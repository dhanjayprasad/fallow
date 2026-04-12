// PortCheckerTests.swift
// Unit tests for port conflict detection.
// Part of Fallow. MIT licence.

import Testing
import Foundation
@testable import FallowCore

@Suite("PortChecker")
struct PortCheckerTests {

    @Test("High ephemeral port is available")
    func availablePort() {
        let available = PortChecker.isPortAvailable(59123)
        #expect(available == true)
    }

    @Test("Occupied port is detected")
    func occupiedPort() {
        let sock = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP)
        #expect(sock >= 0)

        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = UInt16(59124).bigEndian
        addr.sin_addr.s_addr = inet_addr("127.0.0.1")

        let bindResult = withUnsafePointer(to: &addr) { addrPtr in
            addrPtr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                bind(sock, sockaddrPtr, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        #expect(bindResult == 0)

        let available = PortChecker.isPortAvailable(59124)
        close(sock)
        #expect(available == false)
    }
}
