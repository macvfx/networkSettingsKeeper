import Foundation
import Security
import SystemConfiguration

enum RestoreError: LocalizedError {
    case authorizationDenied
    case serviceNotFound
    case invalidProfile(String)
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .authorizationDenied: "Administrator approval was not given."
        case .serviceNotFound: "The network service is no longer present."
        case .invalidProfile(let why): "The saved settings are not valid: \(why)"
        case .failed(let why): "macOS did not accept the change: \(why)"
        }
    }
}

/// Writes saved settings back to a network service through the SystemConfiguration framework.
/// Changing network preferences needs administrator approval, which macOS asks for.
enum Restorer {
    static func apply(_ settings: ServiceSettings, toServiceID serviceID: String) throws {
        try validate(settings)
        let auth = try authorization()
        defer { AuthorizationFree(auth, []) }

        guard let prefs = SCPreferencesCreateWithAuthorization(nil, ServiceReader.appName, nil, auth),
              SCPreferencesLock(prefs, true) else {
            throw RestoreError.failed(scMessage())
        }
        defer { SCPreferencesUnlock(prefs) }

        guard let services = SCNetworkServiceCopyAll(prefs) as? [SCNetworkService],
              let service = services.first(where: { SCNetworkServiceGetServiceID($0) as String? == serviceID }),
              let interface = SCNetworkServiceGetInterface(service) else {
            throw RestoreError.serviceNotFound
        }

        try setProtocol(service, kSCNetworkProtocolTypeIPv4, ipv4Config(settings.ipv4))
        try setProtocol(service, kSCNetworkProtocolTypeDNS, dnsConfig(settings.dns))

        var link = SCNetworkInterfaceGetConfiguration(interface) as? [String: Any] ?? [:]
        link[kSCPropNetEthernetMTU as String] = settings.link.mtu
        link[kSCPropNetEthernetMediaSubType as String] = settings.link.mediaSubType
        link[kSCPropNetEthernetMediaOptions as String] = settings.link.mediaOptions.isEmpty ? nil : settings.link.mediaOptions
        guard SCNetworkInterfaceSetConfiguration(interface, link as CFDictionary) else {
            throw RestoreError.failed(scMessage())
        }

        guard SCPreferencesCommitChanges(prefs), SCPreferencesApplyChanges(prefs) else {
            throw RestoreError.failed(scMessage())
        }
    }

    // MARK: Building configuration

    private static func ipv4Config(_ ipv4: IPv4Settings) -> [String: Any] {
        var config: [String: Any] = [kSCPropNetIPv4ConfigMethod as String: ipv4.method]
        if ipv4.method == kSCValNetIPv4ConfigMethodManual as String {
            config[kSCPropNetIPv4Addresses as String] = ipv4.addresses
            config[kSCPropNetIPv4SubnetMasks as String] = ipv4.subnetMasks
            if let router = ipv4.router { config[kSCPropNetIPv4Router as String] = router }
        }
        return config
    }

    private static func dnsConfig(_ dns: DNSSettings) -> [String: Any] {
        var config: [String: Any] = [:]
        if !dns.servers.isEmpty { config[kSCPropNetDNSServerAddresses as String] = dns.servers }
        if !dns.searchDomains.isEmpty { config[kSCPropNetDNSSearchDomains as String] = dns.searchDomains }
        return config
    }

    private static func setProtocol(_ service: SCNetworkService, _ type: CFString, _ config: [String: Any]) throws {
        let proto = SCNetworkServiceCopyProtocol(service, type)
            ?? (SCNetworkServiceAddProtocolType(service, type) ? SCNetworkServiceCopyProtocol(service, type) : nil)
        guard let proto, SCNetworkProtocolSetConfiguration(proto, config as CFDictionary) else {
            throw RestoreError.failed(scMessage())
        }
    }

    // MARK: Validation and authorization

    private static func validate(_ settings: ServiceSettings) throws {
        let ipv4 = settings.ipv4
        let addresses = ipv4.addresses + ipv4.subnetMasks + (ipv4.router.map { [$0] } ?? []) + settings.dns.servers
        for value in addresses where !isIPAddress(value) {
            throw RestoreError.invalidProfile("\"\(value)\" is not an IP address")
        }
        if ipv4.method == kSCValNetIPv4ConfigMethodManual as String,
           ipv4.addresses.isEmpty || ipv4.addresses.count != ipv4.subnetMasks.count {
            throw RestoreError.invalidProfile("manual configuration needs an address and subnet mask")
        }
    }

    private static func isIPAddress(_ text: String) -> Bool {
        var v4 = in_addr(), v6 = in6_addr()
        return inet_pton(AF_INET, text, &v4) == 1 || inet_pton(AF_INET6, text, &v6) == 1
    }

    private static func authorization() throws -> AuthorizationRef {
        var auth: AuthorizationRef?
        guard AuthorizationCreate(nil, nil, [], &auth) == errAuthorizationSuccess, let auth else {
            throw RestoreError.authorizationDenied
        }
        let status = "system.services.systemconfiguration.network".withCString { name -> OSStatus in
            var item = AuthorizationItem(name: name, valueLength: 0, value: nil, flags: 0)
            return withUnsafeMutablePointer(to: &item) { pointer in
                var rights = AuthorizationRights(count: 1, items: pointer)
                return AuthorizationCopyRights(auth, &rights, nil,
                                               [.interactionAllowed, .extendRights, .preAuthorize], nil)
            }
        }
        guard status == errAuthorizationSuccess else {
            AuthorizationFree(auth, [])
            throw RestoreError.authorizationDenied
        }
        return auth
    }

    private static func scMessage() -> String {
        String(cString: SCErrorString(SCError()))
    }
}
