// KwaaiNetManager.swift
// Manages the KwaaiNet binary lifecycle: P2P daemon and local API server.
// Part of Fallow. MIT licence.

import Foundation
import OSLog

/// Information about the running KwaaiNet node.
package struct KwaaiNetStatus: Sendable {
    package var isDaemonRunning: Bool = false
    package var isApiRunning: Bool = false
    package var modelName: String?

    package var isRunning: Bool { isDaemonRunning || isApiRunning }

    package init(isDaemonRunning: Bool = false, isApiRunning: Bool = false, modelName: String? = nil) {
        self.isDaemonRunning = isDaemonRunning
        self.isApiRunning = isApiRunning
        self.modelName = modelName
    }
}

/// State of the first-run setup process.
package enum SetupState: Sendable, Equatable {
    case notNeeded
    case checking
    case running(String)
    case completed
    case failed(String)
}

/// Network port configuration for KwaaiNet services.
package enum KwaaiNetPorts {
    /// Port for the local OpenAI-compatible API (kwaainet serve).
    package static let api: UInt16 = 11435
    /// Port used by the P2P daemon (p2pd).
    package static let p2p: UInt16 = 8080
}

@MainActor
@Observable
package final class KwaaiNetManager {

    package private(set) var status = KwaaiNetStatus()
    package private(set) var isTransitioning = false
    package private(set) var lastError: String?
    package private(set) var setupState: SetupState = .notNeeded
    package private(set) var currentAuthToken: String?

    private var healthCheckTask: Task<Void, Never>?
    private var serveProcess: Process?
    private var serveStderrPipe: Pipe?
    private var lastChatStartFailed = false

    /// URLSession with a short timeout for API checks.
    private static let apiSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 5
        return URLSession(configuration: config)
    }()

    /// Locates the kwaainet binary in the app bundle or system PATH.
    package var binaryPath: String? {
        if let bundlePath = Bundle.main.url(
            forAuxiliaryExecutable: "kwaainet"
        )?.path {
            return bundlePath
        }
        #if DEBUG
        return ProcessRunner.findInPath("kwaainet")
        #else
        Logger.kwaainet.error("kwaainet binary not found in app bundle")
        return nil
        #endif
    }

    /// Starts the KwaaiNet P2P daemon for network contribution.
    /// The local chat API is started lazily via startChatApi().
    package func start() async {
        guard !isTransitioning else { return }
        guard let binary = binaryPath else {
            lastError = "kwaainet binary not found"
            Logger.kwaainet.error("kwaainet binary not found in bundle or PATH")
            return
        }

        isTransitioning = true
        lastError = nil
        Logger.kwaainet.info("Starting KwaaiNet daemon")

        // 1. Verify binary code signature (Release builds only)
        let verification = BinaryVerifier.verify(binaryPath: binary)
        if case .invalid(let reason) = verification {
            lastError = "Binary signature invalid: \(reason)"
            Logger.security.error("Refusing to launch unsigned binary: \(reason)")
            isTransitioning = false
            return
        }

        // 2. Check ONLY the P2P port (API port is checked lazily by startChatApi)
        if !PortChecker.isPortAvailable(KwaaiNetPorts.p2p) && !status.isDaemonRunning {
            lastError = "Port \(KwaaiNetPorts.p2p) already in use. KwaaiNet cannot start."
            Logger.network.error("Port \(KwaaiNetPorts.p2p) conflict")
            isTransitioning = false
            return
        }

        // 3. First-run setup detection
        if needsSetup() {
            setupState = .running("Setting up KwaaiNet configuration...")
            Logger.kwaainet.info("First-run setup needed")

            do {
                let setupResult = try await ProcessRunner.run(
                    executablePath: binary,
                    arguments: ["setup"]
                )
                if !setupResult.succeeded {
                    let err = setupResult.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
                    setupState = .failed(err)
                    lastError = "KwaaiNet setup failed: \(err)"
                    isTransitioning = false
                    return
                }
                setupState = .completed
            } catch {
                setupState = .failed(error.localizedDescription)
                lastError = "KwaaiNet setup failed: \(error.localizedDescription)"
                isTransitioning = false
                return
            }
        }

        // 4. Generate auth token for this session
        currentAuthToken = AuthTokenManager.generateToken()

        // 5. Start P2P daemon (only this; chat API is opt-in)
        do {
            var env: [String: String] = [:]
            if let token = currentAuthToken {
                env[AuthTokenManager.envVarName] = token
            }

            let result = try await ProcessRunner.run(
                executablePath: binary,
                arguments: ["start", "--daemon"],
                environment: env.isEmpty ? nil : env
            )

            if !result.succeeded {
                let err = result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
                if !err.contains("already running") {
                    Logger.kwaainet.warning("kwaainet start --daemon: \(err)")
                }
            }
        } catch {
            Logger.kwaainet.warning("Failed to start P2P daemon: \(error)")
        }

        // 6. Verify daemon started
        try? await Task.sleep(for: .seconds(2))
        await refreshStatus()
        if status.isDaemonRunning {
            startHealthPolling()
        } else {
            lastError = "Daemon did not start"
        }

        isTransitioning = false
    }

    /// Starts the chat API server using a local Ollama model.
    /// Auto-detects the best model for this machine. Call when chat opens.
    /// Resets the failure guard on explicit user retry.
    package func startChatApi(retry: Bool = false) async {
        guard serveProcess == nil else { return }
        if lastChatStartFailed && !retry {
            // Don't auto-retry on failure; user must explicitly retry
            return
        }
        guard let binary = binaryPath else {
            lastError = "kwaainet binary not found"
            lastChatStartFailed = true
            return
        }

        // Check API port availability
        if !PortChecker.isPortAvailable(KwaaiNetPorts.api) {
            lastError = "Port \(KwaaiNetPorts.api) already in use. Stop the conflicting service."
            lastChatStartFailed = true
            return
        }

        // Detect a local Ollama model to use
        guard let model = OllamaModels.bestAvailable() else {
            lastError = "No Ollama models found. Install one with: ollama pull llama3.2:3b"
            lastChatStartFailed = true
            return
        }
        Logger.kwaainet.info("Starting chat API with model: \(model)")

        do {
            try startServeProcess(binary: binary, model: model)
        } catch {
            lastError = "Failed to start chat API: \(error.localizedDescription)"
            lastChatStartFailed = true
            return
        }

        let ready = await waitForApi(timeoutSeconds: 30)
        if !ready {
            // Read stderr after termination to avoid pipe deadlock.
            // Run waitUntilExit off the main actor.
            if let serve = serveProcess {
                serve.terminate()
                await Task.detached { serve.waitUntilExit() }.value
            }
            let stderr = readServeStderr()
            serveProcess = nil
            serveStderrPipe = nil

            if stderr.contains("not found in local cache") {
                lastError = "Model '\(model)' missing. Run: ollama pull \(model)"
            } else if !stderr.isEmpty {
                lastError = "Chat API failed: \(stderr.prefix(200))"
            } else {
                lastError = "Chat API did not become ready"
            }
            lastChatStartFailed = true
        } else {
            lastChatStartFailed = false
            await refreshStatus()
        }
    }

    /// Stops the chat API server but keeps the daemon running.
    /// Async to avoid blocking the main actor on waitUntilExit.
    package func stopChatApi() async {
        guard let serve = serveProcess else { return }
        if serve.isRunning {
            serve.terminate()
            await Task.detached {
                serve.waitUntilExit()
            }.value
        }
        serveProcess = nil
        serveStderrPipe = nil
        status.isApiRunning = false
        status.modelName = nil
    }

    /// Stops all KwaaiNet services.
    package func stop() async {
        guard !isTransitioning else { return }
        guard let binary = binaryPath else { return }

        isTransitioning = true
        lastError = nil
        stopHealthPolling()
        Logger.kwaainet.info("Stopping KwaaiNet services")

        // Stop the chat API first (off-main to avoid blocking)
        await stopChatApi()

        // Stop the P2P daemon
        do {
            let result = try await ProcessRunner.run(
                executablePath: binary,
                arguments: ["stop"]
            )
            if !result.succeeded {
                Logger.kwaainet.warning("kwaainet stop returned non-zero: \(result.stderr)")
            }
        } catch {
            Logger.kwaainet.error("Failed to stop kwaainet: \(error)")
            lastError = error.localizedDescription
        }

        try? await Task.sleep(for: .seconds(1))
        await refreshStatus()
        currentAuthToken = nil
        lastChatStartFailed = false
        isTransitioning = false
    }

    /// Checks the status of both the daemon and the API server.
    package func refreshStatus() async {
        // Check daemon via CLI
        if let binary = binaryPath {
            do {
                let result = try await ProcessRunner.run(
                    executablePath: binary,
                    arguments: ["status"]
                )
                status.isDaemonRunning = result.succeeded
                    && result.stdout.contains("Running")
            } catch {
                status.isDaemonRunning = false
            }
        }

        // Check API server via HTTP
        guard let request = authenticatedRequest(
            url: "http://localhost:\(KwaaiNetPorts.api)/v1/models"
        ) else {
            status.isApiRunning = false
            return
        }

        do {
            let (data, response) = try await Self.apiSession.data(for: request)
            if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                status.isApiRunning = true
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let models = json["data"] as? [[String: Any]],
                   let firstModel = models.first,
                   let modelId = firstModel["id"] as? String {
                    status.modelName = modelId
                }
                return
            }
        } catch {
            Logger.kwaainet.debug("API check failed: \(error.localizedDescription)")
        }

        status.isApiRunning = false
    }

    /// Begins periodic health polling.
    package func startHealthPolling() {
        stopHealthPolling()
        healthCheckTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(10))
                guard !Task.isCancelled else { break }
                await self?.refreshStatus()
            }
        }
    }

    // MARK: - Private

    private func startServeProcess(binary: String, model: String) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: binary)
        // kwaainet serve is GPU-accelerated llama.cpp inference using local Ollama models.
        // Much lighter than shard api (no HF download) and faster (Metal GPU).
        process.arguments = ["serve", "--port", "\(KwaaiNetPorts.api)", model]

        let stderrPipe = Pipe()
        process.standardOutput = FileHandle.nullDevice
        process.standardError = stderrPipe
        serveStderrPipe = stderrPipe

        if let token = currentAuthToken {
            var env = ProcessInfo.processInfo.environment
            env[AuthTokenManager.envVarName] = token
            process.environment = env
        }

        try process.run()
        serveProcess = process
        Logger.kwaainet.info("Started kwaainet serve with model \(model) on port \(KwaaiNetPorts.api)")
    }

    /// Reads any accumulated stderr from the serve process.
    /// Should be called only after process termination to avoid pipe deadlock.
    private func readServeStderr() -> String {
        guard let pipe = serveStderrPipe else { return "" }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }

    private func authenticatedRequest(url: String) -> URLRequest? {
        guard let url = URL(string: url) else { return nil }
        var request = URLRequest(url: url)
        if let token = currentAuthToken {
            AuthTokenManager.applyToken(token, to: &request)
        }
        return request
    }

    /// Checks whether kwaainet first-run setup is needed.
    private func needsSetup() -> Bool {
        let configPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".kwaainet/config.yaml").path
        return !FileManager.default.fileExists(atPath: configPath)
    }

    /// Polls the API endpoint until it responds or the timeout expires.
    private func waitForApi(timeoutSeconds: Int) async -> Bool {
        for _ in 0..<timeoutSeconds {
            try? await Task.sleep(for: .seconds(1))
            guard let request = authenticatedRequest(
                url: "http://localhost:\(KwaaiNetPorts.api)/v1/models"
            ) else { return false }
            do {
                let (_, response) = try await Self.apiSession.data(for: request)
                if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                    return true
                }
            } catch {
                // Keep waiting; model still loading
            }
        }
        return false
    }

    private func stopHealthPolling() {
        healthCheckTask?.cancel()
        healthCheckTask = nil
    }
}
