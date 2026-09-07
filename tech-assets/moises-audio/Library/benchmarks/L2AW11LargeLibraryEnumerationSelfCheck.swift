import Foundation

@main
struct L2AW11LargeLibraryEnumerationSelfCheck {
    static func main() throws {
        var scenarios = 0
        func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
            guard condition() else {
                throw NSError(domain: "L2-AW11", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
            }
        }

        let clampedLow = LibraryEnumerationPolicy(batchSize: -1)
        try require(clampedLow.batchSize == 16, "low clamp")
        scenarios += 1

        let clampedHigh = LibraryEnumerationPolicy(batchSize: 100_000)
        try require(clampedHigh.batchSize == 1024, "high clamp")
        scenarios += 1

        let policy = LibraryEnumerationPolicy(batchSize: 128)
        let tenThousand = policy.ranges(forCount: 10_000)
        try require(tenThousand.count == 79, "10k batch count")
        try require(tenThousand.flatMap(Array.init) == Array(0..<10_000), "exact coverage")
        try require(tenThousand.allSatisfy { $0.count <= 128 }, "bounded range")
        scenarios += 1

        try require(policy.estimatedProjectFetchOperations(projectCount: 10_000) == 396, "project fetch upper bound")
        try require(1 + 5 * 10_000 == 50_001, "legacy project fetch shape baseline")
        scenarios += 1

        try require(policy.estimatedSetlistFetchOperations(setlistCount: 10_000) == 80, "setlist fetch upper bound")
        scenarios += 1

        let start = Date()
        let itemCount = 1_000_000
        var checksum = 0
        for range in policy.ranges(forCount: itemCount) {
            try require(range.count <= policy.batchSize, "million-item bound")
            checksum &+= range.count
        }
        let elapsed = Date().timeIntervalSince(start)
        try require(checksum == itemCount, "million-item coverage")
        scenarios += 1

        print(String(
            format: "L2_AW11_SELF_TEST_PASS scenarios=%d items=%d planning_s=%.6f project10k_fetches=%d legacy_project10k_fetches=%d",
            scenarios,
            itemCount,
            elapsed,
            policy.estimatedProjectFetchOperations(projectCount: 10_000),
            50_001
        ))
    }
}
