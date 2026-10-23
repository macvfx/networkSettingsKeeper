import Foundation
import Observation

/// State of the import review sheet: a profile read from a file, the adapter it will be set up
/// on, and the (possibly changed) address.
@MainActor
@Observable
final class ImportDraft: Identifiable {
    enum Probe: Equatable { case idle, checking, inUse, noReply }

    let id = UUID()
    let portable: PortableProfile
    var label: String
    var targetID: String?
    /// Editing the address invalidates any earlier "in use" result.
    var addressText: String {
        didSet {
            if addressText != oldValue { probe = .idle; suggestionNote = nil }
        }
    }
    private(set) var probe: Probe = .idle
    private(set) var suggesting = false
    private(set) var suggestionNote: String?

    init(portable: PortableProfile, defaultTarget: ServiceInfo?) {
        self.portable = portable
        label = portable.label
        targetID = defaultTarget?.id
        addressText = portable.settings.ipv4.addresses.first ?? ""
    }

    var isManual: Bool { portable.settings.ipv4.method == "Manual" }
    var fileAddress: String { portable.settings.ipv4.addresses.first ?? "" }
    var mask: String { portable.settings.ipv4.subnetMasks.first ?? "" }
    var router: String? { portable.settings.ipv4.router }
    var trimmedAddress: String { addressText.trimmingCharacters(in: .whitespaces) }
    var addressChanged: Bool { trimmedAddress != fileAddress }

    var addressCheck: AddressCheck {
        isManual ? IPv4.check(candidate: trimmedAddress, subnetOf: fileAddress, mask: mask, router: router) : .ok
    }

    var addressMessage: String? {
        switch addressCheck {
        case .ok: nil
        case .invalid: "Not a valid IPv4 address."
        case .notInSubnet: "Outside the original network (\(fileAddress) with mask \(mask))."
        case .networkAddress: "That is the network address, which cannot be used by a device."
        case .broadcastAddress: "That is the broadcast address, which cannot be used by a device."
        case .routerAddress: "That is the router's address."
        }
    }

    /// The settings to save: the file's, with the chosen address. Speed and duplex are only kept
    /// when the file came from this same adapter, since another model may not support them.
    func settings(for target: ServiceInfo) -> ServiceSettings {
        var settings = portable.settings
        if isManual { settings.ipv4.addresses = [trimmedAddress] }
        if portable.sourceHardwareAddress?.lowercased() != target.mac {
            settings.link.mediaSubType = nil
            settings.link.mediaOptions = []
        }
        return settings
    }

    var droppedMedia: Bool {
        portable.settings.link.mediaSubType != nil
    }

    func checkAddress(interface: String?) async {
        guard addressCheck == .ok else { return }
        probe = .checking
        let inUse = await AddressProbe.replies(from: trimmedAddress, interface: interface)
        probe = inUse ? .inUse : .noReply
    }

    func suggestFree(interface: String?) async {
        guard isManual else { return }
        let start = IPv4.parse(trimmedAddress) != nil ? trimmedAddress : fileAddress
        suggesting = true
        suggestionNote = nil
        defer { suggesting = false }
        for candidate in IPv4.hostCandidates(after: start, mask: mask, router: router, limit: 12) {
            if await !AddressProbe.replies(from: candidate, interface: interface) {
                addressText = candidate
                probe = .noReply
                suggestionNote = "Nothing answered at \(candidate). Not a guarantee it is free."
                return
            }
        }
        suggestionNote = "Every address tried is in use. Enter one by hand."
    }
}
