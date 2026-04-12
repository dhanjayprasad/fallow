// KwaaiNetManager.swift
// Manages the KwaaiNet binary lifecycle: start, stop, health checks.
// Part of Fallow. MIT licence.

import Foundation
import OSLog

/// Information about the running KwaaiNet node.
package struct KwaaiNetStatus: Sendable {
    package var isRunning: Bool = false
    package var modelName: String?
    package var connectionCount: Int?

    package init(isRunning: Bool = false, modelName: String? = nil, connectionCount: Int? = nil) {
        self.isRunning = isRunning
        self.modelName = modelName
        self.connectionCount = connectionCount
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

@MainActor
@Observable
package final class KwaaiNetManager {

    package private(set) var status = KwaaiNetStatus()
    package private(set) var isTransitioning = false
    package private(set) var lastError: String?
    package private(set) var setupState: SetupState = .notNeeded
    package private(set) var currentAuthToken: String?

    private var healthCheckTask: Task<Void, Never>?

    /// URLSession with a short timeout for health checks and model discovery.
    private static let healthSession: URLSession = {
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

    /// Starts the KwaaiNet daemon with full pre-flight checks.
    package func start() async {
        guard !isTransitioning else { return }
        guard let binary = binaryPath else {
            lastError = "kwaainet binary not found"
            Logger.kwaainet.error("kwaainet binary not found in bundle or PATH")
            return
        }

        isTransitioning = true
        lastError = nil
        Logger.kwaainet.info("Starting kwaainet daemon")

        // 1. Verify binary code signature (Release builds only)
        let verification = BinaryVerifier.verify(binaryPath: binary)
        if case .invalid(let reason) = verification {
            lastError = "Binary signature invalid: \(reason)"
            Logger.security.error("Refusing to launch unsigned binary: \(reason)")
            isTransitioning = false
            return
        }

        // 2. Check port availability
        let conflicts = PortChecker.checkKwaaiNetPorts()
        if !conflicts.isEmpty {
            let desc = conflicts.map { conflict in
                "Port \(conflict.port)\(conflict.processName.map { " (used by \($0))" } ?? "")"
            }.joined(separator: ", ")
            lastError = "\(desc) already in use. KwaaiNet cannot start."
            Logger.network.error("Port conflicts detected: \(desc)")
            isTransitioning = false
            return
        }

        // 3. First-run setup detection
        if needsSetup() {
            setupState = .running("Setting up KwaaiNet identity and dependencies...")
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
                    Logger.kwaainet.error("kwaainet setup failed: \(err)")
                    isTransitioning = false
                    return
                }
                setupState = .completed
                Logger.kwaainet.info("kwaainet setup completed successfully")
            } catch {
                setupState = .failed(error.localizedDescription)
                lastError = "KwaaiNet setup failed: \(error.localizedDescription)"
                isTransitioning = false
                return
            }
        }

        // 4. Generate auth token for this session
        currentAuthToken = AuthTokenManager.generateToken()
        Logger.kwaainet.info("Generated auth token for daemon session")

        // 5. Launch the daemon with auth token in environment
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
                lastError = result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
                Logger.kwaainet.error("kwaainet start failed: \(result.stderr)")
                isTransitioning = false
                return
            }

            // 6. Wait for daemon to become ready
            let ready = await waitForHealth(timeoutSeconds: 30)
            if !ready {
                lastError = "KwaaiNet daemon did not become ready in time"
                Logger.kwaainet.warning("Health check did not succeed within timeout")
            }
            await refreshStatus()
            if status.isRunning {
                startHealthPolling()
            }
        } catch {
            lastError = error.localizedDescription
            Logger.kwaainet.error("Failed to launch kwaainet: \(error)")
        }

        isTransitioning = false
    }

    /// Stops the KwaaiNet daemon gracefully.
    package func stop() async {
        guard !isTransitioning else { return }
        guard let binary = binaryPath else { return }

        isTransitioning = true
        lastError = nil
        stopHealthPolling()
        Logger.kwaainet.info("Stopping kwaainet daemon")

        do {
            let result = try await ProcessRunner.run(
                executablePath: binary,
                arguments: ["stop"]
            )

            if !result.succeeded {
                Logger.kwaainet.warning("kwaainet stop returned non-zero: \(result.stderr)")
            }

            try await Task.sleep(for: .seconds(2))
            await refreshStatus()
        } catch {
            Logger.kwaainet.error("Failed to stop kwaainet: \(error)")
            lastError = error.localizedDescription
        }

        currentAuthToken = nil
        isTransitioning = false
    }

    /// Queries the KwaaiNet health endpoint and updates status.
    package func refreshStatus() async {
        guard let request = authenticatedRequest(
            url: "http://localhost:8080/health"
        ) else { return }

        do {
            let (_, response) = try await Self.healthSession.data(for: request)
            if let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode == 200 {
                status.isRunning = true
                await fetchModelInfo()
                return
            }
        } catch {
            Logger.kwaainet.debug("Health check failed: \(error.localizedDescription)")
        }

        status = KwaaiNetStatus(isRunning: false)
    }

    /// Begins periodic health polling. Call when attaching to an existing daemon.
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

    /// Creates a URLRequest with the current auth token header.
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
        let identityPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".kwaainet/identity.key").path
        let exists = FileManager.default.fileExists(atPath: identityPath)
        if !exists {
            Logger.kwaainet.info("KwaaiNet identity key not found at \(identityPath)")
        }
        return !exists
    }

    /// Polls the health endpoint until it responds or the timeout expires.
    private func waitForHealth(timeoutSeconds: Int) async -> Bool {
        for _ in 0..<timeoutSeconds {
            try? await Task.sleep(for: .seconds(1))
            guard let request = authenticatedRequest(
                url: "http://localhost:8080/health"
            ) else { return false }
            do {
                let (_, response) = try await Self.healthSession.data(for: request)
                if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                    return true
                }
            } catch {
                // Keep waiting; daemon may still be starting
            }
        }
        return false
    }

    private func fetchModelInfo() async {
        guard let request = authenticatedRequest(
            url: "http://localhost:8000/v1/models"
        ) else { return }

        do {
            let (data, _) = try await Self.healthSession.data(for: request)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let models = json["data"] as? [[String: Any]],
               let firstModel = models.first,
               let modelId = firstModel["id"] as? String {
                status.modelName = modelId
            }
        } catch {
            Logger.kwaainet.debug("Could not fetch model info: \(error)")
        }
    }

    private func stopHealthPolling() {
        healthCheckTask?.cancel()
        healthCheckTask = nil
    }
}
