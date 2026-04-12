// AuthTokenManagerTests.swift
// Unit tests for authentication token generation.
// Part of Fallow. MIT licence.

import XCTest
@testable import FallowCore

final class AuthTokenManagerTests: XCTestCase {

    func testTokenLength() {
        let token = AuthTokenManager.generateToken()
        XCTAssertEqual(token.count, 64) // 32 bytes = 64 hex chars
    }

    func testTokenUniqueness() {
        let token1 = AuthTokenManager.generateToken()
        let token2 = AuthTokenManager.generateToken()
        XCTAssertNotEqual(token1, token2)
    }

    func testTokenHexOnly() {
        let token = AuthTokenManager.generateToken()
        let hexChars = CharacterSet(charactersIn: "0123456789abcdef")
        let tokenChars = CharacterSet(charactersIn: token)
        XCTAssertTrue(tokenChars.isSubset(of: hexChars))
    }

    func testTokenApplied() {
        var request = URLRequest(url: URL(string: "http://localhost:8080/health")!)
        AuthTokenManager.applyToken("test-token-123", to: &request)
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-Fallow-Token"), "test-token-123")
    }
}
