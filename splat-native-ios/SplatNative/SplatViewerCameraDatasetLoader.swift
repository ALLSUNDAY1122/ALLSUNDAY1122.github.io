import Foundation
import simd

enum SplatViewerCameraDatasetLoader {
    private struct Dataset: Decodable {
        let positions: [SIMD3<Float>]

        enum CodingKeys: String, CodingKey {
            case frames
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            var frames = try container.nestedUnkeyedContainer(forKey: .frames)
            var decodedPositions: [SIMD3<Float>] = []
            decodedPositions.reserveCapacity(min(frames.count ?? 0, maximumReturnedPositions * 2))

            while !frames.isAtEnd {
                let frame = try frames.decode(Frame.self)
                if let position = frame.position {
                    decodedPositions.append(position)
                }
            }
            positions = decodedPositions
        }
    }

    private struct Frame: Decodable {
        let position: SIMD3<Float>?

        enum CodingKeys: String, CodingKey {
            case transformMatrix = "transform_matrix"
        }

        init(from decoder: Decoder) throws {
            guard let container = try? decoder.container(keyedBy: CodingKeys.self),
                  var matrix = try? container.nestedUnkeyedContainer(forKey: .transformMatrix) else {
                position = nil
                return
            }

            var translation = SIMD3<Float>.zero
            for rowIndex in 0..<3 {
                guard !matrix.isAtEnd,
                      var row = try? matrix.nestedUnkeyedContainer() else {
                    position = nil
                    return
                }

                var translationComponent: Float?
                for columnIndex in 0..<4 {
                    guard !row.isAtEnd,
                          let value = try? row.decode(Float.self) else {
                        position = nil
                        return
                    }
                    if columnIndex == 3 {
                        translationComponent = value
                    }
                }

                guard let component = translationComponent, component.isFinite else {
                    position = nil
                    return
                }
                translation[rowIndex] = component
            }

            position = translation
        }
    }

    static let maximumTransformsBytes: Int64 = 32 * 1024 * 1024
    static let maximumReturnedPositions = 4_096

    static func cameraPositions(for renderURL: URL, fileManager: FileManager = .default) -> [SIMD3<Float>] {
        let root = renderURL.deletingLastPathComponent().standardizedFileURL
        let url = root.appendingPathComponent("transforms.json").standardizedFileURL
        guard let rootValues = try? root.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey]),
              rootValues.isDirectory == true,
              rootValues.isSymbolicLink != true,
              url.deletingLastPathComponent() == root,
              let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey]),
              values.isRegularFile == true,
              values.isSymbolicLink != true,
              let size = values.fileSize,
              size > 0,
              Int64(size) <= maximumTransformsBytes,
              let data = try? Data(contentsOf: url, options: .mappedIfSafe),
              let dataset = try? JSONDecoder().decode(Dataset.self, from: data),
              !dataset.positions.isEmpty else {
            return []
        }

        let positions = dataset.positions
        guard positions.count > maximumReturnedPositions else { return positions }

        // Viewer orientation only needs the capture trajectory envelope. Both capture endpoints are
        // retained while downstream normalization/sort work stays capped at maximumReturnedPositions
        // regardless of a very long capture.
        var sampled: [SIMD3<Float>] = []
        sampled.reserveCapacity(maximumReturnedPositions)
        let denominator = maximumReturnedPositions - 1
        let lastIndex = positions.count - 1
        for slot in 0..<maximumReturnedPositions {
            sampled.append(positions[evenlySpacedIndex(slot: slot, lastIndex: lastIndex, denominator: denominator)])
        }
        return sampled
    }

    private static func evenlySpacedIndex(slot: Int, lastIndex: Int, denominator: Int) -> Int {
        guard denominator > 0 else { return 0 }
        let product = slot.multipliedFullWidth(by: lastIndex)
        return denominator.dividingFullWidth(product).quotient
    }
}
