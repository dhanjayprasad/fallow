// BinaryVerifier.swift
// Verifies code signatures on bundled helper binaries.
// Part of Fallow. MIT licence.

import Foundation
import Security
import OSLog

package enum BinaryVerifier {

    package enum VerificationResult: Sendable, Equatable {
        case valid
        case invalid(String)
        case skipped
    }

    /// Verifies the code signature of the binary at the given path.
    /// In DEBUG builds, verification is skipped (development binaries are unsigned).
    package static func verify(binaryPath: String) -> VerificationResult {
        #if DEBUG
        Logger.security.info("Skipping signature verification in debug build for \(binaryPath)")
        return .skipped
        #else
        guard FileManager.default.isExecutableFile(atPath: binaryPath) else {
            return .invalid("Binary not found or not executable: \(binaryPath)")
        }

        let url = URL(fileURLWithPath: binaryPath)
        var staticCode: SecStaticCode?
        let createStatus = SecStaticCodeCreateWithPath(
            url as CFURL,
            SecCSFlags(rawValue: 0),
            &staticCode
        )

        guard createStatus == errSecSuccess, let code = staticCode else {
            return .invalid("Could not create static code object (status: \(createStatus))")
        }

        let checkStatus = SecStaticCodeCheckValidity(
            code,
            SecCSFlags(rawValue: kSecCSCheckAllArchitectures),
            nil
        )

        if checkStatus == errSecSuccess {
            Logger.security.info("Code signature valid for \(binaryPath)")
            return .valid
        } else {
            return .invalid("Signature verification failed (status: \(checkStatus))")
        }
        #endif
    }
}
