import Foundation
import simd

enum SplatViewerCameraDatasetLoader {
    private struct Dataset: Decodable {
        let positions: [SIMD3<Float>]

        enum CodingKeys: String, CodingKey { case frames }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            var frames = try container.nestedUnkeyedContainer(forKey: .frames)
            var decodedPositions: [SIMD3<Float>] = []
            decodedPositions.reserveCapacity(min(frames.count ?? 0, maximumReturnedPositions * 2))
            var initialPositions: [SIMD3<Float>] = []
            initialPositions.reserveCapacity(6)
            var validPositionIndex = 0
            var decodedFrameIndex = 0
            var retentionStride = 1
            var lastValidPosition: SIMD3<Float>?

            while !frames.isAtEnd {
                if decodedFrameIndex % cancellationCheckFrameInterval == 0, Task.isCancelled { throw CancellationError() }
                decodedFrameIndex += 1
                let frame = try frames.decode(Frame.self)
                guard let position = frame.position else { continue }
                lastValidPosition = position
                if initialPositions.count < 6 { initialPositions.append(position) }
                if validPositionIndex % retentionStride == 0 { decodedPositions.append(position) }
                validPositionIndex += 1
                if decodedPositions.count > maximumReturnedPositions * 2 {
                    var compacted: [SIMD3<Float>] = []
                    compacted.reserveCapacity(maximumReturnedPositions + 1)
                    for index in stride(from: 0, to: decodedPositions.count, by: 2) { compacted.append(decodedPositions[index]) }
                    decodedPositions = compacted
                    if retentionStride <= Int.max / 2 { retentionStride *= 2 }
                }
            }

            var sampled = Self.evenlySampled(decodedPositions, limit: maximumReturnedPositions)
            if !sampled.isEmpty {
                let prefixCount = min(initialPositions.count, sampled.count)
                for index in 0..<prefixCount { sampled[index] = initialPositions[index] }
            }
            if let lastValidPosition, !sampled.isEmpty { sampled[sampled.count - 1] = lastValidPosition }
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
        enum CodingKeys: String, CodingKey { case transformMatrix = "transform_matrix" }

        init(from decoder: Decoder) throws {
            guard let container = try? decoder.container(keyedBy: CodingKeys.self),
                  var matrix = try? container.nestedUnkeyedContainer(forKey: .transformMatrix) else { position = nil; return }
            var translation = SIMD3<Float>.zero
            for rowIndex in 0..<3 {
                guard !matrix.isAtEnd, var row = try? matrix.nestedUnkeyedContainer() else { position = nil; return }
                var translationComponent: Float?
                for columnIndex in 0..<4 {
                    guard !row.isAtEnd, let value = try? row.decode(Float.self) else { position = nil; return }
                    if columnIndex == 3 { translationComponent = value }
                }
                guard row.isAtEnd else { position = nil; return }
                let safeAccumulationComponent = Float.greatestFiniteMagnitude / Float(maximumReturnedPositions * 2)
                guard let component = translationComponent, component.isFinite, abs(component) <= safeAccumulationComponent else { position = nil; return }
                translation[rowIndex] = component
            }
            guard !matrix.isAtEnd, var finalRow = try? matrix.nestedUnkeyedContainer() else { position = nil; return }
            var tail: [Float] = []
            tail.reserveCapacity(4)
            for _ in 0..<4 {
                guard !finalRow.isAtEnd, let value = try? finalRow.decode(Float.self), value.isFinite else { position = nil; return }
                tail.append(value)
            }
            guard finalRow.isAtEnd, matrix.isAtEnd,
                  abs(tail[0]) <= 0.0001, abs(tail[1]) <= 0.0001, abs(tail[2]) <= 0.0001, abs(tail[3] - 1) <= 0.0001 else { position = nil; return }
            position = translation
        }
    }

    static let maximumTransformsBytes: Int64 = 32 * 1024 * 1024
    static let maximumReturnedPositions = 4_096
    static let cancellationCheckFrameInterval = 256

    static func cameraPositions(for renderURL: URL, fileManager: FileManager = .default) -> [SIMD3<Float>] {
        let root = renderURL.deletingLastPathComponent().standardizedFileURL
        let url = root.appendingPathComponent("transforms.json").standardizedFileURL
        guard let rootValues = try? root.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey]),
              rootValues.isDirectory == true,
              rootValues.isSymbolicLink != true,
              url.deletingLastPathComponent() == root,
              let data = try? BoundedFileReader.read(url, maximumBytes: Int(maximumTransformsBytes)),
              !data.isEmpty,
              let dataset = try? JSONDecoder().decode(Dataset.self, from: data),
              !dataset.positions.isEmpty else { return [] }
        return dataset.positions
    }

    static func cameraPositionsAsync(for renderURL: URL) async -> [SIMD3<Float>] {
        let worker = Task.detached(priority: .userInitiated) { cameraPositions(for: renderURL) }
        let positions = await withTaskCancellationHandler { await worker.value } onCancel: { worker.cancel() }
        return Task.isCancelled ? [] : positions
    }
}
