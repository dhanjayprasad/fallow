// BinaryVerifierTests.swift
// Unit tests for binary code signature verification.
// Part of Fallow. MIT licence.

import Testing
import Foundation
@testable import FallowCore

@Suite("BinaryVerifier")
struct BinaryVerifierTests {

    @Test("Debug builds skip verification")
    func debugSkipsVerification() {
        let result = BinaryVerifier.verify(binaryPath: "/usr/bin/true")
        #if DEBUG
        #expect(result == .skipped)
        #else
        #expect(result == .valid)
        #endif
    }

    @Test("Nonexistent path handled correctly")
    func nonexistentPath() {
        let result = BinaryVerifier.verify(binaryPath: "/nonexistent/binary")
        #if DEBUG
        #expect(result == .skipped)
        #else
        #expect(result != .valid)
        #endif
    }
}
