// PortChecker.swift
// Detects port conflicts before starting KwaaiNet.
// Part of Fallow. MIT licence.

import Foundation
import OSLog

package enum PortChecker {

    package struct Conflict: Sendable {
        package let port: UInt16
        package let processName: String?
    }

    /// Checks whether the given TCP port is available by attempting to bind.
    package static func isPortAvailable(_ port: UInt16) -> Bool {
        let sock = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP)
        guard sock >= 0 else { return false }
        defer { close(sock) }

        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = port.bigEndian
        addr.sin_addr.s_addr = inet_addr("127.0.0.1")

        var reuseAddr: Int32 = 1
        setsockopt(sock, SOL_SOCKET, SO_REUSEADDR, &reuseAddr, socklen_t(MemoryLayout<Int32>.size))

        let bindResult = withUnsafePointer(to: &addr) { addrPtr in
            addrPtr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                bind(sock, sockaddrPtr, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }

        return bindResult == 0
    }

    /// Checks both KwaaiNet ports and returns any conflicts found.
    package static func checkKwaaiNetPorts() -> [Conflict] {
        var conflicts: [Conflict] = []
        let ports: [UInt16] = [KwaaiNetPorts.p2p, KwaaiNetPorts.api]

        for port in ports {
            if !isPortAvailable(port) {
                let processName = identifyProcess(onPort: port)
                conflicts.append(Conflict(port: port, processName: processName))
                Logger.network.warning("Port \(port) is already in use\(processName.map { " by \($0)" } ?? "")")
            }
        }

        return conflicts
    }

    // MARK: - Private

    /// Best-effort identification of the process using a port.
    private static func identifyProcess(onPort port: UInt16) -> String? {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        process.arguments = ["-ti", ":\(port)"]
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        guard (try? process.run()) != nil else { return nil }
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let pidStr = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: "\n").first else { return nil }

        let psProcess = Process()
        let psPipe = Pipe()
        psProcess.executableURL = URL(fileURLWithPath: "/bin/ps")
        psProcess.arguments = ["-p", String(pidStr), "-o", "comm="]
        psProcess.standardOutput = psPipe
        psProcess.standardError = FileHandle.nullDevice

        guard (try? psProcess.run()) != nil else { return nil }
        psProcess.waitUntilExit()

        let psData = psPipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: psData, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
