@preconcurrency import ARKit
import SceneKit
import SwiftUI

@MainActor
struct MeshARViewerSheet: View {
    enum DisplayMode: String, CaseIterable, Identifiable {
        case ar = "AR"
        case object = "オブジェクト"

        var id: String { rawValue }
    }

    @EnvironmentObject var model: MeshScanModel
    @Environment(\.dismiss) private var dismiss
    @State private var displayMode: DisplayMode = .ar

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let url = model.resultURL {
                switch displayMode {
                case .ar:
                    MeshARPlacementView(modelURL: url, preparedScene: model.previewScene)
                        .ignoresSafeArea()
                case .object:
                    if let scene = model.previewScene {
                        SceneView(
                            scene: scene,
                            options: [.allowsCameraControl, .autoenablesDefaultLighting]
                        )
                        .ignoresSafeArea()
                    }
                }
            }

            VStack(spacing: 0) {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.headline)
                            .frame(width: 42, height: 42)
                            .background(.black.opacity(0.62), in: Circle())
                    }
                    Spacer()
                    Picker("表示", selection: $displayMode) {
                        ForEach(DisplayMode.allCases) { mode in Text(mode.rawValue).tag(mode) }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 190)
                    Spacer()
                    Color.clear.frame(width: 42, height: 42)
                }
                .padding(.horizontal, 14)
                .padding(.top, 10)

                Spacer()

                if displayMode == .ar {
                    Text("水平面をタップすると、実寸Meshをその位置へ置き直します")
                        .font(.caption)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(.black.opacity(0.68), in: Capsule())
                        .padding(.bottom, 18)
                }
            }
            .foregroundStyle(.white)
        }
    }
}

@MainActor
struct MeshARPlacementView: UIViewRepresentable {
    let modelURL: URL
    let preparedScene: SCNScene?

    func makeCoordinator() -> Coordinator { Coordinator(modelURL: modelURL, preparedScene: preparedScene) }

    func makeUIView(context: Context) -> ARSCNView {
        let view = ARSCNView(frame: .zero)
        view.automaticallyUpdatesLighting = true
        view.autoenablesDefaultLighting = true
        view.scene = SCNScene()
        context.coordinator.attach(to: view)

        let configuration = ARWorldTrackingConfiguration()
        configuration.worldAlignment = .gravity
        configuration.planeDetection = [.horizontal]
        configuration.environmentTexturing = .automatic
        view.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])

        let coaching = ARCoachingOverlayView()
        coaching.session = view.session
        coaching.goal = .horizontalPlane
        coaching.activatesAutomatically = true
        coaching.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(coaching)
        NSLayoutConstraint.activate([
            coaching.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            coaching.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            coaching.topAnchor.constraint(equalTo: view.topAnchor),
            coaching.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        return view
    }

    func updateUIView(_ uiView: ARSCNView, context: Context) {}

    static func dismantleUIView(_ uiView: ARSCNView, coordinator: Coordinator) { uiView.session.pause() }

    @MainActor
    final class Coordinator: NSObject {
        private let modelURL: URL
        private let preparedScene: SCNScene?
        private weak var view: ARSCNView?
        private var placedNode: SCNNode?

        init(modelURL: URL, preparedScene: SCNScene?) {
            self.modelURL = modelURL
            self.preparedScene = preparedScene
        }

        func attach(to view: ARSCNView) {
            self.view = view
            let recognizer = UITapGestureRecognizer(target: self, action: #selector(placeFromTap(_:)))
            view.addGestureRecognizer(recognizer)
        }

        @objc private func placeFromTap(_ recognizer: UITapGestureRecognizer) {
            guard let view else { return }
            let point = recognizer.location(in: view)
            let result = raycast(view: view, point: point, allowing: .existingPlaneGeometry, alignment: .horizontal)
                ?? raycast(view: view, point: point, allowing: .existingPlaneInfinite, alignment: .horizontal)
                ?? raycast(view: view, point: point, allowing: .estimatedPlane, alignment: .horizontal)
            guard let result else { return }
            place(at: Self.translationOnlyPlacement(from: result.worldTransform))
        }

        private func raycast(view: ARSCNView, point: CGPoint, allowing target: ARRaycastQuery.Target, alignment: ARRaycastQuery.TargetAlignment) -> ARRaycastResult? {
            guard let query = view.raycastQuery(from: point, allowing: target, alignment: alignment) else { return nil }
            return view.session.raycast(query).first
        }

        private func place(at transform: simd_float4x4) {
            guard let view else { return }
            if let placedNode {
                placedNode.simdTransform = transform
                return
            }

            let source: SCNScene
            if let preparedScene, MeshRawSceneValidator.containsGeometry(preparedScene) {
                source = preparedScene
            } else if let loaded = try? SCNScene(url: modelURL, options: nil), MeshRawSceneValidator.containsGeometry(loaded) {
                source = loaded
            } else {
                return
            }

            let anchor = SCNNode()
            anchor.simdTransform = transform
            let modelRoot = SCNNode()
            modelRoot.addChildNode(source.rootNode.clone())
            recenterForPlacement(modelRoot)
            anchor.addChildNode(modelRoot)
            view.scene.rootNode.addChildNode(anchor)
            placedNode = anchor
        }

        private func recenterForPlacement(_ root: SCNNode) {
            var minimum = SIMD3<Float>(repeating: .greatestFiniteMagnitude)
            var maximum = SIMD3<Float>(repeating: -.greatestFiniteMagnitude)
            var found = false

            root.enumerateChildNodes { node, _ in
                guard let geometry = node.geometry else { return }
                let bounds = geometry.boundingBox
                let corners = Self.corners(minimum: bounds.min, maximum: bounds.max)
                for corner in corners {
                    let local = node.convertPosition(corner, to: root)
                    let point = SIMD3<Float>(local.x, local.y, local.z)
                    guard point.x.isFinite, point.y.isFinite, point.z.isFinite else { continue }
                    minimum = simd_min(minimum, point)
                    maximum = simd_max(maximum, point)
                    found = true
                }
            }

            guard found else { return }
            // `minimum` and `maximum` can each be finite while their subtraction/addition
            // overflows Float. Never turn a valid saved scene into an Inf/NaN placement transform.
            let extent = maximum - minimum
            guard extent.x.isFinite, extent.y.isFinite, extent.z.isFinite else { return }
            let center = minimum + extent / 2
            guard center.x.isFinite, center.y.isFinite, center.z.isFinite, minimum.y.isFinite else { return }
            root.position = SCNVector3(-center.x, -minimum.y, -center.z)
        }

        nonisolated static func translationOnlyPlacement(from raycastTransform: simd_float4x4) -> simd_float4x4 {
            var transform = matrix_identity_float4x4
            let translation = raycastTransform.columns.3
            if translation.x.isFinite, translation.y.isFinite, translation.z.isFinite {
                transform.columns.3 = SIMD4<Float>(translation.x, translation.y, translation.z, 1)
            }
            return transform
        }

        private static func corners(minimum: SCNVector3, maximum: SCNVector3) -> [SCNVector3] {
            [
                SCNVector3(minimum.x, minimum.y, minimum.z),
                SCNVector3(maximum.x, minimum.y, minimum.z),
                SCNVector3(minimum.x, maximum.y, minimum.z),
                SCNVector3(maximum.x, maximum.y, minimum.z),
                SCNVector3(minimum.x, minimum.y, maximum.z),
                SCNVector3(maximum.x, minimum.y, maximum.z),
                SCNVector3(minimum.x, maximum.y, maximum.z),
                SCNVector3(maximum.x, maximum.y, maximum.z)
            ]
        }
    }
}
