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

    /// Starts the KwaaiNet P2P daemon and local API server.
    package func start() async {
        guard !isTransitioning else { return }
        guard let binary = binaryPath else {
            lastError = "kwaainet binary not found"
            Logger.kwaainet.error("kwaainet binary not found in bundle or PATH")
            return
        }

        isTransitioning = true
        lastError = nil
        Logger.kwaainet.info("Starting KwaaiNet services")

        // 1. Verify binary code signature (Release builds only)
        let verification = BinaryVerifier.verify(binaryPath: binary)
        if case .invalid(let reason) = verification {
            lastError = "Binary signature invalid: \(reason)"
            Logger.security.error("Refusing to launch unsigned binary: \(reason)")
            isTransitioning = false
            return
        }

        // 2. Check port availability
        var portsToCheck: [UInt16] = [KwaaiNetPorts.api]
        // Only check P2P port if no daemon is already running
        if !status.isDaemonRunning {
            portsToCheck.append(KwaaiNetPorts.p2p)
        }
        let conflicts = portsToCheck.compactMap { port in
            PortChecker.isPortAvailable(port) ? nil : PortChecker.Conflict(port: port, processName: nil)
        }
        if !conflicts.isEmpty {
            let desc = conflicts.map { "Port \($0.port)" }.joined(separator: ", ")
            lastError = "\(desc) already in use. KwaaiNet cannot start."
            Logger.network.error("Port conflicts detected: \(desc)")
            isTransitioning = false
            return
        }

        // 3. First-run setup detection
        if needsSetup() {
            setupState = .running("Setting up KwaaiNet configuration...")
            Logger.kwaainet.info("First-run setup needed, running kwaainet setup")

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

        // 5. Start P2P daemon for network contribution
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
                // Non-fatal: daemon might already be running
                if !err.contains("already running") {
                    Logger.kwaainet.warning("kwaainet start --daemon: \(err)")
                }
            }
        } catch {
            Logger.kwaainet.warning("Failed to start P2P daemon: \(error)")
        }

        // Note: the chat API server (kwaainet shard api) is NOT started here.
        // It requires the full model files locally (~5GB) and would crash
        // low-RAM machines. Chat is opt-in via startChatApi() called from
        // the chat window when the user explicitly wants to chat.

        // Verify daemon actually started
        try? await Task.sleep(for: .seconds(2))
        await refreshStatus()
        if status.isDaemonRunning {
            startHealthPolling()
        } else {
            lastError = "Daemon did not start"
        }

        isTransitioning = false
    }

    /// Starts the chat API server (kwaainet shard api). This requires the
    /// model files in the local HuggingFace cache and may use significant
    /// memory. Call only when the user explicitly opens chat.
    package func startChatApi() async {
        guard serveProcess == nil else { return }
        guard let binary = binaryPath else {
            lastError = "kwaainet binary not found"
            return
        }

        do {
            try startShardApiProcess(binary: binary)
        } catch {
            lastError = "Failed to start chat API: \(error.localizedDescription)"
            return
        }

        let ready = await waitForApi(timeoutSeconds: 30)
        if !ready {
            let stderr = readServeStderr()
            if stderr.contains("not found in local cache") {
                lastError = "Chat needs model files. Run: kwaainet shard download"
            } else if !stderr.isEmpty {
                lastError = "Chat API failed: \(stderr.prefix(200))"
            } else {
                lastError = "Chat API did not become ready"
            }
            // Stop the failed process
            serveProcess?.terminate()
            serveProcess = nil
            serveStderrPipe = nil
        } else {
            await refreshStatus()
        }
    }

    /// Stops the chat API server but keeps the daemon running.
    package func stopChatApi() {
        if let serve = serveProcess, serve.isRunning {
            serve.terminate()
            serve.waitUntilExit()
        }
        serveProcess = nil
        serveStderrPipe = nil
        status.isApiRunning = false
    }

    /// Stops all KwaaiNet services.
    package func stop() async {
        guard !isTransitioning else { return }
        guard let binary = binaryPath else { return }

        isTransitioning = true
        lastError = nil
        stopHealthPolling()
        Logger.kwaainet.info("Stopping KwaaiNet services")

        // Stop the serve process first
        if let serve = serveProcess, serve.isRunning {
            serve.terminate()
            serve.waitUntilExit()
        }
        serveProcess = nil
        serveStderrPipe = nil

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
        let apiBase = "http://localhost:\(KwaaiNetPorts.api)"
        guard let request = authenticatedRequest(url: "\(apiBase)/v1/models") else {
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

    private func startShardApiProcess(binary: String) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: binary)

        // shard api uses distributed inference: hosts a few blocks locally,
        // routes the rest through the P2P network. Much lighter than serve.
        process.arguments = ["shard", "api", "--port", "\(KwaaiNetPorts.api)"]

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
        Logger.kwaainet.info("Started kwaainet serve on port \(KwaaiNetPorts.api)")
    }

    /// Reads any accumulated stderr from the serve process.
    private func readServeStderr() -> String {
        guard let pipe = serveStderrPipe else { return "" }
        let data = pipe.fileHandleForReading.availableData
        guard !data.isEmpty else { return "" }
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
        let exists = FileManager.default.fileExists(atPath: configPath)
        if !exists {
            Logger.kwaainet.info("KwaaiNet config not found at \(configPath)")
        }
        return !exists
    }

    /// Polls the API endpoint until it responds or the timeout expires.
    private func waitForApi(timeoutSeconds: Int) async -> Bool {
        let apiBase = "http://localhost:\(KwaaiNetPorts.api)"
        for _ in 0..<timeoutSeconds {
            try? await Task.sleep(for: .seconds(1))
            guard let request = authenticatedRequest(url: "\(apiBase)/v1/models") else {
                return false
            }
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
