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
              let dataset = try? JSONDecoder().decode(Dataset.self, from: data) else {
            return []
        }

        return dataset.frames.compactMap { frame in
            let matrix = frame.transformMatrix
            guard matrix.count >= 3,
                  matrix[0].count >= 4,
                  matrix[1].count >= 4,
                  matrix[2].count >= 4 else { return nil }
            let position = SIMD3<Float>(matrix[0][3], matrix[1][3], matrix[2][3])
            guard position.x.isFinite, position.y.isFinite, position.z.isFinite else { return nil }
            return position
        }
    }
}
