import Foundation
import XCTest

final class Lane2LibraryDescriptorRelativeIOTests: XCTestCase {
    func testRoundTripUsesPinnedManagedTree() throws {
        let root = try makeRoot(prefix: "roundtrip")
        defer { try? FileManager.default.removeItem(at: root) }
        let directory = root.appendingPathComponent("managed", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let file = directory.appendingPathComponent("record.json")
        let io = Lane2LibraryDescriptorRelativeIO(rootURL: root)

        let payload = Data("descriptor-roundtrip".utf8)
        try io.writeRegularFileAtomically(payload, to: file)
        XCTAssertEqual(try io.readRegularFile(at: file), payload)
        try io.removeLeaf(at: file)
        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))
    }

    func testMetadataComesFromPinnedRegularFileDescriptor() throws {
        let root = try makeRoot(prefix: "metadata")
        defer { try? FileManager.default.removeItem(at: root) }
        let directory = root.appendingPathComponent("managed", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let file = directory.appendingPathComponent("record.json")
        let payload = Data("descriptor-metadata".utf8)
        let expectedDate = Date(timeIntervalSince1970: 7_000_000)
        try payload.write(to: file)
        try FileManager.default.setAttributes(
            [.modificationDate: expectedDate],
            ofItemAtPath: file.path
        )

        let io = Lane2LibraryDescriptorRelativeIO(rootURL: root)
        let metadata = try io.regularFileMetadata(at: file)
        XCTAssertEqual(metadata.sizeBytes, payload.count)
        XCTAssertEqual(metadata.modificationTime, expectedDate.timeIntervalSince1970, accuracy: 0.001)
    }

    func testBoundedReadFailsClosedBeforeAppendingPastLimit() throws {
        let root = try makeRoot(prefix: "bounded-read")
        defer { try? FileManager.default.removeItem(at: root) }
        let directory = root.appendingPathComponent("managed", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let file = directory.appendingPathComponent("record.json")
        try Data(repeating: 0x41, count: 65_537).write(to: file)
        let io = Lane2LibraryDescriptorRelativeIO(rootURL: root)

        XCTAssertThrowsError(try io.readRegularFile(at: file, maximumBytes: 65_536)) { error in
            XCTAssertEqual(error as? Lane2LibraryDescriptorRelativeIO.Failure, .fileTooLarge("record.json"))
        }
        XCTAssertEqual(try io.readRegularFile(at: file, maximumBytes: 65_537).count, 65_537)
    }

    func testReadRejectsAncestorSymlinkAtUseTime() throws {
        let root = try makeRoot(prefix: "ancestor-root")
        let external = try makeRoot(prefix: "ancestor-external")
        defer {
            try? FileManager.default.removeItem(at: root)
            try? FileManager.default.removeItem(at: external)
        }
        let externalFile = external.appendingPathComponent("record.json")
        let sentinel = Data("external-must-not-be-read".utf8)
        try sentinel.write(to: externalFile)
        let managed = root.appendingPathComponent("managed", isDirectory: true)
        try FileManager.default.createSymbolicLink(at: managed, withDestinationURL: external)
        let managedFile = managed.appendingPathComponent("record.json")

        let io = Lane2LibraryDescriptorRelativeIO(rootURL: root)
        XCTAssertThrowsError(try io.readRegularFile(at: managedFile))
        XCTAssertThrowsError(try io.regularFileMetadata(at: managedFile))
        XCTAssertEqual(try Data(contentsOf: externalFile), sentinel)
    }

    func testReadRejectsLeafSymlinkAtUseTime() throws {
        let root = try makeRoot(prefix: "leaf-root")
        let external = try makeRoot(prefix: "leaf-external")
        defer {
            try? FileManager.default.removeItem(at: root)
            try? FileManager.default.removeItem(at: external)
        }
        let managed = root.appendingPathComponent("managed", isDirectory: true)
        try FileManager.default.createDirectory(at: managed, withIntermediateDirectories: true)
        let externalFile = external.appendingPathComponent("record.json")
        let sentinel = Data("external-leaf-must-not-be-read".utf8)
        try sentinel.write(to: externalFile)
        let managedFile = managed.appendingPathComponent("record.json")
        try FileManager.default.createSymbolicLink(at: managedFile, withDestinationURL: externalFile)

        let io = Lane2LibraryDescriptorRelativeIO(rootURL: root)
        XCTAssertThrowsError(try io.readRegularFile(at: managedFile))
        XCTAssertThrowsError(try io.regularFileMetadata(at: managedFile))
        XCTAssertEqual(try Data(contentsOf: externalFile), sentinel)
    }

    func testAtomicWriteReplacesSymlinkEntryWithoutMutatingExternalTarget() throws {
        let root = try makeRoot(prefix: "write-root")
        let external = try makeRoot(prefix: "write-external")
        defer {
            try? FileManager.default.removeItem(at: root)
            try? FileManager.default.removeItem(at: external)
        }
        let managed = root.appendingPathComponent("managed", isDirectory: true)
        try FileManager.default.createDirectory(at: managed, withIntermediateDirectories: true)
        let externalFile = external.appendingPathComponent("record.json")
        let sentinel = Data("external-write-target-must-survive".utf8)
        try sentinel.write(to: externalFile)
        let managedFile = managed.appendingPathComponent("record.json")
        try FileManager.default.createSymbolicLink(at: managedFile, withDestinationURL: externalFile)

        let io = Lane2LibraryDescriptorRelativeIO(rootURL: root)
        let replacement = Data("managed-replacement".utf8)
        try io.writeRegularFileAtomically(replacement, to: managedFile)

        XCTAssertEqual(try Data(contentsOf: externalFile), sentinel)
        XCTAssertEqual(try io.readRegularFile(at: managedFile), replacement)
        let attributes = try FileManager.default.attributesOfItem(atPath: managedFile.path)
        XCTAssertEqual(attributes[.type] as? FileAttributeType, .typeRegular)
    }

    func testRemoveUnlinksSymlinkEntryWithoutMutatingExternalTarget() throws {
        let root = try makeRoot(prefix: "remove-root")
        let external = try makeRoot(prefix: "remove-external")
        defer {
            try? FileManager.default.removeItem(at: root)
            try? FileManager.default.removeItem(at: external)
        }
        let managed = root.appendingPathComponent("managed", isDirectory: true)
        try FileManager.default.createDirectory(at: managed, withIntermediateDirectories: true)
        let externalFile = external.appendingPathComponent("record.json")
        let sentinel = Data("external-remove-target-must-survive".utf8)
        try sentinel.write(to: externalFile)
        let managedFile = managed.appendingPathComponent("record.json")
        try FileManager.default.createSymbolicLink(at: managedFile, withDestinationURL: externalFile)

        let io = Lane2LibraryDescriptorRelativeIO(rootURL: root)
        try io.removeLeaf(at: managedFile)

        XCTAssertFalse(FileManager.default.fileExists(atPath: managedFile.path))
        XCTAssertEqual(try Data(contentsOf: externalFile), sentinel)
    }

    func testRemoveRegularFileRejectsLeafSymlinkWithoutMutatingExternalTarget() throws {
        let root = try makeRoot(prefix: "regular-remove-root")
        let external = try makeRoot(prefix: "regular-remove-external")
        defer {
            try? FileManager.default.removeItem(at: root)
            try? FileManager.default.removeItem(at: external)
        }
        let managed = root.appendingPathComponent("managed", isDirectory: true)
        try FileManager.default.createDirectory(at: managed, withIntermediateDirectories: true)
        let externalFile = external.appendingPathComponent("record.json")
        let sentinel = Data("regular-remove-target-must-survive".utf8)
        try sentinel.write(to: externalFile)
        let managedFile = managed.appendingPathComponent("record.json")
        try FileManager.default.createSymbolicLink(at: managedFile, withDestinationURL: externalFile)

        let io = Lane2LibraryDescriptorRelativeIO(rootURL: root)
        XCTAssertThrowsError(try io.removeRegularFileLeaf(at: managedFile))
        XCTAssertEqual(try Data(contentsOf: externalFile), sentinel)
        let attributes = try FileManager.default.attributesOfItem(atPath: managedFile.path)
        XCTAssertEqual(attributes[.type] as? FileAttributeType, .typeSymbolicLink)
    }

    func testRejectsPathOutsideManagedRoot() throws {
        let root = try makeRoot(prefix: "outside-root")
        let external = try makeRoot(prefix: "outside-external")
        defer {
            try? FileManager.default.removeItem(at: root)
            try? FileManager.default.removeItem(at: external)
        }
        let externalFile = external.appendingPathComponent("record.json")
        try Data("outside".utf8).write(to: externalFile)

        let io = Lane2LibraryDescriptorRelativeIO(rootURL: root)
        XCTAssertThrowsError(try io.readRegularFile(at: externalFile))
        XCTAssertThrowsError(try io.regularFileMetadata(at: externalFile))
        XCTAssertThrowsError(try io.removeRegularFileLeaf(at: externalFile))
    }

    private func makeRoot(prefix: String) throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(
            "L2DescriptorAuthority-\(prefix)-\(UUID().uuidString)",
            isDirectory: true
        )
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }
}
