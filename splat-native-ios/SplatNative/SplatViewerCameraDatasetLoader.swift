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
            var validPositionIndex = 0
            var retentionStride = 1
            var lastValidPosition: SIMD3<Float>?

            while !frames.isAtEnd {
                let frame = try frames.decode(Frame.self)
                guard let position = frame.position else { continue }
                lastValidPosition = position

                if validPositionIndex % retentionStride == 0 {
                    decodedPositions.append(position)
                }
                validPositionIndex += 1

                // A 32 MiB JSON file can still contain tens or hundreds of thousands of compact
                // frames. Keep decode memory bounded while preserving samples across the complete
                // trajectory. Whenever the temporary sample exceeds 2x the final budget, retain
                // every other entry and double the future stride; the first sample remains fixed
                // and later samples continue on the same global cadence.
                if decodedPositions.count > maximumReturnedPositions * 2 {
                    var compacted: [SIMD3<Float>] = []
                    compacted.reserveCapacity(maximumReturnedPositions + 1)
                    for index in stride(from: 0, to: decodedPositions.count, by: 2) {
                        compacted.append(decodedPositions[index])
                    }
                    decodedPositions = compacted
                    if retentionStride <= Int.max / 2 {
                        retentionStride *= 2
                    }
                }
            }

            var sampled = Self.evenlySampled(decodedPositions, limit: maximumReturnedPositions)
            // The final camera pose is useful to trajectory-envelope normalization and was retained
            // by the previous post-decode sampler. Online compaction can end between stride slots,
            // so explicitly keep the true endpoint without allowing the working array to grow.
            if let lastValidPosition, !sampled.isEmpty {
                sampled[sampled.count - 1] = lastValidPosition
            }
            positions = sampled
        }

        private static func evenlySampled(_ positions: [SIMD3<Float>], limit: Int) -> [SIMD3<Float>] {
            guard positions.count > limit, limit > 1 else { return positions }
            var sampled: [SIMD3<Float>] = []
            sampled.reserveCapacity(limit)
            let denominator = limit - 1
            let lastIndex = positions.count - 1
            for slot in 0..<limit {
                let product = slot.multipliedFullWidth(by: lastIndex)
                let index = denominator.dividingFullWidth(product).quotient
                sampled.append(positions[index])
            }
            return sampled
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
        return dataset.positions
    }
}
