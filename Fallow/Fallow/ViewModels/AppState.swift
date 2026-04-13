// AppState.swift
// Central application state coordinating all subsystems.
// Part of Fallow. MIT licence.

import SwiftUI
import OSLog

@MainActor
@Observable
package final class AppState {

    package let kwaaiNetManager: KwaaiNetManager
    package let systemMonitor: SystemMonitor
    package let idleDetector: IdleDetector
    package let creditLedger: CreditLedger
    package let resourceGovernor: ResourceGovernor

    /// Whether auto-contribution mode is enabled.
    package var autoContribute: Bool = true {
        didSet { evaluateContribution() }
    }

    /// Whether the user has completed the onboarding consent flow.
    /// Backed by a stored property so @Observable tracks changes for SwiftUI.
    package var hasCompletedOnboarding: Bool {
        didSet { UserDefaults.standard.set(hasCompletedOnboarding, forKey: "hasCompletedOnboarding") }
    }

    /// SF Symbol name for the menu bar icon.
    package var menuBarIcon: String {
        if kwaaiNetManager.isTransitioning {
            return "arrow.triangle.2.circlepath"
        }
        return kwaaiNetManager.status.isRunning ? "circle.fill" : "circle"
    }

    /// Colour for the menu bar icon.
    package var menuBarColour: Color {
        if kwaaiNetManager.isTransitioning { return .orange }
        return kwaaiNetManager.status.isRunning ? .green : .secondary
    }

    /// Human-readable status string.
    package var statusText: String {
        if kwaaiNetManager.isTransitioning { return "Starting..." }
        if !kwaaiNetManager.status.isRunning { return "Stopped" }
        if let model = kwaaiNetManager.status.modelName {
            return "Contributing: \(model)"
        }
        return "Running"
    }

    /// Formatted contribution time.
    package var contributionTimeFormatted: String {
        let total = creditLedger.totalContributionSeconds
        let hours = Int(total) / 3600
        let minutes = (Int(total) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    private var governorTask: Task<Void, Never>?
    private var hasPerformedSetup = false
    /// Set to true when the user manually starts contribution.
    /// The governor loop will not auto-stop in this case.
    private var manuallyStarted = false

    package init() {
        let manager = KwaaiNetManager()
        let monitor = SystemMonitor()
        let detector = IdleDetector()
        let ledger = CreditLedger()

        self.kwaaiNetManager = manager
        self.systemMonitor = monitor
        self.idleDetector = detector
        self.creditLedger = ledger
        self.resourceGovernor = ResourceGovernor(
            systemMonitor: monitor,
            idleDetector: detector
        )
        self.hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")

        Logger.app.info("AppState initialised")
    }

    /// Called once from the view layer to kick off async setup.
    package func initialSetup() async {
        guard !hasPerformedSetup else { return }
        hasPerformedSetup = true

        systemMonitor.startMonitoring()
        idleDetector.startDetecting()

        await kwaaiNetManager.refreshStatus()
        if kwaaiNetManager.status.isRunning {
            kwaaiNetManager.startHealthPolling()
            // Only start earning credits if the user has already given consent
            if hasCompletedOnboarding {
                creditLedger.startContribution()
            }
        }

        // Only start auto-contribution after user has given consent
        if hasCompletedOnboarding {
            startGovernorLoop()
        }

        setupTerminationHandler()
    }

    /// Called when the user completes onboarding; starts the governor loop.
    package func onOnboardingComplete() {
        startGovernorLoop()
    }

    /// Toggle contribution on or off.
    package func toggleContribution() async {
        if kwaaiNetManager.status.isRunning {
            manuallyStarted = false
            resourceGovernor.isManuallyPaused = true
            creditLedger.stopContribution()
            await kwaaiNetManager.stop()
        } else {
            manuallyStarted = true
            resourceGovernor.isManuallyPaused = false
            await kwaaiNetManager.start()
            if kwaaiNetManager.status.isRunning {
                creditLedger.startContribution()
            }
        }
    }

    // MARK: - Private

    private func evaluateContribution() {
        if !autoContribute {
            governorTask?.cancel()
            governorTask = nil
        } else {
            startGovernorLoop()
        }
    }

    private func startGovernorLoop() {
        governorTask?.cancel()
        governorTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(15))
                guard !Task.isCancelled else { break }
                guard let self else { break }
                guard self.autoContribute else { continue }

                let evaluation = self.resourceGovernor.evaluate()

                if evaluation.shouldContribute
                    && !self.kwaaiNetManager.status.isRunning
                    && !self.kwaaiNetManager.isTransitioning {
                    await self.kwaaiNetManager.start()
                    if self.kwaaiNetManager.status.isRunning {
                        self.creditLedger.startContribution()
                    }
                } else if !evaluation.shouldContribute
                    && self.kwaaiNetManager.status.isRunning
                    && !self.kwaaiNetManager.isTransitioning
                    && !self.manuallyStarted {
                    // Only auto-stop if not manually started by the user.
                    // Manual start should persist until manual stop.
                    self.creditLedger.stopContribution()
                    await self.kwaaiNetManager.stop()
                }
            }
        }
    }

    private func setupTerminationHandler() {
        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            // queue: .main guarantees we are on the main thread.
            // MainActor.assumeIsolated is the official bridge for
            // callback-based APIs that are known to run on the main actor.
            MainActor.assumeIsolated {
                self.handleTermination()
            }
        }
    }

    private func handleTermination() {
        creditLedger.stopContribution()
        guard kwaaiNetManager.status.isRunning,
              let binary = kwaaiNetManager.binaryPath else { return }

        Logger.app.info("App terminating, stopping kwaainet")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: binary)
        process.arguments = ["stop"]
        guard (try? process.run()) != nil else { return }

        // Give kwaainet stop up to 5 seconds to complete.
        // Note: process.terminate() would only kill this CLI client,
        // not the daemonised KwaaiNet node, so we just log on timeout.
        let semaphore = DispatchSemaphore(value: 0)
        DispatchQueue.global().async {
            process.waitUntilExit()
            semaphore.signal()
        }
        if semaphore.wait(timeout: .now() + 5) == .timedOut {
            Logger.app.warning("kwaainet stop did not complete within timeout; daemon may still be running")
        }
    }
}
