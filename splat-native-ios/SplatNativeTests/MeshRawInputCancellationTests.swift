import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import XCTest

final class MeshRawInputCancellationTests: XCTestCase {
    func testCancelledValidationTaskSkipsImageDecodeScan() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("mesh-raw-cancel-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        try writePNG(to: root.appendingPathComponent("frame.png"))
        XCTAssertEqual(MeshRawInputValidator.usableImageCount(in: root), 1)

        let task = Task { () -> Int in
            do {
                try await Task.sleep(for: .seconds(5))
            } catch {
                // Cancellation is the state under test. Continue into the synchronous validator
                // with the task's cancelled bit still set.
            }
            return MeshRawInputValidator.usableImageCount(in: root)
        }
        task.cancel()

        XCTAssertEqual(await task.value, 0)
    }

    private func writePNG(to url: URL) throws {
        let width = 64
        let height = 64
        var pixels = Data(repeating: 0xff, count: width * height * 4)
        let image: CGImage = try pixels.withUnsafeMutableBytes { raw in
            guard let base = raw.baseAddress,
                  let context = CGContext(
                    data: base,
                    width: width,
                    height: height,
                    bitsPerComponent: 8,
                    bytesPerRow: width * 4,
                    space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                  ),
                  let image = context.makeImage() else {
                throw NSError(domain: "MeshRawInputCancellationTests", code: 1)
            }
            return image
        }
        guard let destination = CGImageDestinationCreateWithURL(
            url as CFURL,
            UTType.png.identifier as CFString,
            1,
            nil
        ) else {
            throw NSError(domain: "MeshRawInputCancellationTests", code: 2)
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw NSError(domain: "MeshRawInputCancellationTests", code: 3)
        }
    }
}
