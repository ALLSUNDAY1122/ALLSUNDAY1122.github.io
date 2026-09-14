import Foundation
import SceneKit
import XCTest

final class MeshRawSceneValidatorPolygonTests: XCTestCase {
    func testAcceptsValidPolygonSurface() {
        let scene = sceneWithPolygon(tokens: [3, 0, 1, 2])
        XCTAssertTrue(MeshRawSceneValidator.containsGeometry(scene))
    }

    func testRejectsPolygonWithOutOfRangeIndex() {
        let scene = sceneWithPolygon(tokens: [3, 0, 1, 7])
        XCTAssertFalse(MeshRawSceneValidator.containsGeometry(scene))
    }

    func testRejectsFullyDegeneratePolygon() {
        let scene = sceneWithPolygon(tokens: [3, 0, 0, 0])
        XCTAssertFalse(MeshRawSceneValidator.containsGeometry(scene))
    }

    func testRejectsTruncatedPolygonRecord() {
        let scene = sceneWithPolygon(tokens: [4, 0, 1, 2])
        XCTAssertFalse(MeshRawSceneValidator.containsGeometry(scene))
    }

    private func sceneWithPolygon(tokens: [UInt16]) -> SCNScene {
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
            primitiveCount: 1,
            bytesPerIndex: MemoryLayout<UInt16>.size
        )
        scene.rootNode.addChildNode(
            SCNNode(geometry: SCNGeometry(sources: [vertices], elements: [polygon]))
        )
        return scene
    }
}
