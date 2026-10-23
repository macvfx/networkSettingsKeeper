import Foundation
import SystemConfiguration

/// Reads the configured (Setup) state of Ethernet network services from the system preferences.
enum ServiceReader {
    static let appName = "Network Settings Keeper" as CFString

    static func readAll() -> [ServiceInfo] {
        guard let prefs = SCPreferencesCreate(nil, appName, nil),
              let services = SCNetworkServiceCopyAll(prefs) as? [SCNetworkService] else { return [] }
        let presentBSD = Set((SCNetworkInterfaceCopyAll() as? [SCNetworkInterface] ?? [])
            .compactMap { SCNetworkInterfaceGetBSDName($0) as String? })

        return services.compactMap { service in
            guard let interface = SCNetworkServiceGetInterface(service),
                  SCNetworkInterfaceGetInterfaceType(interface) as String? == kSCNetworkInterfaceTypeEthernet as String,
                  let id = SCNetworkServiceGetServiceID(service) as String? else { return nil }
            let bsd = SCNetworkInterfaceGetBSDName(interface) as String?
            return ServiceInfo(
                id: id,
                name: SCNetworkServiceGetName(service) as String? ?? "Unnamed",
                bsdName: bsd,
                mac: (SCNetworkInterfaceGetHardwareAddressString(interface) as String?)?.lowercased(),
                isPresent: bsd.map(presentBSD.contains) ?? false,
                isEnabled: SCNetworkServiceGetEnabled(service),
                settings: settings(of: service, interface: interface))
        }
    }

    static func settings(of service: SCNetworkService, interface: SCNetworkInterface) -> ServiceSettings {
        let ipv4 = protocolConfig(service, kSCNetworkProtocolTypeIPv4)
        let dns = protocolConfig(service, kSCNetworkProtocolTypeDNS)
        let link = SCNetworkInterfaceGetConfiguration(interface) as? [String: Any] ?? [:]
        return ServiceSettings(
            ipv4: IPv4Settings(
                method: ipv4?[kSCPropNetIPv4ConfigMethod as String] as? String ?? "None",
                addresses: ipv4?[kSCPropNetIPv4Addresses as String] as? [String] ?? [],
                subnetMasks: ipv4?[kSCPropNetIPv4SubnetMasks as String] as? [String] ?? [],
                router: ipv4?[kSCPropNetIPv4Router as String] as? String),
            dns: DNSSettings(
                servers: dns?[kSCPropNetDNSServerAddresses as String] as? [String] ?? [],
                searchDomains: dns?[kSCPropNetDNSSearchDomains as String] as? [String] ?? []),
            link: LinkSettings(
                mtu: link[kSCPropNetEthernetMTU as String] as? Int,
                mediaSubType: link[kSCPropNetEthernetMediaSubType as String] as? String,
                mediaOptions: link[kSCPropNetEthernetMediaOptions as String] as? [String] ?? []))
    }

    private static func protocolConfig(_ service: SCNetworkService, _ type: CFString) -> [String: Any]? {
        guard let proto = SCNetworkServiceCopyProtocol(service, type) else { return nil }
        return SCNetworkProtocolGetConfiguration(proto) as? [String: Any]
    }
}
