import Combine
import Foundation
import SceneKit

/// Unit-test-only shell for compiling MeshDetailSimplifier.swift without pulling the full capture/UI
/// model (and its camera/runtime dependencies) into the safety-test target. The safety tests exercise
/// MeshDetailSimplifierEngine directly; these members exist only because the production file also
/// contains the SwiftUI sheet that wires a successful result back into MeshScanModel.
@MainActor
final class MeshScanModel: ObservableObject {
    @Published var rawOBJURL: URL?
    @Published var resultURL: URL?
    @Published var previewScene: SCNScene?
    @Published var vertexCount: Int = 0
    @Published var faceCount: Int = 0
    @Published var statusMessage: String = ""

    func persistExporterMeshAssetContract() throws {}
}
