import Foundation

extension SplatCanonicalSHAsset {
    /// Derives the content-addressed SH3 path from a digest that was freshly produced by
    /// `SplatCompletionVerifier`. This avoids re-reading a potentially hundreds-of-megabytes
    /// legacy `.splat` immediately after completion verification while preserving the same
    /// content-addressed naming invariant.
    static func canonicalURL(
        forLegacySplat sourceURL: URL,
        verifiedDigest: String
    ) throws -> URL {
        guard sourceURL.isFileURL,
              FileManager.default.fileExists(atPath: sourceURL.path) else {
            throw CanonicalError.sourceMissing
        }

        let normalized = verifiedDigest.lowercased()
        let isSHA256 = normalized.count == 64 && normalized.utf8.allSatisfy { byte in
            (48...57).contains(byte) || (97...102).contains(byte)
        }
        guard isSHA256 else {
            throw CanonicalError.sourceMissing
        }

        return sourceURL.deletingLastPathComponent()
            .appendingPathComponent("result.sh3-\(normalized).ply")
    }
}
