// CreditLedger.swift
// Local credit tracking for compute contribution and chat usage.
// Part of Fallow. MIT licence.

import Foundation
import OSLog

@MainActor
@Observable
final class CreditLedger {

    /// Total credits earned from contributing compute.
    private(set) var creditsEarned: Double = 0

    /// Total credits spent on chat.
    private(set) var creditsSpent: Double = 0

    /// Current balance.
    var balance: Double { creditsEarned - creditsSpent }

    /// Total time contributed in seconds.
    private(set) var totalContributionSeconds: TimeInterval = 0

    /// Rate: credits earned per minute of contribution.
    let creditsPerMinute: Double = 1.0

    private var contributionStartTime: Date?
    private var accrualTask: Task<Void, Never>?
    private var accrualSecondsAdded: TimeInterval = 0

    init() {
        loadFromDisk()
    }

    /// Begin tracking a contribution session.
    func startContribution() {
        guard contributionStartTime == nil else { return }
        contributionStartTime = Date()
        accrualSecondsAdded = 0
        startAccrual()
        Logger.credits.info("Contribution session started")
    }

    /// End the current contribution session.
    func stopContribution() {
        accrualTask?.cancel()
        accrualTask = nil

        guard let startTime = contributionStartTime else { return }
        let totalDuration = Date().timeIntervalSince(startTime)
        // Only add the portion not already counted by the accrual loop
        let remainingSeconds = max(0, totalDuration - accrualSecondsAdded)
        totalContributionSeconds += remainingSeconds
        creditsEarned += (remainingSeconds / 60.0) * creditsPerMinute
        contributionStartTime = nil

        saveToDisk()
        Logger.credits.info("Contribution session ended. Balance: \(self.balance)")
    }

    /// Deduct credits for a chat interaction. Returns true if sufficient balance.
    @discardableResult
    func spendCredits(_ amount: Double) -> Bool {
        guard amount > 0, balance >= amount else { return false }
        creditsSpent += amount
        saveToDisk()
        Logger.credits.info("Spent \(amount) credits. Balance: \(self.balance)")
        return true
    }

    // MARK: - Private

    private func startAccrual() {
        accrualTask?.cancel()
        accrualTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(60))
                guard !Task.isCancelled else { break }
                guard let self, self.contributionStartTime != nil else { break }
                self.creditsEarned += self.creditsPerMinute
                self.totalContributionSeconds += 60
                self.accrualSecondsAdded += 60
                self.saveToDisk()
            }
        }
    }

    // MARK: - Persistence

    private static let earnedKey = "creditsEarned"
    private static let spentKey = "creditsSpent"
    private static let contributionTimeKey = "totalContributionSeconds"

    private func saveToDisk() {
        let defaults = UserDefaults.standard
        defaults.set(creditsEarned, forKey: Self.earnedKey)
        defaults.set(creditsSpent, forKey: Self.spentKey)
        defaults.set(totalContributionSeconds, forKey: Self.contributionTimeKey)
    }

    private func loadFromDisk() {
        let defaults = UserDefaults.standard
        creditsEarned = defaults.double(forKey: Self.earnedKey)
        creditsSpent = defaults.double(forKey: Self.spentKey)
        totalContributionSeconds = defaults.double(forKey: Self.contributionTimeKey)
    }
}
