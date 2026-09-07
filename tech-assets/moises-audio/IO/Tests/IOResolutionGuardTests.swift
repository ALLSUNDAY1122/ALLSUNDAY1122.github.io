import Foundation
import XCTest

final class IOResolutionGuardTests: XCTestCase {
    func testPublicIPv4AndIPv6AreAccepted() throws {
        XCTAssertTrue(IOPublicHostResolutionPolicy.isPublicNumericAddress("8.8.8.8"))
        XCTAssertTrue(IOPublicHostResolutionPolicy.isPublicNumericAddress("1.1.1.1"))
        XCTAssertTrue(IOPublicHostResolutionPolicy.isPublicNumericAddress("2606:4700:4700::1111"))
        XCTAssertNoThrow(
            try IOPublicHostResolutionPolicy.requirePublic(
                addresses: ["8.8.8.8", "2606:4700:4700::1111"],
                host: "example.test"
            )
        )
    }

    func testPrivateReservedAndMappedAddressesAreRejected() throws {
        let blocked = [
            "0.0.0.0", "10.0.0.1", "100.64.0.1", "127.0.0.1", "169.254.1.1",
            "172.16.0.1", "192.168.1.1", "198.18.0.1", "224.0.0.1", "255.255.255.255",
            "::", "::1", "fe80::1", "fc00::1", "fd00::1", "ff02::1", "2001:db8::1",
            "::ffff:127.0.0.1", "::ffff:10.0.0.1"
        ]
        for address in blocked {
            XCTAssertFalse(IOPublicHostResolutionPolicy.isPublicNumericAddress(address), address)
        }
    }

    func testMixedPublicPrivateDNSAnswerFailsClosed() throws {
        XCTAssertThrowsError(
            try IOPublicHostResolutionPolicy.requirePublic(
                addresses: ["8.8.8.8", "10.0.0.8"],
                host: "mixed.test"
            )
        ) { error in
            XCTAssertEqual(error as? IODirectDownloadFailure, .localNetworkHost("mixed.test"))
        }
    }

    func testGuardUsesResolverForHostname() throws {
        let guardPolicy = IOPublicHostResolutionGuard(
            resolver: FakeResolver(addresses: ["192.168.0.20"])
        )
        XCTAssertThrowsError(try guardPolicy.validate(url: URL(string: "https://music.example/file.mp3")!))
    }

    private struct FakeResolver: IOHostResolving {
        let addresses: [String]
        func resolveNumericAddresses(host: String) throws -> [String] { addresses }
    }
}
