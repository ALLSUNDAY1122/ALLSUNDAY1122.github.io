import Foundation

private struct L2AW34FakeResolver: IOHostResolving {
    let addresses: [String]
    func resolveNumericAddresses(host: String) throws -> [String] { addresses }
}

@main
struct L2AW34ResolutionGuardSelfCheck {
    static func main() throws {
        let publicAddresses = ["8.8.8.8", "1.1.1.1", "2606:4700:4700::1111"]
        let blockedAddresses = [
            "0.0.0.0", "10.0.0.1", "100.64.0.1", "127.0.0.1", "169.254.1.1",
            "172.16.0.1", "192.168.1.1", "198.18.0.1", "224.0.0.1",
            "::", "::1", "fe80::1", "fc00::1", "ff02::1", "2001:db8::1",
            "::ffff:127.0.0.1", "::ffff:10.0.0.1"
        ]
        for address in publicAddresses {
            precondition(IOPublicHostResolutionPolicy.isPublicNumericAddress(address), address)
        }
        for address in blockedAddresses {
            precondition(!IOPublicHostResolutionPolicy.isPublicNumericAddress(address), address)
        }

        try IOPublicHostResolutionPolicy.requirePublic(
            addresses: publicAddresses,
            host: "public.test"
        )
        var mixedRejected = false
        do {
            try IOPublicHostResolutionPolicy.requirePublic(
                addresses: ["8.8.8.8", "10.0.0.8"],
                host: "mixed.test"
            )
        } catch {
            mixedRejected = true
        }
        precondition(mixedRejected)

        let privateGuard = IOPublicHostResolutionGuard(
            resolver: L2AW34FakeResolver(addresses: ["192.168.1.20"])
        )
        var resolverGuardRejected = false
        do {
            try privateGuard.validate(url: URL(string: "https://music.example/file.mp3")!)
        } catch {
            resolverGuardRejected = true
        }
        precondition(resolverGuardRejected)

        print(
            "L2_AW34_SELF_TEST_PASS public=\(publicAddresses.count) blocked=\(blockedAddresses.count) mixed_dns_rejected=\(mixedRejected) hostname_private_resolution_rejected=\(resolverGuardRejected)"
        )
    }
}
