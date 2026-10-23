import Foundation

enum AddressCheck: Equatable {
    case ok, invalid, notInSubnet, networkAddress, broadcastAddress, routerAddress
}

/// IPv4 helpers for validating a new address against a network.
enum IPv4 {
    static func parse(_ text: String) -> UInt32? {
        let parts = text.trimmingCharacters(in: .whitespaces).split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 4 else { return nil }
        var value: UInt32 = 0
        for part in parts {
            guard (1...3).contains(part.count), part.allSatisfy(\.isNumber),
                  let octet = UInt32(part), octet <= 255 else { return nil }
            value = value << 8 | octet
        }
        return value
    }

    static func string(_ value: UInt32) -> String {
        "\(value >> 24).\((value >> 16) & 255).\((value >> 8) & 255).\(value & 255)"
    }

    /// A contiguous mask that leaves at least two host bits (so /30 or wider).
    static func isValidMask(_ mask: UInt32) -> Bool {
        let host = ~mask
        return mask != 0 && host & (host &+ 1) == 0 && host >= 3
    }

    static func isIPAddress(_ text: String) -> Bool {
        var v4 = in_addr(), v6 = in6_addr()
        return inet_pton(AF_INET, text, &v4) == 1 || inet_pton(AF_INET6, text, &v6) == 1
    }

    /// Whether `candidate` is a usable host address on the network that `reference` and `mask` define.
    static func check(candidate: String, subnetOf reference: String, mask: String, router: String?) -> AddressCheck {
        guard let c = parse(candidate), let r = parse(reference), let m = parse(mask), isValidMask(m) else {
            return .invalid
        }
        guard c & m == r & m else { return .notInSubnet }
        if c == c & m { return .networkAddress }
        if c == c & m | ~m { return .broadcastAddress }
        if let router, parse(router) == c { return .routerAddress }
        return .ok
    }

    /// Usable host addresses after `start`, wrapping inside the network, skipping `start` and the router.
    static func hostCandidates(after start: String, mask: String, router: String?, limit: Int) -> [String] {
        guard let s = parse(start), let m = parse(mask), isValidMask(m) else { return [] }
        let network = s & m
        let first = network + 1
        let last = (network | ~m) - 1
        let routerValue = router.flatMap(parse)
        var result: [String] = []
        var next = s
        for _ in 0..<(last - first + 1) {
            next = next >= last ? first : next + 1
            if next == s || next == routerValue { continue }
            result.append(string(next))
            if result.count == limit { break }
        }
        return result
    }
}
