// ProcessRunner.swift
// Utility for running external processes asynchronously.
// Part of Fallow. MIT licence.

import Foundation

/// Result of running an external process.
struct ProcessResult: Sendable {
    let exitCode: Int32
    let stdout: String
    let stderr: String

    var succeeded: Bool { exitCode == 0 }
}

/// Runs external processes off the main actor.
enum ProcessRunner {

    /// Runs an executable at the given path with arguments.
    /// Executes on a detached task to avoid blocking the caller's actor.
    static func run(
        executablePath: String,
        arguments: [String] = [],
        environment: [String: String]? = nil
    ) async throws -> ProcessResult {
        let env = environment
        return try await Task.detached {
            let process = Process()
            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()

            process.executableURL = URL(fileURLWithPath: executablePath)
            process.arguments = arguments
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe

            if let env {
                var merged = ProcessInfo.processInfo.environment
                merged.merge(env) { _, new in new }
                process.environment = merged
            }

            try process.run()

            // Note: sequential pipe reads are safe for CLI commands with small output.
            // For processes that may produce >64KB on both stdout and stderr
            // simultaneously, concurrent draining would be needed to avoid deadlock.
            let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
            let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()

            return ProcessResult(
                exitCode: process.terminationStatus,
                stdout: String(data: stdoutData, encoding: .utf8) ?? "",
                stderr: String(data: stderrData, encoding: .utf8) ?? ""
            )
        }.value
    }

    /// Searches the system PATH (plus common install locations) for an executable.
    /// GUI apps launched via `open` get a minimal PATH, so we extend it with
    /// common locations where kwaainet and similar tools are installed.
    static func findInPath(_ name: String) -> String? {
        let envPath = ProcessInfo.processInfo.environment["PATH"] ?? ""
        let home = FileManager.default.homeDirectoryForCurrentUser.path

        var dirs = envPath.split(separator: ":").map(String.init)
        // Add common install locations not typically in a GUI app's PATH
        dirs.append(contentsOf: [
            "\(home)/.cargo/bin",
            "/opt/homebrew/bin",
            "/usr/local/bin",
            "\(home)/.local/bin",
        ])

        for dir in dirs {
            let fullPath = (dir as NSString).appendingPathComponent(name)
            if FileManager.default.isExecutableFile(atPath: fullPath) {
                return fullPath
            }
        }
        return nil
    }
}
