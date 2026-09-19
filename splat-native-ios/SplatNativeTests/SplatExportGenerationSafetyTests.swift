import Foundation
import XCTest

final class SplatExportGenerationSafetyTests: XCTestCase {
    func testPointCountRejectsSymlinkAndHardLinkSources() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("SplatExportGenerationSafety-\(UUID().uuidString)", isDirectory: true)
        defer { try? fm.removeItem(at: root) }
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        let real = root.appendingPathComponent("real.splat")
        try Data(repeating: 0, count: 64).write(to: real)
        let alias = root.appendingPathComponent("alias.splat")
        try fm.createSymbolicLink(at: alias, withDestinationURL: real)
        XCTAssertThrowsError(try SplatExportService.sourcePointCount(alias))
        let hard = root.appendingPathComponent("hard.splat")
        try fm.linkItem(at: real, to: hard)
        XCTAssertThrowsError(try SplatExportService.sourcePointCount(real))
        XCTAssertThrowsError(try SplatExportService.sourcePointCount(hard))
    }

    func testStreamingHashRejectsSymlinkSource() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("SplatExportHashSafety-\(UUID().uuidString)", isDirectory: true)
        defer { try? fm.removeItem(at: root) }
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        let real = root.appendingPathComponent("real.spz")
        try Data(repeating: 7, count: 4096).write(to: real)
        let alias = root.appendingPathComponent("alias.spz")
        try fm.createSymbolicLink(at: alias, withDestinationURL: real)
        XCTAssertThrowsError(try SplatExportService.sha256Hex(fileURL: alias))
    }
}
