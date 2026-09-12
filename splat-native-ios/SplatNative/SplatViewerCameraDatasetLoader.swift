import Foundation
import simd

enum SplatViewerCameraDatasetLoader {
    private struct Dataset: Decodable {
        let frames: [Frame]
    }

    private struct Frame: Decodable {
        let position: SIMD3<Float>?

        enum CodingKeys: String, CodingKey {
            case transformMatrix = "transform_matrix"
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            guard let matrix = try? container.decode([[Float]].self, forKey: .transformMatrix),
                  matrix.count >= 3,
                  matrix[0].count >= 4,
                  matrix[1].count >= 4,
                  matrix[2].count >= 4 else {
                position = nil
                return
            }
            let candidate = SIMD3<Float>(matrix[0][3], matrix[1][3], matrix[2][3])
            position = candidate.x.isFinite && candidate.y.isFinite && candidate.z.isFinite
                ? candidate
                : nil
        }
    }

    static let maximumTransformsBytes: Int64 = 32 * 1024 * 1024
    static let maximumReturnedPositions = 4_096

    static func cameraPositions(for renderURL: URL, fileManager: FileManager = .default) -> [SIMD3<Float>] {
        let root = renderURL.deletingLastPathComponent().standardizedFileURL
        let url = root.appendingPathComponent("transforms.json").standardizedFileURL
        guard url.deletingLastPathComponent() == root,
              let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey]),
              values.isRegularFile == true,
              values.isSymbolicLink != true,
              let size = values.fileSize,
              size > 0,
              Int64(size) <= maximumTransformsBytes,
              let data = try? Data(contentsOf: url, options: .mappedIfSafe),
              let dataset = try? JSONDecoder().decode(Dataset.self, from: data),
              !dataset.frames.isEmpty else {
            return []
        }

        var validCount = 0
        for frame in dataset.frames where frame.position != nil {
            validCount += 1
        }
        guard validCount > 0 else { return [] }
        guard validCount > maximumReturnedPositions else {
            return dataset.frames.compactMap(\.position)
        }

        // Viewer orientation only needs the capture trajectory envelope. Sample by valid-camera
        // ordinal, not raw frame index, so malformed frames cannot punch holes in the bounded sample.
        // Both capture endpoints are retained when valid. Downstream normalization/sort work stays
        // capped at maximumReturnedPositions regardless of a very long capture.
        var positions: [SIMD3<Float>] = []
        positions.reserveCapacity(maximumReturnedPositions)
        let denominator = maximumReturnedPositions - 1
        let lastValidOrdinal = validCount - 1
        var nextSlot = 0
        var validOrdinal = 0

        for frame in dataset.frames {
            guard let value = frame.position else { continue }
            while nextSlot < maximumReturnedPositions,
                  evenlySpacedIndex(slot: nextSlot, lastIndex: lastValidOrdinal, denominator: denominator) == validOrdinal {
                positions.append(value)
                nextSlot += 1
            }
            validOrdinal += 1
            if nextSlot == maximumReturnedPositions { break }
        }
        return positions
    }

    private static func evenlySpacedIndex(slot: Int, lastIndex: Int, denominator: Int) -> Int {
        guard denominator > 0 else { return 0 }
        let product = slot.multipliedFullWidth(by: lastIndex)
        return denominator.dividingFullWidth(product).quotient
    }
}
