// CreditLedgerTests.swift
// Unit tests for the CreditLedger credit tracking system.
// Part of Fallow. MIT licence.

import Testing
import Foundation
@testable import FallowCore

@Suite("CreditLedger")
struct CreditLedgerTests {

    private func makeTestDefaults() -> UserDefaults {
        let suiteName = "com.fallow.test.\(UUID().uuidString)"
        return UserDefaults(suiteName: suiteName)!
    }

    @MainActor @Test("Initial balance is zero")
    func initialBalanceZero() {
        let ledger = CreditLedger(defaults: makeTestDefaults())
        #expect(ledger.balance == 0)
        #expect(ledger.creditsEarned == 0)
        #expect(ledger.creditsSpent == 0)
    }

    @MainActor @Test("Spending credits reduces balance")
    func spendReducesBalance() {
        let defaults = makeTestDefaults()
        defaults.set(10.0, forKey: "creditsEarned")
        let ledger = CreditLedger(defaults: defaults)
        let success = ledger.spendCredits(3.0)
        #expect(success == true)
        #expect(ledger.balance == 7.0)
    }

    @MainActor @Test("Spending fails when insufficient balance")
    func spendFailsInsufficientBalance() {
        let ledger = CreditLedger(defaults: makeTestDefaults())
        let success = ledger.spendCredits(5.0)
        #expect(success == false)
        #expect(ledger.balance == 0)
    }

    @MainActor @Test("Spending fails for zero or negative amount")
    func spendFailsNegativeAmount() {
        let defaults = makeTestDefaults()
        defaults.set(10.0, forKey: "creditsEarned")
        let ledger = CreditLedger(defaults: defaults)
        #expect(ledger.spendCredits(0) == false)
        #expect(ledger.spendCredits(-1) == false)
    }
}
