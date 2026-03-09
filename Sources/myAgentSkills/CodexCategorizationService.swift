import Foundation

private final class CodexOutputBuffer: @unchecked Sendable {
    private let queue = DispatchQueue(label: "myAgentSkills.codex-categorization.output")
    private var stdout = ""
    private var stderr = ""

    func append(_ chunk: String, isError: Bool) {
        queue.sync {
            if isError {
                stderr += chunk
            } else {
                stdout += chunk
            }
        }
    }

    func snapshot() -> (stdout: String, stderr: String) {
        queue.sync { (stdout, stderr) }
    }
}

struct CodexRuntimeResolution {
    let executablePath: String?
    let attemptedPaths: [String]

    var isResolved: Bool {
        executablePath != nil
    }
}

final class CodexRuntimeResolver {
    private let fileManager: FileManager
    private let processInfo: ProcessInfo

    init(fileManager: FileManager = .default, processInfo: ProcessInfo = .processInfo) {
        self.fileManager = fileManager
        self.processInfo = processInfo
    }

    func resolveCodex() -> CodexRuntimeResolution {
        let homeDirectory = NSHomeDirectory()
        let environment = processInfo.environment
        let candidates = Self.candidatePaths(homeDirectory: homeDirectory, environment: environment)
        let selected = Self.selectExecutable(from: candidates) { [fileManager] path in
            fileManager.isExecutableFile(atPath: path)
        }

        return CodexRuntimeResolution(executablePath: selected, attemptedPaths: candidates)
    }

    static func candidatePaths(homeDirectory: String, environment: [String: String]) -> [String] {
        var candidates: [String] = []

        if let path = environment["PATH"] {
            for segment in path.split(separator: ":") {
                candidates.append(URL(fileURLWithPath: String(segment)).appendingPathComponent("codex").path)
            }
        }

        candidates.append(contentsOf: [
            "/opt/homebrew/bin/codex",
            "/usr/local/bin/codex",
            "/usr/bin/codex",
            URL(fileURLWithPath: homeDirectory).appendingPathComponent(".local/bin/codex").path
        ])

        return deduplicated(candidates)
    }

    static func selectExecutable(from candidates: [String], fileExists: (String) -> Bool) -> String? {
        candidates.first(where: fileExists)
    }

    private static func deduplicated(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.filter { seen.insert($0).inserted }
    }
}

final class CodexCategorizationService {
    private let runtimeResolver: CodexRuntimeResolver
    private let queue = DispatchQueue(label: "myAgentSkills.codex-categorization", qos: .userInitiated)
    private let rootURL: URL

    init(
        rootURL: URL = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".agents/skills"),
        runtimeResolver: CodexRuntimeResolver = CodexRuntimeResolver()
    ) {
        self.rootURL = rootURL
        self.runtimeResolver = runtimeResolver
    }

    func run(
        snapshot: CustomSkillsCatalogSnapshot,
        additionalInstruction: String? = nil,
        onOutput: (@MainActor @Sendable (String) -> Void)? = nil,
        completion: @escaping @MainActor (CLICommandResult) -> Void
    ) {
        let resolution = runtimeResolver.resolveCodex()
        let prompt = buildPrompt(snapshot: snapshot, additionalInstruction: additionalInstruction)
        let arguments = buildArguments(prompt: prompt)
        let rootPath = rootURL.path
        let rootURL = self.rootURL

        guard let executablePath = resolution.executablePath else {
            Task { @MainActor in
                completion(
                    CLICommandResult(
                        executablePath: nil,
                        arguments: arguments,
                        workingDirectory: rootPath,
                        stdout: "",
                        stderr: "Could not find `codex`. Install the Codex CLI or make it available to GUI apps.",
                        exitCode: -1,
                        attemptedPaths: resolution.attemptedPaths
                    )
                )
            }
            return
        }

        let environment = buildEnvironment(forExecutablePath: executablePath)
        let outputHandler = onOutput

        queue.async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executablePath)
            process.arguments = arguments
            process.currentDirectoryURL = rootURL

            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe
            process.environment = environment
            let outputBuffer = CodexOutputBuffer()

            let consumeChunk: @Sendable (Data, Bool) -> Void = { data, isError in
                guard !data.isEmpty else { return }
                let chunk = String(decoding: data, as: UTF8.self)
                guard !chunk.isEmpty else { return }

                outputBuffer.append(chunk, isError: isError)

                if let outputHandler {
                    Task { @MainActor in
                        outputHandler(chunk)
                    }
                }
            }

            stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                guard !data.isEmpty else { return }
                consumeChunk(data, false)
            }

            stderrPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                guard !data.isEmpty else { return }
                consumeChunk(data, true)
            }

            do {
                try process.run()
                process.waitUntilExit()

                stdoutPipe.fileHandleForReading.readabilityHandler = nil
                stderrPipe.fileHandleForReading.readabilityHandler = nil
                consumeChunk(stdoutPipe.fileHandleForReading.readDataToEndOfFile(), false)
                consumeChunk(stderrPipe.fileHandleForReading.readDataToEndOfFile(), true)

                let finalOutput = outputBuffer.snapshot()
                let result = CLICommandResult(
                    executablePath: executablePath,
                    arguments: arguments,
                    workingDirectory: rootPath,
                    stdout: finalOutput.stdout,
                    stderr: finalOutput.stderr,
                    exitCode: process.terminationStatus,
                    attemptedPaths: resolution.attemptedPaths
                )

                Task { @MainActor in
                    completion(result)
                }
            } catch {
                let result = CLICommandResult(
                    executablePath: executablePath,
                    arguments: arguments,
                    workingDirectory: rootPath,
                    stdout: "",
                    stderr: error.localizedDescription,
                    exitCode: -1,
                    attemptedPaths: resolution.attemptedPaths
                )

                Task { @MainActor in
                    completion(result)
                }
            }
        }
    }

    func buildArguments(prompt: String) -> [String] {
        [
            "exec",
            "--skip-git-repo-check",
            "--sandbox", "workspace-write",
            "--full-auto",
            "--color", "never",
            "--ephemeral",
            "-C", rootURL.path,
            "--add-dir", rootURL.path,
            prompt
        ]
    }

    func buildPrompt(snapshot: CustomSkillsCatalogSnapshot, additionalInstruction: String? = nil) -> String {
        let activeFolders = snapshot.skills
            .filter { !$0.isDisabled }
            .map(\.folderName)
            .sorted()
        let disabledFolders = snapshot.skills
            .filter(\.isDisabled)
            .map(\.folderName)
            .sorted()
        let knownScopes: [String]
        switch snapshot.categorizationState {
        case .loaded(let definition):
            knownScopes = definition.scopes.map(\.label)
        case .missing, .invalid:
            knownScopes = []
        }

        let skillList = [
            activeFolders.isEmpty ? "Active skill folders: none" : "Active skill folders: \(activeFolders.joined(separator: ", "))",
            disabledFolders.isEmpty ? "Disabled skill folders: none" : "Disabled skill folders: \(disabledFolders.joined(separator: ", "))",
            knownScopes.isEmpty ? "Existing scopes: none" : "Existing scopes: \(knownScopes.joined(separator: ", "))"
        ].joined(separator: "\n")

        let baseInstructions = """
        You are inside ~/.agents/skills.

        Your job is to create or update skills.json for AI Skills Companion using the existing schema exactly:
        - version
        - generatedAt
        - description
        - scopes
        - skills

        Rules:
        - Read local skill folders from the current directory and from .disabled.
        - A skill folder is a directory containing SKILL.md.
        - Match skills by folder name.
        - If skills.json is missing, create it.
        - If skills.json exists and is valid, preserve existing scopes and existing skill mappings.
        - Append only missing skills that are not already present in skills.json.
        - Create a new scope only when no existing scope is a good fit.
        - Prefer intent-based scopes over umbrella buckets. Avoid broad catch-all scopes like Engineering when narrower scopes such as Debug, Review, Automation, Project Context, or Docs better match how a human would browse the library.
        - Prefer stable categorization. If a tool-specific or workflow-specific scope already exists and clearly fits new skills, keep using it.
        - A scope may contain only one skill if that skill represents a distinct workflow, discipline, or project-specific context and the scope improves discovery.
        - Do not create a dedicated scope for every tool mention. Keep a skill inside a broader domain when the tool is only an implementation detail of that broader area.
        - Common useful scope patterns in this library include Frontend, Docs, Review, Debug, Automation, Project Context, Video, and Stitch. Use these when they fit naturally, but do not force skills into them if a clearer scope would improve browsing.
        - Example: several Stitch-focused skills should live in a dedicated Stitch scope.
        - Example: a single shadcn-ui skill should usually remain inside Frontend.
        - Example: a browser automation skill usually belongs in Automation, a root-cause debugging skill in Debug, a review methodology or evaluation framework skill in Review, and a branding or project-specific guidance skill in Project Context or Brand Context.
        - Example: do not put a skill into Video only because it mentions Remotion. If the actual workflow is centered on Stitch and the skill uses Remotion as an implementation detail, prefer Stitch instead.
        - When a skill depends on a larger workflow, platform, or family that other skills also center on, categorize it by that larger parent concept rather than by a secondary implementation detail.
        - Brand-focused or project-focused skills should usually live in Project Context or Brand Context instead of being merged into a broader engineering bucket.
        - Avoid collapsing an existing meaningful scope back into a broader scope unless the existing scope is clearly mistaken.
        - If skills.json exists but is invalid, repair it into valid JSON and preserve as much useful categorization as possible.
        - Do not edit SKILL.md files.
        - Do not delete existing scopes or skill mappings unless required to make the JSON valid.
        - Ensure every discovered skill folder ends up represented in skills.json.
        - Include both active and disabled skills.
        - Write the final result to ~/.agents/skills/skills.json.
        - Keep the JSON pretty-printed.

        Context:
        \(skillList)

        For reference, this is the supported starter shape:
        \(SkillCatalogDefinition.templateJSON)
        """

        switch snapshot.categorizationState {
        case .missing:
            return baseInstructions + additionalInstructionSection(additionalInstruction) + "\n\nskills.json is currently missing. Create it from scratch and categorize all discovered skills."
        case .invalid:
            return baseInstructions + additionalInstructionSection(additionalInstruction) + "\n\nskills.json currently exists but cannot be parsed. Repair it and categorize all discovered skills."
        case .loaded:
            return baseInstructions + additionalInstructionSection(additionalInstruction) + "\n\nskills.json currently exists and is valid. Keep all current mappings and only append missing skill entries."
        }
    }

    private func additionalInstructionSection(_ additionalInstruction: String?) -> String {
        guard let additionalInstruction else { return "" }
        let trimmedInstruction = additionalInstruction.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedInstruction.isEmpty else { return "" }

        return "\n\nAdditional user guidance for this run:\n- \(trimmedInstruction)"
    }

    private func buildEnvironment(forExecutablePath executablePath: String) -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        environment["HOME"] = NSHomeDirectory()

        let executableDirectory = URL(fileURLWithPath: executablePath).deletingLastPathComponent().path
        let existingPath = environment["PATH"] ?? ""
        environment["PATH"] = ([executableDirectory, existingPath])
            .filter { !$0.isEmpty }
            .joined(separator: ":")

        return environment
    }
}
