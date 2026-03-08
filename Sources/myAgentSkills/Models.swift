import Foundation

enum InstallScope: String, CaseIterable {
    case project
    case global

    var displayName: String {
        switch self {
        case .project: return "Project"
        case .global: return "Global"
        }
    }
}

enum SkillSourceKind: String, CaseIterable {
    case searchResult
    case github
    case fullURL
    case localPath

    var displayName: String {
        switch self {
        case .searchResult: return "Search Result"
        case .github: return "GitHub Shorthand"
        case .fullURL: return "Full URL"
        case .localPath: return "Local Path"
        }
    }
}

enum SkillInstallStatus: Equatable, Hashable {
    case unknown
    case upToDate
    case updateAvailable(details: String?)
    case info(details: String)
    case error(details: String)

    var title: String {
        switch self {
        case .unknown:
            return "Unknown"
        case .upToDate:
            return "Up to date"
        case .updateAvailable(let details):
            return details ?? "Update available"
        case .info(let details):
            return details
        case .error(let details):
            return details
        }
    }
}

struct CLICommandResult: Equatable {
    let executablePath: String?
    let arguments: [String]
    let workingDirectory: String?
    let stdout: String
    let stderr: String
    let exitCode: Int32
    let attemptedPaths: [String]

    var succeeded: Bool {
        exitCode == 0
    }

    var displayCommand: String {
        let binary = executablePath ?? "npx"
        return ([binary] + arguments).joined(separator: " ")
    }

    var combinedOutput: String {
        let cleanedStdout = stdout.strippingANSI()
        let cleanedStderr = stderr.strippingANSI()
        let shouldShowAttemptedPaths = executablePath == nil || !succeeded
        let sections = [
            "Command: \(displayCommand)",
            workingDirectory.map { "Working Directory: \($0)" },
            cleanedStdout.isEmpty ? nil : "STDOUT\n\(cleanedStdout)",
            cleanedStderr.isEmpty ? nil : "STDERR\n\(cleanedStderr)",
            (shouldShowAttemptedPaths && !attemptedPaths.isEmpty) ? "Attempted npx paths:\n\(attemptedPaths.joined(separator: "\n"))" : nil,
            "Exit Code: \(exitCode)"
        ]
        return sections.compactMap { $0 }.joined(separator: "\n\n")
    }
}

enum InteractiveTerminalApp: String, CaseIterable {
    case terminal
    case iTerm2
    case ghostty
    case kitty

    var displayName: String {
        switch self {
        case .terminal:
            return "Terminal"
        case .iTerm2:
            return "iTerm2"
        case .ghostty:
            return "Ghostty"
        case .kitty:
            return "Kitty"
        }
    }

    var bundleIdentifier: String {
        switch self {
        case .terminal:
            return "com.apple.Terminal"
        case .iTerm2:
            return "com.googlecode.iterm2"
        case .ghostty:
            return "com.mitchellh.ghostty"
        case .kitty:
            return "net.kovidgoyal.kitty"
        }
    }

    var executableRelativePath: String? {
        switch self {
        case .terminal, .iTerm2:
            return nil
        case .ghostty:
            return "Contents/MacOS/ghostty"
        case .kitty:
            return "Contents/MacOS/kitty"
        }
    }
}

struct AgentTarget: Hashable {
    let id: String
    let displayName: String
    let globalPath: String?
    let projectRelativePath: String?

    static let all: [AgentTarget] = [
        AgentTarget(id: "codex", displayName: "Codex", globalPath: "~/.codex/skills", projectRelativePath: ".codex/skills"),
        AgentTarget(id: "claude-code", displayName: "Claude Code", globalPath: "~/.claude/skills", projectRelativePath: ".claude/skills"),
        AgentTarget(id: "opencode", displayName: "OpenCode", globalPath: "~/.config/opencode/skills", projectRelativePath: ".opencode/skills"),
        AgentTarget(id: "cline", displayName: "Cline", globalPath: nil, projectRelativePath: nil),
        AgentTarget(id: "gemini-cli", displayName: "Gemini CLI", globalPath: "~/.gemini/skills", projectRelativePath: ".gemini/skills"),
        AgentTarget(id: "cursor", displayName: "Cursor", globalPath: "~/.cursor/skills", projectRelativePath: ".cursor/skills"),
        AgentTarget(id: "amp", displayName: "Amp", globalPath: "~/.amp/skills", projectRelativePath: ".amp/skills"),
        AgentTarget(id: "qwen-code", displayName: "Qwen Code", globalPath: "~/.qwen/skills", projectRelativePath: ".qwen/skills"),
        AgentTarget(id: "crush", displayName: "Crush", globalPath: "~/.config/crush/skills", projectRelativePath: ".crush/skills"),
        AgentTarget(id: "goose", displayName: "Goose", globalPath: "~/.config/goose/skills", projectRelativePath: ".goose/skills"),
        AgentTarget(id: "warp", displayName: "Warp", globalPath: "~/.warp/skills", projectRelativePath: ".warp/skills"),
        AgentTarget(id: "zed", displayName: "Zed", globalPath: "~/.config/zed/skills", projectRelativePath: ".zed/skills"),
        AgentTarget(id: "roo-code", displayName: "Roo Code", globalPath: "~/.roo/skills", projectRelativePath: ".roo/skills"),
        AgentTarget(id: "aider", displayName: "Aider", globalPath: "~/.aider/skills", projectRelativePath: ".aider/skills"),
        AgentTarget(id: "witsy", displayName: "Witsy", globalPath: "~/.witsy/skills", projectRelativePath: ".witsy/skills"),
        AgentTarget(id: "vscode", displayName: "VS Code", globalPath: "~/.config/Code/User/skills", projectRelativePath: ".vscode/skills"),
        AgentTarget(id: "kilo-code", displayName: "Kilo Code", globalPath: "~/.kilo/skills", projectRelativePath: ".kilo/skills"),
        AgentTarget(id: "vim", displayName: "Vim", globalPath: "~/.vim/skills", projectRelativePath: ".vim/skills"),
        AgentTarget(id: "neovim", displayName: "Neovim", globalPath: "~/.config/nvim/skills", projectRelativePath: ".nvim/skills"),
        AgentTarget(id: "emacs", displayName: "Emacs", globalPath: "~/.emacs.d/skills", projectRelativePath: ".emacs.d/skills"),
        AgentTarget(id: "obsidian", displayName: "Obsidian", globalPath: "~/Library/Application Support/Obsidian/skills", projectRelativePath: ".obsidian/skills"),
        AgentTarget(id: "windsurf", displayName: "Windsurf", globalPath: "~/.windsurf/skills", projectRelativePath: ".windsurf/skills"),
        AgentTarget(id: "boltai", displayName: "BoltAI", globalPath: "~/Library/Application Support/BoltAI/skills", projectRelativePath: ".boltai/skills"),
        AgentTarget(id: "enconvo", displayName: "Enconvo", globalPath: "~/Library/Application Support/Enconvo/skills", projectRelativePath: ".enconvo/skills"),
        AgentTarget(id: "continue", displayName: "Continue", globalPath: "~/.continue/skills", projectRelativePath: ".continue/skills"),
        AgentTarget(id: "github-copilot", displayName: "GitHub Copilot", globalPath: "~/.config/github-copilot/skills", projectRelativePath: ".github-copilot/skills"),
        AgentTarget(id: "kiro", displayName: "Kiro", globalPath: "~/.kiro/skills", projectRelativePath: ".kiro/skills"),
        AgentTarget(id: "cursor-agents", displayName: "Cursor Agents", globalPath: "~/.cursor/agents/skills", projectRelativePath: ".cursor/agents/skills"),
        AgentTarget(id: "jules", displayName: "Jules", globalPath: "~/.jules/skills", projectRelativePath: ".jules/skills"),
        AgentTarget(id: "openhands", displayName: "OpenHands", globalPath: "~/.openhands/skills", projectRelativePath: ".openhands/skills"),
        AgentTarget(id: "augment-code", displayName: "Augment Code", globalPath: "~/.augment/skills", projectRelativePath: ".augment/skills"),
        AgentTarget(id: "trae", displayName: "Trae", globalPath: "~/.trae/skills", projectRelativePath: ".trae/skills")
    ]
}

struct OfficialSkillSearchResult: Equatable, Hashable {
    let title: String
    let source: String?
    let description: String
    let rawValue: String
    let installSource: String
}

struct InstalledSkillBucket: Equatable, Hashable {
    let title: String
    let order: Int
    let locationLabel: String
}

struct InstalledSkillRecord: Equatable, Hashable {
    let name: String
    let description: String
    let sourceLabel: String
    let bucket: InstalledSkillBucket
    let agentID: String?
    let folderURL: URL?
    let skillFileURL: URL?
    var status: SkillInstallStatus

    var searchableText: String {
        [name, description, sourceLabel, bucket.title, bucket.locationLabel, agentID ?? ""]
            .joined(separator: " ")
            .lowercased()
    }
}

struct SkillCatalogScope: Codable, Equatable, Hashable {
    let id: String
    let label: String
    let description: String?
}

struct SkillCategorizationEntry: Codable, Equatable, Hashable {
    let folder: String
    let name: String?
    let scope: String
    let platforms: [String]?
    let tags: [String]?
}

struct SkillCatalogDefinition: Codable, Equatable {
    let version: Int
    let generatedAt: String?
    let description: String?
    let scopes: [SkillCatalogScope]
    let skills: [SkillCategorizationEntry]

    static var templateJSON: String {
        let template = SkillCatalogDefinition(
            version: 1,
            generatedAt: "2026-03-08",
            description: "Local skill catalog for My Agent Skills.",
            scopes: [
                SkillCatalogScope(
                    id: "frontend",
                    label: "Frontend",
                    description: "Skills for UI design, implementation, and frontend quality."
                ),
                SkillCatalogScope(
                    id: "docs",
                    label: "Docs",
                    description: "Skills for documentation, guides, and reader-first writing."
                )
            ],
            skills: [
                SkillCategorizationEntry(
                    folder: "frontend-design",
                    name: "frontend-design",
                    scope: "frontend",
                    platforms: ["generic"],
                    tags: ["ui", "design", "frontend"]
                ),
                SkillCategorizationEntry(
                    folder: "documentation-authoring",
                    name: "documentation-authoring",
                    scope: "docs",
                    platforms: ["generic"],
                    tags: ["docs", "readme", "guides"]
                )
            ]
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(template),
           let string = String(data: data, encoding: .utf8) {
            return string
        }

        return "{\n  \"version\": 1,\n  \"scopes\": [],\n  \"skills\": []\n}"
    }
}

enum SkillCategorizationState: Equatable {
    case missing
    case invalid(message: String)
    case loaded(SkillCatalogDefinition)
}

struct CustomSkillsCatalogSnapshot: Equatable {
    let skills: [CustomSkillRecord]
    let categorizationState: SkillCategorizationState
}

struct CustomSkillSection: Equatable {
    let id: String
    let title: String
    let description: String?
    let skills: [CustomSkillRecord]
}

enum CustomSkillStorageLocation: String, Equatable, Hashable {
    case active
    case disabled

    var isDisabled: Bool {
        self == .disabled
    }
}

struct CustomSkillRecord: Equatable, Hashable {
    let name: String
    let description: String
    let folderName: String
    let folderURL: URL
    let skillFileURL: URL
    let isDisabled: Bool
    let storageLocation: CustomSkillStorageLocation
    let categoryScopeID: String?
    let categoryLabel: String?
    let categoryDescription: String?
    let tags: [String]
    let platforms: [String]

    var searchableText: String {
        [name, description].joined(separator: " ").lowercased()
    }
}

struct FrontmatterMetadata: Equatable {
    let name: String?
    let description: String?
}

struct InstallWizardState: Equatable {
    var sourceKind: SkillSourceKind = .github
    var sourceInput: String = ""
    var selectedSkill: String?
    var scope: InstallScope = .project
    var selectedAgentIDs: Set<String> = []
    var extraAgentIDs: String = ""

    var normalizedExtraAgentIDs: [String] {
        extraAgentIDs
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    var allAgentIDs: [String] {
        Array(selectedAgentIDs.union(normalizedExtraAgentIDs)).sorted()
    }

    func buildListArguments() -> [String] {
        ["--yes", "skills", "add", sourceInput, "--list"]
    }

    func buildInstallArguments() -> [String] {
        var arguments = ["--yes", "skills", "add", sourceInput]

        if scope == .global {
            arguments.append("-g")
        }

        if let selectedSkill, !selectedSkill.isEmpty {
            arguments.append(contentsOf: ["-s", selectedSkill])
        }

        for agentID in allAgentIDs {
            arguments.append(contentsOf: ["-a", agentID])
        }

        arguments.append("-y")
        return arguments
    }

    func commandPreview(executableName: String = "npx") -> String {
        ([executableName] + buildInstallArguments()).joined(separator: " ")
    }
}

extension String {
    func strippingANSI() -> String {
        var value = self
        let patterns = [
            "\u{001B}\\[[0-9;?]*[ -/]*[@-~]",
            "\u{001B}\\][^\u{0007}]*\u{0007}",
            "\u{009B}[0-9;?]*[ -/]*[@-~]"
        ]

        for pattern in patterns {
            value = value.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
        }

        return value
    }

    func normalizedSearchTokens() -> [String] {
        lowercased()
            .split(whereSeparator: { $0.isWhitespace || $0.isNewline })
            .map(String.init)
            .filter { !$0.isEmpty }
    }
}
