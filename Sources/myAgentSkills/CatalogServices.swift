import Foundation

enum SkillFileParser {
    static func parse(contents: String, fallbackName: String) -> FrontmatterMetadata {
        let lines = contents.components(separatedBy: .newlines)
        guard lines.first?.trimmingCharacters(in: .whitespacesAndNewlines) == "---" else {
            return FrontmatterMetadata(
                name: nil,
                description: firstBodyParagraph(from: contents)
            )
        }

        var frontmatterLines: [String] = []
        var bodyLines: [String] = []
        var isInsideFrontmatter = true

        for line in lines.dropFirst() {
            if isInsideFrontmatter, line.trimmingCharacters(in: .whitespacesAndNewlines) == "---" {
                isInsideFrontmatter = false
                continue
            }

            if isInsideFrontmatter {
                frontmatterLines.append(line)
            } else {
                bodyLines.append(line)
            }
        }

        let values = Dictionary(uniqueKeysWithValues: frontmatterLines.compactMap { line -> (String, String)? in
            let parts = line.split(separator: ":", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { return nil }
            let key = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
            let value = parts[1]
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            return (key, value)
        })

        let description = values["description"].flatMap { $0.isEmpty ? nil : $0 }
            ?? firstBodyParagraph(from: bodyLines.joined(separator: "\n"))

        return FrontmatterMetadata(
            name: values["name"].flatMap { $0.isEmpty ? nil : $0 } ?? fallbackName,
            description: description
        )
    }

    private static func firstBodyParagraph(from contents: String) -> String? {
        contents
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty && !$0.hasPrefix("#") }
    }
}

final class CustomSkillsCatalogService {
    private let rootURL: URL
    private let fileManager: FileManager
    private let categorizationFileName = "skills.json"
    private let disabledDirectoryName = ".disabled"
    private let trashItemHandler: (URL) throws -> Void

    init(
        rootURL: URL = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".agents/skills"),
        fileManager: FileManager = .default,
        trashItemHandler: ((URL) throws -> Void)? = nil
    ) {
        self.rootURL = rootURL
        self.fileManager = fileManager
        self.trashItemHandler = trashItemHandler ?? { url in
            _ = try fileManager.trashItem(at: url, resultingItemURL: nil)
        }
    }

    func loadSnapshot() -> CustomSkillsCatalogSnapshot {
        let categorizationState = loadCategorizationState()
        let skills = loadSkills(categorizationState: categorizationState)
        return CustomSkillsCatalogSnapshot(skills: skills, categorizationState: categorizationState)
    }

    func loadSkills() -> [CustomSkillRecord] {
        loadSnapshot().skills
    }

    func buildSections(skills: [CustomSkillRecord], categorizationState: SkillCategorizationState) -> [CustomSkillSection] {
        guard case .loaded(let catalogDefinition) = categorizationState else {
            return []
        }

        let orderedSections = catalogDefinition.scopes.compactMap { scope -> CustomSkillSection? in
            let scopedSkills = skills.filter { $0.categoryScopeID == scope.id }
            guard !scopedSkills.isEmpty else { return nil }

            return CustomSkillSection(
                id: scope.id,
                title: scope.label,
                description: scope.description,
                skills: scopedSkills
            )
        }

        let uncategorizedSkills = skills.filter { $0.categoryScopeID == nil }
        guard !uncategorizedSkills.isEmpty else {
            return orderedSections
        }

        return orderedSections + [
            CustomSkillSection(
                id: "uncategorized",
                title: "Uncategorized",
                description: "Skills found in `~/.agents/skills` but not assigned in `skills.json`.",
                skills: uncategorizedSkills
            )
        ]
    }

    func setSkill(_ skill: CustomSkillRecord, enabled: Bool) throws {
        let destinationLocation: CustomSkillStorageLocation = enabled ? .active : .disabled
        guard destinationLocation != skill.storageLocation else { return }

        let sourceURL = skill.folderURL
        guard fileManager.fileExists(atPath: sourceURL.path) else {
            throw CustomSkillMutationError.missingSkill(folderName: skill.folderName)
        }

        let destinationRootURL = rootURL(for: destinationLocation)
        if destinationLocation == .disabled {
            try ensureDisabledDirectoryExists()
        }

        let destinationURL = destinationRootURL.appendingPathComponent(skill.folderName, isDirectory: true)
        guard !fileManager.fileExists(atPath: destinationURL.path) else {
            throw CustomSkillMutationError.destinationAlreadyExists(
                folderName: skill.folderName,
                destinationPath: destinationURL.path
            )
        }

        do {
            try fileManager.moveItem(at: sourceURL, to: destinationURL)
        } catch {
            throw CustomSkillMutationError.moveFailed(
                folderName: skill.folderName,
                destinationPath: destinationURL.path,
                underlyingMessage: error.localizedDescription
            )
        }
    }

    func trashSkill(_ skill: CustomSkillRecord) throws {
        guard fileManager.fileExists(atPath: skill.folderURL.path) else {
            throw CustomSkillMutationError.missingSkill(folderName: skill.folderName)
        }

        do {
            try trashItemHandler(skill.folderURL)
        } catch {
            throw CustomSkillMutationError.trashFailed(
                folderName: skill.folderName,
                underlyingMessage: error.localizedDescription
            )
        }
    }

    private func loadSkills(categorizationState: SkillCategorizationState) -> [CustomSkillRecord] {
        let categorizationByFolder: [String: SkillCategorizationEntry]
        let scopesByID: [String: SkillCatalogScope]
        if case .loaded(let definition) = categorizationState {
            categorizationByFolder = Dictionary(
                definition.skills.map { ($0.folder, $0) },
                uniquingKeysWith: { _, latest in latest }
            )
            scopesByID = Dictionary(
                definition.scopes.map { ($0.id, $0) },
                uniquingKeysWith: { _, latest in latest }
            )
        } else {
            categorizationByFolder = [:]
            scopesByID = [:]
        }

        let activeSkills = loadSkills(
            in: rootURL,
            storageLocation: .active,
            categorizationByFolder: categorizationByFolder,
            scopesByID: scopesByID
        )
        let disabledSkills = loadSkills(
            in: disabledRootURL,
            storageLocation: .disabled,
            categorizationByFolder: categorizationByFolder,
            scopesByID: scopesByID
        )

        return (activeSkills + disabledSkills).sorted {
            if $0.isDisabled != $1.isDisabled {
                return !$0.isDisabled && $1.isDisabled
            }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    private func loadSkills(
        in directoryURL: URL,
        storageLocation: CustomSkillStorageLocation,
        categorizationByFolder: [String: SkillCategorizationEntry],
        scopesByID: [String: SkillCatalogScope]
    ) -> [CustomSkillRecord] {
        guard let contents = try? fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return contents.compactMap { folderURL in
            let skillFileURL = folderURL.appendingPathComponent("SKILL.md")
            guard fileManager.fileExists(atPath: skillFileURL.path) else { return nil }

            let contents = (try? String(contentsOf: skillFileURL)) ?? ""
            let metadata = SkillFileParser.parse(contents: contents, fallbackName: folderURL.lastPathComponent)
            let description = metadata.description?.trimmingCharacters(in: .whitespacesAndNewlines)
            let folderName = folderURL.lastPathComponent
            let categorizationEntry = categorizationByFolder[folderName]
            let scope = categorizationEntry.flatMap { scopesByID[$0.scope] }
            return CustomSkillRecord(
                name: metadata.name ?? folderURL.lastPathComponent,
                description: description?.isEmpty == false ? description! : "Custom Local",
                folderName: folderName,
                folderURL: folderURL,
                skillFileURL: skillFileURL,
                isDisabled: storageLocation.isDisabled,
                storageLocation: storageLocation,
                categoryScopeID: scope?.id,
                categoryLabel: scope?.label,
                categoryDescription: scope?.description,
                tags: categorizationEntry?.tags ?? [],
                platforms: categorizationEntry?.platforms ?? []
            )
        }
    }

    private func loadCategorizationState() -> SkillCategorizationState {
        let categorizationFileURL = rootURL.appendingPathComponent(categorizationFileName)
        guard fileManager.fileExists(atPath: categorizationFileURL.path) else {
            return .missing
        }

        do {
            let data = try Data(contentsOf: categorizationFileURL)
            let decoder = JSONDecoder()
            let definition = try decoder.decode(SkillCatalogDefinition.self, from: data)
            return .loaded(definition)
        } catch {
            return .invalid(message: error.localizedDescription)
        }
    }

    func filter(skills: [CustomSkillRecord], query: String) -> [CustomSkillRecord] {
        let tokens = query.normalizedSearchTokens()
        guard !tokens.isEmpty else { return skills }
        return skills.filter { record in
            let searchable = record.searchableText
            return tokens.allSatisfy(searchable.contains)
        }
    }

    private var disabledRootURL: URL {
        rootURL.appendingPathComponent(disabledDirectoryName, isDirectory: true)
    }

    private func rootURL(for storageLocation: CustomSkillStorageLocation) -> URL {
        switch storageLocation {
        case .active:
            return rootURL
        case .disabled:
            return disabledRootURL
        }
    }

    private func ensureDisabledDirectoryExists() throws {
        guard !fileManager.fileExists(atPath: disabledRootURL.path) else { return }
        try fileManager.createDirectory(at: disabledRootURL, withIntermediateDirectories: true)
    }
}

enum CustomSkillMutationError: LocalizedError, Equatable {
    case missingSkill(folderName: String)
    case destinationAlreadyExists(folderName: String, destinationPath: String)
    case moveFailed(folderName: String, destinationPath: String, underlyingMessage: String)
    case trashFailed(folderName: String, underlyingMessage: String)

    var errorDescription: String? {
        switch self {
        case .missingSkill(let folderName):
            return "The skill folder for `\(folderName)` could not be found anymore."
        case .destinationAlreadyExists(let folderName, let destinationPath):
            return "Could not move `\(folderName)` because a folder already exists at `\(destinationPath)`."
        case .moveFailed(let folderName, let destinationPath, let underlyingMessage):
            return "Could not move `\(folderName)` to `\(destinationPath)`. \(underlyingMessage)"
        case .trashFailed(let folderName, let underlyingMessage):
            return "Could not move `\(folderName)` to the Trash. \(underlyingMessage)"
        }
    }
}

final class InstalledSkillsCatalogService {
    private let fileManager: FileManager
    private let homeDirectoryURL: URL

    init(
        fileManager: FileManager = .default,
        homeDirectoryURL: URL = URL(fileURLWithPath: NSHomeDirectory())
    ) {
        self.fileManager = fileManager
        self.homeDirectoryURL = homeDirectoryURL
    }

    func loadSkills() -> [InstalledSkillRecord] {
        var results: [InstalledSkillRecord] = []
        let roots: [(bucket: InstalledSkillBucket, url: URL, agentID: String?)] = [
            (
                InstalledSkillBucket(
                    title: "Global Library",
                    order: 0,
                    locationLabel: "~/.agents/skills"
                ),
                homeDirectoryURL.appendingPathComponent(".agents/skills"),
                nil
            ),
            (
                InstalledSkillBucket(
                    title: "Codex",
                    order: 1,
                    locationLabel: "~/.codex/skills"
                ),
                homeDirectoryURL.appendingPathComponent(".codex/skills"),
                "codex"
            ),
            (
                InstalledSkillBucket(
                    title: "Claude",
                    order: 2,
                    locationLabel: "~/.claude/skills"
                ),
                homeDirectoryURL.appendingPathComponent(".claude/skills"),
                "claude-code"
            ),
            (
                InstalledSkillBucket(
                    title: "Gemini / Antigravity",
                    order: 3,
                    locationLabel: "~/.gemini/antigravity/skills"
                ),
                homeDirectoryURL.appendingPathComponent(".gemini/antigravity/skills"),
                "gemini-antigravity"
            )
        ]

        for root in roots {
            results.append(contentsOf: loadSkills(in: root.url, bucket: root.bucket, agentID: root.agentID))
        }

        return results.sorted {
            if $0.bucket.order != $1.bucket.order {
                return $0.bucket.order < $1.bucket.order
            }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    func filter(skills: [InstalledSkillRecord], query: String) -> [InstalledSkillRecord] {
        let tokens = query.normalizedSearchTokens()
        guard !tokens.isEmpty else { return skills }
        return skills.filter { record in
            let searchable = record.searchableText
            return tokens.allSatisfy(searchable.contains)
        }
    }

    private func loadSkills(in rootURL: URL, agent: AgentTarget, scope: InstallScope) -> [InstalledSkillRecord] {
        []
    }

    private func loadSkills(in rootURL: URL, bucket: InstalledSkillBucket, agentID: String?) -> [InstalledSkillRecord] {
        guard let contents = try? fileManager.contentsOfDirectory(
            at: rootURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return contents.compactMap { folderURL in
            let skillFileURL = folderURL.appendingPathComponent("SKILL.md")
            let contents = (try? String(contentsOf: skillFileURL)) ?? ""
            let metadata = SkillFileParser.parse(contents: contents, fallbackName: folderURL.lastPathComponent)
            let description = metadata.description?.trimmingCharacters(in: .whitespacesAndNewlines)

            return InstalledSkillRecord(
                name: metadata.name ?? folderURL.lastPathComponent,
                description: description?.isEmpty == false ? description! : "Installed skill",
                sourceLabel: bucket.locationLabel,
                bucket: bucket,
                agentID: agentID,
                folderURL: folderURL,
                skillFileURL: fileManager.fileExists(atPath: skillFileURL.path) ? skillFileURL : nil,
                status: .unknown
            )
        }
    }
}
