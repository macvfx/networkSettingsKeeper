import XCTest

final class AddressToolsTests: XCTestCase {
    func testParse() {
        XCTAssertEqual(IPv4.parse("192.0.2.10"), 0xC000020A)
        XCTAssertNil(IPv4.parse("192.0.2"))
        XCTAssertNil(IPv4.parse("192.0.2.256"))
        XCTAssertNil(IPv4.parse("192.0.2.x"))
        XCTAssertEqual(IPv4.string(0xC000020A), "192.0.2.10")
    }

    func testMask() {
        XCTAssertTrue(IPv4.isValidMask(IPv4.parse("255.255.255.0")!))
        XCTAssertTrue(IPv4.isValidMask(IPv4.parse("255.255.252.0")!))
        XCTAssertFalse(IPv4.isValidMask(IPv4.parse("255.0.255.0")!))
        XCTAssertFalse(IPv4.isValidMask(IPv4.parse("255.255.255.255")!))
        XCTAssertFalse(IPv4.isValidMask(0))
    }

    func testCheck() {
        func check(_ candidate: String, router: String? = "192.0.2.1") -> AddressCheck {
            IPv4.check(candidate: candidate, subnetOf: "192.0.2.10", mask: "255.255.255.0", router: router)
        }
        XCTAssertEqual(check("192.0.2.20"), .ok)
        XCTAssertEqual(check("192.0.3.20"), .notInSubnet)
        XCTAssertEqual(check("192.0.2.0"), .networkAddress)
        XCTAssertEqual(check("192.0.2.255"), .broadcastAddress)
        XCTAssertEqual(check("192.0.2.1"), .routerAddress)
        XCTAssertEqual(check("nonsense"), .invalid)
        XCTAssertEqual(check("192.0.2.1", router: nil), .ok)
    }

    func testCandidatesSkipRouterAndWrap() {
        let next = IPv4.hostCandidates(after: "192.0.2.253", mask: "255.255.255.0", router: "192.0.2.1", limit: 3)
        XCTAssertEqual(next, ["192.0.2.254", "192.0.2.2", "192.0.2.3"])
        let small = IPv4.hostCandidates(after: "192.0.2.1", mask: "255.255.255.252", router: nil, limit: 10)
        XCTAssertEqual(small, ["192.0.2.2"])
    }
}
