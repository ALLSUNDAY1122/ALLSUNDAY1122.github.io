import XCTest

final class MeshExportResourcePressureTests: XCTestCase {
    private let mib: UInt64 = 1_048_576

    func testSeriousAndCriticalThermalPressureReduceMeshExportBudget() {
        let memory = UInt64(4 * 1_024) * mib
        let nominal = MeshExportMemoryPolicy.budgetBytes(
            physicalMemoryBytes: memory,
            thermalState: .nominal,
            isLowPowerModeEnabled: false
        )
        let serious = MeshExportMemoryPolicy.budgetBytes(
            physicalMemoryBytes: memory,
            thermalState: .serious,
            isLowPowerModeEnabled: false
        )
        let critical = MeshExportMemoryPolicy.budgetBytes(
            physicalMemoryBytes: memory,
            thermalState: .critical,
            isLowPowerModeEnabled: false
        )

        XCTAssertEqual(serious, nominal / 4 * 3)
        XCTAssertEqual(critical, nominal / 2)
    }

    func testLowPowerModeReducesMeshExportBudgetWithoutChangingNormalMode() {
        let memory = UInt64(4 * 1_024) * mib
        let normal = MeshExportMemoryPolicy.budgetBytes(
            physicalMemoryBytes: memory,
            thermalState: .nominal,
            isLowPowerModeEnabled: false
        )
        let lowPower = MeshExportMemoryPolicy.budgetBytes(
            physicalMemoryBytes: memory,
            thermalState: .nominal,
            isLowPowerModeEnabled: true
        )

        XCTAssertEqual(lowPower, normal / 4 * 3)
    }

    func testBorderlineConversionIsAllowedNormallyButRejectedUnderCriticalThermalPressure() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("mesh-resource-pressure-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let source = root.appendingPathComponent("borderline.obj")
        XCTAssertTrue(FileManager.default.createFile(atPath: source.path, contents: Data("v 0 0 0\n".utf8)))
        let handle = try FileHandle(forWritingTo: source)
        try handle.truncate(atOffset: 48 * mib)
        try handle.close()

        let memory = UInt64(4 * 1_024) * mib
        XCTAssertNoThrow(try MeshExportMemoryPolicy.preflight(
            sourceURL: source,
            format: .glb,
            physicalMemoryBytes: memory,
            thermalState: .nominal,
            isLowPowerModeEnabled: false
        ))
        XCTAssertThrowsError(try MeshExportMemoryPolicy.preflight(
            sourceURL: source,
            format: .glb,
            physicalMemoryBytes: memory,
            thermalState: .critical,
            isLowPowerModeEnabled: false
        )) { error in
            guard case MeshExportMemoryPolicy.PolicyError.conversionTooLarge = error else {
                return XCTFail("Expected conversionTooLarge, got \(error)")
            }
        }
    }
}
