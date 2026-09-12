import Foundation
import simd

enum SplatViewerCameraDatasetLoader {
    private struct Dataset: Decodable {
        let frames: [Frame]
    }

    private struct Frame: Decodable {
        let transformMatrix: [[Float]]

        enum CodingKeys: String, CodingKey {
            case transformMatrix = "transform_matrix"
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

        func position(at index: Int) -> SIMD3<Float>? {
            let matrix = dataset.frames[index].transformMatrix
            guard matrix.count >= 3,
                  matrix[0].count >= 4,
                  matrix[1].count >= 4,
                  matrix[2].count >= 4 else { return nil }
            let position = SIMD3<Float>(matrix[0][3], matrix[1][3], matrix[2][3])
            guard position.x.isFinite, position.y.isFinite, position.z.isFinite else { return nil }
            return position
        }

        let frameCount = dataset.frames.count
        guard frameCount > maximumReturnedPositions else {
            return dataset.frames.indices.compactMap(position(at:))
        }

        // Viewer orientation only needs the capture trajectory envelope. Keep a deterministic,
        // evenly spaced sample including both endpoints instead of materializing every camera
        // position for very long captures. This bounds downstream normalization/sort work while
        // preserving the beginning and end of the scan path.
        var positions: [SIMD3<Float>] = []
        positions.reserveCapacity(maximumReturnedPositions)
        let denominator = maximumReturnedPositions - 1
        let lastFrameIndex = frameCount - 1
        for slot in 0..<maximumReturnedPositions {
            let index = slot * lastFrameIndex / denominator
            if let value = position(at: index) {
                positions.append(value)
            }
        }
        return positions
    }
}
