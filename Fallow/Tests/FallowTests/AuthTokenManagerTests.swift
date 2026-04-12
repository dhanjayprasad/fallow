// AuthTokenManagerTests.swift
// Unit tests for authentication token generation.
// Part of Fallow. MIT licence.

import Testing
import Foundation
@testable import FallowCore

@Suite("AuthTokenManager")
struct AuthTokenManagerTests {

    @Test("Token is 64 hex characters (32 bytes)")
    func tokenLength() {
        let token = AuthTokenManager.generateToken()
        #expect(token.count == 64)
    }

    @Test("Two tokens are different")
    func tokenUniqueness() {
        let token1 = AuthTokenManager.generateToken()
        let token2 = AuthTokenManager.generateToken()
        #expect(token1 != token2)
    }

    @Test("Token contains only hex characters")
    func tokenHexOnly() {
        let token = AuthTokenManager.generateToken()
        let hexChars = CharacterSet(charactersIn: "0123456789abcdef")
        let tokenChars = CharacterSet(charactersIn: token)
        #expect(tokenChars.isSubset(of: hexChars))
    }

    @Test("Token is applied to URLRequest")
    func tokenApplied() {
        var request = URLRequest(url: URL(string: "http://localhost:8080/health")!)
        AuthTokenManager.applyToken("test-token-123", to: &request)
        #expect(request.value(forHTTPHeaderField: "X-Fallow-Token") == "test-token-123")
    }
}
