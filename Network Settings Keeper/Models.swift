import Foundation

struct IPv4Settings: Codable, Equatable {
    var method: String
    var addresses: [String] = []
    var subnetMasks: [String] = []
    var router: String?

    var summary: String {
        guard method == "Manual" else { return method }
        let address = addresses.first ?? "?"
        let mask = subnetMasks.first ?? "?"
        return "Manual \(address) / \(mask)" + (router.map { ", router \($0)" } ?? "")
    }
}

struct DNSSettings: Codable, Equatable {
    var servers: [String] = []
    var searchDomains: [String] = []
}

/// Values stored in the interface's own configuration: only present when set explicitly.
struct LinkSettings: Codable, Equatable {
    var mtu: Int?
    var mediaSubType: String?
    var mediaOptions: [String] = []
}

struct ServiceSettings: Codable, Equatable {
    var ipv4: IPv4Settings
    var dns: DNSSettings
    var link: LinkSettings

    /// Human-readable list of what differs from `saved` (empty when everything matches).
    func differences(from saved: ServiceSettings) -> [String] {
        var diffs: [String] = []
        if ipv4.method != saved.ipv4.method {
            diffs.append("IPv4 is \(ipv4.method), saved \(saved.ipv4.method)")
        }
        if ipv4.addresses != saved.ipv4.addresses {
            diffs.append("Address \(ipv4.addresses.joined(separator: ", ").nonEmpty), saved \(saved.ipv4.addresses.joined(separator: ", ").nonEmpty)")
        }
        if ipv4.subnetMasks != saved.ipv4.subnetMasks {
            diffs.append("Subnet mask \(ipv4.subnetMasks.joined(separator: ", ").nonEmpty), saved \(saved.ipv4.subnetMasks.joined(separator: ", ").nonEmpty)")
        }
        if ipv4.router != saved.ipv4.router {
            diffs.append("Router \(ipv4.router ?? "none"), saved \(saved.ipv4.router ?? "none")")
        }
        if dns.servers != saved.dns.servers {
            diffs.append("DNS \(dns.servers.joined(separator: ", ").nonEmpty), saved \(saved.dns.servers.joined(separator: ", ").nonEmpty)")
        }
        if dns.searchDomains != saved.dns.searchDomains {
            diffs.append("Search domains \(dns.searchDomains.joined(separator: ", ").nonEmpty), saved \(saved.dns.searchDomains.joined(separator: ", ").nonEmpty)")
        }
        if link.mtu != saved.link.mtu {
            diffs.append("MTU \(link.mtu.map(String.init) ?? "default"), saved \(saved.link.mtu.map(String.init) ?? "default")")
        }
        if link.mediaSubType != saved.link.mediaSubType || link.mediaOptions != saved.link.mediaOptions {
            diffs.append("Speed and duplex \(link.mediaSubType ?? "automatic"), saved \(saved.link.mediaSubType ?? "automatic")")
        }
        return diffs
    }
}

private extension String {
    var nonEmpty: String { isEmpty ? "none" : self }
}

/// A network service as macOS currently has it configured.
struct ServiceInfo: Identifiable {
    let id: String
    let name: String
    let bsdName: String?
    let mac: String?
    let isPresent: Bool
    let isEnabled: Bool
    let settings: ServiceSettings
}

/// A known-good configuration, tied to the adapter's hardware address rather than to the
/// service name, because macOS names a new service when the adapter moves to another port.
struct Profile: Codable, Identifiable, Equatable {
    var id = UUID()
    var label: String
    var mac: String
    var savedServiceName: String
    var savedAt = Date()
    var settings: ServiceSettings
}

enum ProfileStatus: Equatable {
    case adapterAbsent
    case matches(serviceName: String)
    case differs(serviceID: String, serviceName: String, differences: [String])
}

struct LogEntry: Identifiable {
    let id = UUID()
    let date = Date()
    let text: String
}
