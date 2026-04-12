// BinaryVerifierTests.swift
// Unit tests for binary code signature verification.
// Part of Fallow. MIT licence.

import XCTest
@testable import FallowCore

final class BinaryVerifierTests: XCTestCase {

    func testDebugSkipsVerification() {
        let result = BinaryVerifier.verify(binaryPath: "/usr/bin/true")
        #if DEBUG
        XCTAssertEqual(result, .skipped)
        #else
        // In release, /usr/bin/true is Apple-signed, should be .valid
        XCTAssertEqual(result, .valid)
        #endif
    }

    func testNonexistentPath() {
        let result = BinaryVerifier.verify(binaryPath: "/nonexistent/binary")
        #if DEBUG
        XCTAssertEqual(result, .skipped)
        #else
        XCTAssertNotEqual(result, .valid)
        #endif
    }
}
