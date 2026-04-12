// KwaaiNetManager.swift
// Manages the KwaaiNet binary lifecycle: start, stop, health checks.
// Part of Fallow. MIT licence.

import Foundation
import OSLog

/// Information about the running KwaaiNet node.
struct KwaaiNetStatus: Sendable {
    var isRunning: Bool = false
    var modelName: String?
    var connectionCount: Int?
}

@MainActor
@Observable
final class KwaaiNetManager {

    private(set) var status = KwaaiNetStatus()
    private(set) var isTransitioning = false
    private(set) var lastError: String?

    private var healthCheckTask: Task<Void, Never>?

    /// URLSession with a short timeout for health checks.
    private static let healthSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 5
        return URLSession(configuration: config)
    }()

    /// Locates the kwaainet binary in the app bundle or system PATH.
    var binaryPath: String? {
        if let bundlePath = Bundle.main.url(
            forAuxiliaryExecutable: "kwaainet"
        )?.path {
            return bundlePath
        }
        #if DEBUG
        // Fall back to system PATH only in debug builds for development
        return ProcessRunner.findInPath("kwaainet")
        #else
        Logger.kwaainet.error("kwaainet binary not found in app bundle")
        return nil
        #endif
    }

    /// Starts the KwaaiNet daemon.
    func start() async {
        guard !isTransitioning else { return }
        guard let binary = binaryPath else {
            lastError = "kwaainet binary not found"
            Logger.kwaainet.error("kwaainet binary not found in bundle or PATH")
            return
        }

        isTransitioning = true
        lastError = nil
        Logger.kwaainet.info("Starting kwaainet daemon")

        do {
            let result = try await ProcessRunner.run(
                executablePath: binary,
                arguments: ["start", "--daemon"]
            )

            if !result.succeeded {
                lastError = result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
                Logger.kwaainet.error("kwaainet start failed: \(result.stderr)")
                isTransitioning = false
                return
            }

            // Wait for daemon to become ready (may take longer on first run)
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
    func stop() async {
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

        isTransitioning = false
    }

    /// Queries the KwaaiNet health endpoint and updates status.
    func refreshStatus() async {
        guard let healthURL = URL(string: "http://localhost:8080/health") else { return }

        do {
            let (_, response) = try await Self.healthSession.data(from: healthURL)
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
    func startHealthPolling() {
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

    /// Polls the health endpoint until it responds or the timeout expires.
    private func waitForHealth(timeoutSeconds: Int) async -> Bool {
        for _ in 0..<timeoutSeconds {
            try? await Task.sleep(for: .seconds(1))
            guard let healthURL = URL(string: "http://localhost:8080/health") else { return false }
            do {
                let (_, response) = try await Self.healthSession.data(from: healthURL)
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
        guard let modelsURL = URL(string: "http://localhost:8000/v1/models") else { return }

        do {
            let (data, _) = try await Self.healthSession.data(from: modelsURL)
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
