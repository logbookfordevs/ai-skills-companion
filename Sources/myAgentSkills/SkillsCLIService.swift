import AppKit
import Foundation

final class SkillsCLIService {
    private let runtimeResolver: NodeRuntimeResolver
    private let queue = DispatchQueue(label: "myAgentSkills.skills-cli", qos: .userInitiated)

    init(runtimeResolver: NodeRuntimeResolver = NodeRuntimeResolver()) {
        self.runtimeResolver = runtimeResolver
    }

    func resolution() -> NodeRuntimeResolution {
        runtimeResolver.resolveNPX()
    }

    func find(query: String, completion: @escaping @MainActor (CLICommandResult, [OfficialSkillSearchResult]) -> Void) {
        run(arguments: ["--yes", "skills", "find", query]) { result in
            completion(result, OfficialSearchParser.parse(result.stdout + "\n" + result.stderr))
        }
    }

    func listSkills(source: String, completion: @escaping @MainActor (CLICommandResult, [String]) -> Void) {
        run(arguments: ["--yes", "skills", "add", source, "--list"]) { result in
            completion(result, SourceSkillListParser.parse(result.stdout + "\n" + result.stderr))
        }
    }

    func check(completion: @escaping @MainActor (CLICommandResult) -> Void) {
        run(arguments: ["--yes", "skills", "check"], completion: completion)
    }

    func updateAll(completion: @escaping @MainActor (CLICommandResult) -> Void) {
        run(arguments: ["--yes", "skills", "update"], completion: completion)
    }

    func add(state: InstallWizardState, completion: @escaping @MainActor (CLICommandResult) -> Void) {
        run(arguments: state.buildInstallArguments(), completion: completion)
    }

    func prepareInstallCommand(source: String) -> CLICommandResult {
        let resolution = runtimeResolver.resolveNPX()
        let installArguments = ["--yes", "skills", "add", source]

        guard let executablePath = resolution.executablePath else {
            return CLICommandResult(
                executablePath: nil,
                arguments: installArguments,
                workingDirectory: FileManager.default.currentDirectoryPath,
                stdout: "",
                stderr: "Could not find npx. Install Node.js or make npx available to GUI apps.",
                exitCode: -1,
                attemptedPaths: resolution.attemptedPaths
            )
        }

        return CLICommandResult(
            executablePath: executablePath,
            arguments: installArguments,
            workingDirectory: FileManager.default.currentDirectoryPath,
            stdout: "Copied install command to the clipboard. Paste it into your favorite terminal and follow the skills CLI prompts there.",
            stderr: "",
            exitCode: 0,
            attemptedPaths: resolution.attemptedPaths
        )
    }

    func run(arguments: [String], completion: @escaping @MainActor (CLICommandResult) -> Void) {
        let resolution = runtimeResolver.resolveNPX()
        guard let executablePath = resolution.executablePath else {
            Task { @MainActor in
                completion(
                    CLICommandResult(
                        executablePath: nil,
                        arguments: arguments,
                        workingDirectory: FileManager.default.currentDirectoryPath,
                        stdout: "",
                        stderr: "Could not find npx. Install Node.js or make npx available to GUI apps.",
                        exitCode: -1,
                        attemptedPaths: resolution.attemptedPaths
                    )
                )
            }
            return
        }

        let environment = environment(forExecutablePath: executablePath)
        let currentDirectoryPath = FileManager.default.currentDirectoryPath
        queue.async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executablePath)
            process.arguments = arguments
            process.currentDirectoryURL = URL(fileURLWithPath: currentDirectoryPath)

            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe
            process.environment = environment

            do {
                try process.run()
                process.waitUntilExit()

                let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                let result = CLICommandResult(
                    executablePath: executablePath,
                    arguments: arguments,
                    workingDirectory: process.currentDirectoryURL?.path,
                    stdout: String(data: stdoutData, encoding: .utf8) ?? "",
                    stderr: String(data: stderrData, encoding: .utf8) ?? "",
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
                    workingDirectory: process.currentDirectoryURL?.path,
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

    private func environment(forExecutablePath executablePath: String) -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        environment["HOME"] = NSHomeDirectory()
        environment["TERM"] = "dumb"
        environment["NO_COLOR"] = "1"
        environment["FORCE_COLOR"] = "0"
        environment["CLICOLOR"] = "0"
        environment["CLICOLOR_FORCE"] = "0"
        environment["CI"] = "1"
        environment["npm_config_color"] = "false"

        let executableDirectory = URL(fileURLWithPath: executablePath).deletingLastPathComponent().path
        let existingPath = environment["PATH"] ?? ""
        environment["PATH"] = ([executableDirectory, existingPath])
            .filter { !$0.isEmpty }
            .joined(separator: ":")

        return environment
    }
}
