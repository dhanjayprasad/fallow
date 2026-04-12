// AuthTokenManager.swift
// Generates and manages localhost API authentication tokens.
// Part of Fallow. MIT licence.

import Foundation
import OSLog

/// Stateless utility for generating and applying auth tokens.
package enum AuthTokenManager {

    /// HTTP header name for token authentication.
    package static let headerName = "X-Fallow-Token"

    /// Environment variable name passed to the kwaainet subprocess.
    package static let envVarName = "FALLOW_AUTH_TOKEN"

    /// Generates a cryptographically random 32-byte hex token.
    package static func generateToken() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return bytes.map { String(format: "%02x", $0) }.joined()
    }

    /// Applies a token to an outgoing HTTP request.
    package static func applyToken(_ token: String, to request: inout URLRequest) {
        request.setValue(token, forHTTPHeaderField: headerName)
    }
}
