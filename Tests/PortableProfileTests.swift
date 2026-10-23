import XCTest

final class PortableProfileTests: XCTestCase {
    private func sample(method: String = "Manual") -> PortableProfile {
        PortableProfile(
            label: "Example",
            settings: ServiceSettings(
                ipv4: IPv4Settings(method: method, addresses: method == "Manual" ? ["192.0.2.10"] : [],
                                   subnetMasks: method == "Manual" ? ["255.255.255.0"] : [], router: nil),
                dns: DNSSettings(servers: ["192.0.2.53"], searchDomains: ["example.test"]),
                link: LinkSettings(mtu: 9000, mediaSubType: "10GBASE-T", mediaOptions: ["full-duplex"])))
    }

    func testRoundTrip() throws {
        let original = sample()
        let decoded = try PortableProfile.decode(try original.encoded())
        XCTAssertEqual(decoded.label, original.label)
        XCTAssertEqual(decoded.settings, original.settings)
        XCTAssertNil(decoded.sourceHardwareAddress)
    }

    func testRejectsOtherFiles() {
        XCTAssertThrowsError(try PortableProfile.decode(Data("{\"hello\":1}".utf8)))
        XCTAssertThrowsError(try PortableProfile.decode(Data("not json".utf8)))
    }

    func testRejectsNewerVersion() throws {
        var profile = sample()
        profile.version = 99
        XCTAssertThrowsError(try PortableProfile.decode(try profile.encoded())) { error in
            guard case PortableProfile.ImportError.unsupportedVersion(99) = error else {
                return XCTFail("wrong error \(error)")
            }
        }
    }

    func testRejectsBadAddresses() throws {
        var profile = sample()
        profile.settings.ipv4.addresses = ["192.0.2.999"]
        XCTAssertThrowsError(try PortableProfile.decode(try profile.encoded()))
        profile = sample()
        profile.settings.ipv4.subnetMasks = ["255.0.255.0"]
        XCTAssertThrowsError(try PortableProfile.decode(try profile.encoded()))
    }

    func testDHCPProfileIsValid() throws {
        XCTAssertNoThrow(try PortableProfile.decode(try sample(method: "DHCP").encoded()))
    }
}
