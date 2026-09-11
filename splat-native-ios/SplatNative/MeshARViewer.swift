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
                    MeshARPlacementView(modelURL: url)
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
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.headline)
                            .frame(width: 42, height: 42)
                            .background(.black.opacity(0.62), in: Circle())
                    }
                    Spacer()
                    Picker("表示", selection: $displayMode) {
                        ForEach(DisplayMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
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

    func makeCoordinator() -> Coordinator {
        Coordinator(modelURL: modelURL)
    }

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
        return view
    }

    func updateUIView(_ uiView: ARSCNView, context: Context) {}

    static func dismantleUIView(_ uiView: ARSCNView, coordinator: Coordinator) {
        uiView.session.pause()
    }

    @MainActor
    final class Coordinator: NSObject {
        private let modelURL: URL
        private weak var view: ARSCNView?
        private var placedNode: SCNNode?

        init(modelURL: URL) {
            self.modelURL = modelURL
        }

        func attach(to view: ARSCNView) {
            self.view = view
            let recognizer = UITapGestureRecognizer(target: self, action: #selector(placeFromTap(_:)))
            view.addGestureRecognizer(recognizer)
        }

        @objc private func placeFromTap(_ recognizer: UITapGestureRecognizer) {
            guard let view else { return }
            let point = recognizer.location(in: view)

            // Prefer ARKit's measured plane geometry before progressively falling back to
            // inferred planes. This avoids snapping a scan to a transient estimated surface
            // when a stable detected horizontal plane is already available.
            let result = raycast(
                view: view,
                point: point,
                allowing: .existingPlaneGeometry,
                alignment: .horizontal
            ) ?? raycast(
                view: view,
                point: point,
                allowing: .existingPlaneInfinite,
                alignment: .horizontal
            ) ?? raycast(
                view: view,
                point: point,
                allowing: .estimatedPlane,
                alignment: .horizontal
            ) ?? raycast(
                view: view,
                point: point,
                allowing: .estimatedPlane,
                alignment: .any
            )

            guard let result else { return }
            place(at: result.worldTransform)
        }

        private func raycast(
            view: ARSCNView,
            point: CGPoint,
            allowing target: ARRaycastQuery.Target,
            alignment: ARRaycastQuery.TargetAlignment
        ) -> ARRaycastResult? {
            guard let query = view.raycastQuery(from: point, allowing: target, alignment: alignment) else {
                return nil
            }
            return view.session.raycast(query).first
        }

        private func place(at transform: simd_float4x4) {
            guard let view else { return }

            // Repositioning an already loaded scan must not parse and clone the entire model again.
            // The anchor owns the recentered model subtree, so changing only its transform produces
            // the same placement result while keeping repeated taps responsive on large meshes.
            if let placedNode {
                placedNode.simdTransform = transform
                return
            }

            guard let source = try? SCNScene(url: modelURL, options: nil) else { return }

            let anchor = SCNNode()
            anchor.simdTransform = transform

            let modelRoot = SCNNode()
            for child in source.rootNode.childNodes {
                modelRoot.addChildNode(child.clone())
            }
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
                    let p = SIMD3<Float>(local.x, local.y, local.z)
                    minimum = simd_min(minimum, p)
                    maximum = simd_max(maximum, p)
                    found = true
                }
            }

            guard found else { return }
            let center = (minimum + maximum) / 2
            root.position = SCNVector3(-center.x, -minimum.y, -center.z)
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