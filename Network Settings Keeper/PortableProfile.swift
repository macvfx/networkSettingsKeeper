import Foundation
import UniformTypeIdentifiers

/// A saved profile written to a file so it can be set up on another Mac. It leaves out the
/// adapter's hardware address unless asked, so it works as a template for a similar adapter.
struct PortableProfile: Codable, Equatable {
    static let formatName = "network-settings-keeper-profile"
    static let currentVersion = 1
    static let fileExtension = "nskprofile"
    static var contentType: UTType { UTType("com.networksettingskeeper.profile") ?? .json }

    var format = PortableProfile.formatName
    var version = PortableProfile.currentVersion
    var label: String
    var exportedAt = Date()
    var sourceHardwareAddress: String?
    var settings: ServiceSettings

    enum ImportError: LocalizedError {
        case notAProfile
        case unsupportedVersion(Int)
        case invalid(String)

        var errorDescription: String? {
            switch self {
            case .notAProfile: "This file is not a Network Settings Keeper profile."
            case .unsupportedVersion(let v): "This profile is version \(v), which this app version cannot read."
            case .invalid(let why): "The profile is not valid: \(why)"
            }
        }
    }

    func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }

    static func decode(_ data: Data) throws -> PortableProfile {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let profile = try? decoder.decode(PortableProfile.self, from: data),
              profile.format == formatName else { throw ImportError.notAProfile }
        guard profile.version == currentVersion else { throw ImportError.unsupportedVersion(profile.version) }
        if let problem = profile.validationProblem() { throw ImportError.invalid(problem) }
        return profile
    }

    /// Nil when every address in the profile is well formed.
    func validationProblem() -> String? {
        let ipv4 = settings.ipv4
        let values = ipv4.addresses + ipv4.subnetMasks + (ipv4.router.map { [$0] } ?? []) + settings.dns.servers
        if let bad = values.first(where: { !IPv4.isIPAddress($0) }) { return "\"\(bad)\" is not an IP address" }
        if ipv4.method == "Manual" {
            guard let address = ipv4.addresses.first, ipv4.addresses.count == ipv4.subnetMasks.count,
                  IPv4.parse(address) != nil, let mask = ipv4.subnetMasks.first.flatMap(IPv4.parse),
                  IPv4.isValidMask(mask) else {
                return "manual configuration needs an IPv4 address and a valid subnet mask"
            }
        }
        return nil
    }
}
