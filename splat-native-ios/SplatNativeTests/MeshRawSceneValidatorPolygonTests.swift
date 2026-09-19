import Foundation
import SceneKit
import XCTest

final class MeshRawSceneValidatorPolygonTests: XCTestCase {
    func testAcceptsValidPolygonSurface() {
        let scene = sceneWithPolygon(tokens: [3, 0, 1, 2])
        XCTAssertTrue(MeshRawSceneValidator.containsGeometry(scene))
    }

    func testAcceptsSceneKitTwoSequenceMultiPolygonLayout() {
        let scene = sceneWithPolygon(
            tokens: [3, 3, 0, 1, 2, 0, 2, 1],
            primitiveCount: 2
        )
        XCTAssertTrue(MeshRawSceneValidator.containsGeometry(scene))
    }

    func testRejectsPolygonWithOutOfRangeIndex() {
        let scene = sceneWithPolygon(tokens: [3, 0, 1, 7])
        XCTAssertFalse(MeshRawSceneValidator.containsGeometry(scene))
    }

    func testRejectsOutOfRangeIndexInLaterPolygon() {
        let scene = sceneWithPolygon(
            tokens: [3, 3, 0, 1, 2, 0, 2, 7],
            primitiveCount: 2
        )
        XCTAssertFalse(MeshRawSceneValidator.containsGeometry(scene))
    }

    func testRejectsFullyDegeneratePolygon() {
        let scene = sceneWithPolygon(tokens: [3, 0, 0, 0])
        XCTAssertFalse(MeshRawSceneValidator.containsGeometry(scene))
    }

    private func sceneWithPolygon(tokens: [UInt16], primitiveCount: Int = 1) -> SCNScene {
        let scene = SCNScene()
        let vertices = SCNGeometrySource(vertices: [
            SCNVector3(0, 0, 0),
            SCNVector3(1, 0, 0),
            SCNVector3(0, 1, 0),
        ])
        let littleEndianTokens = tokens.map { $0.littleEndian }
        let data = littleEndianTokens.withUnsafeBytes { Data($0) }
        let polygon = SCNGeometryElement(
            data: data,
            primitiveType: .polygon,
            primitiveCount: primitiveCount,
            bytesPerIndex: MemoryLayout<UInt16>.size
        )
        scene.rootNode.addChildNode(
            SCNNode(geometry: SCNGeometry(sources: [vertices], elements: [polygon]))
        )
        return scene
    }
}
