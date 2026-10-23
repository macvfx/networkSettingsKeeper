import Foundation

/// A quick "does anything answer at this address" check using ping. It is a hint, not a
/// guarantee: a device that does not answer ping, or a network the adapter is not on yet,
/// looks free.
enum AddressProbe {
    static func replies(from address: String, interface: String?) async -> Bool {
        guard IPv4.parse(address) != nil else { return false }
        return await withCheckedContinuation { continuation in
            let ping = Process()
            ping.executableURL = URL(fileURLWithPath: "/sbin/ping")
            var arguments = ["-c", "1", "-W", "800", "-t", "2"]
            if let interface { arguments += ["-b", interface] }
            ping.arguments = arguments + [address]
            ping.standardOutput = FileHandle.nullDevice
            ping.standardError = FileHandle.nullDevice
            ping.terminationHandler = { continuation.resume(returning: $0.terminationStatus == 0) }
            do { try ping.run() } catch { continuation.resume(returning: false) }
        }
    }
}
