// CreditLedgerTests.swift
// Unit tests for the CreditLedger credit tracking system.
// Part of Fallow. MIT licence.

import XCTest
@testable import FallowCore

final class CreditLedgerTests: XCTestCase {

    private func makeTestDefaults() -> UserDefaults {
        let suiteName = "com.fallow.test.\(UUID().uuidString)"
        return UserDefaults(suiteName: suiteName)!
    }

    @MainActor
    func testInitialBalanceZero() {
        let ledger = CreditLedger(defaults: makeTestDefaults())
        XCTAssertEqual(ledger.balance, 0)
        XCTAssertEqual(ledger.creditsEarned, 0)
        XCTAssertEqual(ledger.creditsSpent, 0)
    }

    @MainActor
    func testSpendReducesBalance() {
        let defaults = makeTestDefaults()
        defaults.set(10.0, forKey: "creditsEarned")
        let ledger = CreditLedger(defaults: defaults)

        let success = ledger.spendCredits(3.0)
        XCTAssertTrue(success)
        XCTAssertEqual(ledger.balance, 7.0)
    }

    @MainActor
    func testSpendFailsInsufficientBalance() {
        let ledger = CreditLedger(defaults: makeTestDefaults())
        let success = ledger.spendCredits(5.0)
        XCTAssertFalse(success)
        XCTAssertEqual(ledger.balance, 0)
    }

    @MainActor
    func testSpendFailsNegativeAmount() {
        let defaults = makeTestDefaults()
        defaults.set(10.0, forKey: "creditsEarned")
        let ledger = CreditLedger(defaults: defaults)

        XCTAssertFalse(ledger.spendCredits(0))
        XCTAssertFalse(ledger.spendCredits(-1))
    }
}
