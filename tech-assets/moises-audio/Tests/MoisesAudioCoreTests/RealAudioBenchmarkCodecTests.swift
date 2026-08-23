import Foundation
import XCTest
@testable import MoisesAudioCore

final class RealAudioBenchmarkCodecTests: XCTestCase {
    func testManifestUsesISO8601RoundTrip() throws {
        let createdAt = Date(timeIntervalSince1970: 1_800_000_000)
        let manifest = AnalysisRealAudioBenchmarkManifest(
            manifestID: "codec-test",
            createdAt: createdAt,
            cases: [
                AnalysisRealAudioBenchmarkCase(
                    fixtureID: "fixture",
                    projectID: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
                    assetID: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
                    relativePath: "fixtures/a.wav",
                    genre: "test",
                    sourceKind: .syntheticTest,
                    expectedDurationSeconds: 1,
                    rights: AnalysisRightsEvidence(
                        grantID: "test",
                        rightsClass: .projectOwned,
                        permittedUses: [.analysisBenchmark],
                        sourceSHA256: String(repeating: "a", count: 64)
                    ),
                    reference: AnalysisReferenceAnnotation(bpm: 120)
                )
            ]
        )

        let data = try AnalysisRealAudioBenchmarkCodec.encodeManifest(manifest)
        let text = try XCTUnwrap(String(data: data, encoding: .utf8))
        XCTAssertTrue(text.contains("2027-01-15T08:00:00Z") || text.contains("2027-01-15T08:00:00.000Z"))
        XCTAssertEqual(try AnalysisRealAudioBenchmarkCodec.decodeManifest(data), manifest)
    }
}
