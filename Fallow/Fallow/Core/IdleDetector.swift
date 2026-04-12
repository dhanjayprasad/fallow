// IdleDetector.swift
// Detects user idle time using IOKit HID idle time.
// Part of Fallow. MIT licence.

import Foundation
import IOKit
import OSLog

@MainActor
@Observable
final class IdleDetector {

    /// Seconds since the user last interacted with the Mac.
    private(set) var idleSeconds: TimeInterval = 0

    /// Threshold in seconds to consider the user idle. Default: 5 minutes.
    var idleThreshold: TimeInterval = 300

    /// Whether the user is currently considered idle.
    var isIdle: Bool {
        idleSeconds >= idleThreshold
    }

    private var pollingTask: Task<Void, Never>?

    func startDetecting() {
        stopDetecting()

        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                self?.refresh()
                try? await Task.sleep(for: .seconds(5))
            }
        }

        Logger.governor.info("Idle detection started (threshold: \(self.idleThreshold)s)")
    }

    func stopDetecting() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    // MARK: - Private

    private func refresh() {
        idleSeconds = Self.systemIdleTime()
    }

    /// Reads system-wide HID idle time from the IOKit registry.
    private static func systemIdleTime() -> TimeInterval {
        var iterator: io_iterator_t = 0

        guard IOServiceGetMatchingServices(
            kIOMainPortDefault,
            IOServiceMatching("IOHIDSystem"),
            &iterator
        ) == KERN_SUCCESS else {
            return 0
        }
        defer { IOObjectRelease(iterator) }

        let entry = IOIteratorNext(iterator)
        guard entry != 0 else { return 0 }
        defer { IOObjectRelease(entry) }

        var unmanagedDict: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(
            entry, &unmanagedDict, kCFAllocatorDefault, 0
        ) == KERN_SUCCESS else {
            return 0
        }

        guard let dict = unmanagedDict?.takeRetainedValue() as NSDictionary?,
              let idleTimeNS = dict["HIDIdleTime"] as? Int64 else {
            return 0
        }

        // HIDIdleTime is in nanoseconds
        return TimeInterval(idleTimeNS) / 1_000_000_000
    }
}
