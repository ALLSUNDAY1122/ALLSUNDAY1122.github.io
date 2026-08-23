#if canImport(SwiftUI) && canImport(PhotosUI) && canImport(UniformTypeIdentifiers)
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers
import ProductFlow

public struct ScannerParityRootView: View {
    @StateObject private var store = ProductFlowStore()
    @StateObject private var importer = MediaImportCoordinator()
    @State private var showFileImporter = false

    public init() {}

    public var body: some View {
        NavigationStack {
            Group {
                switch store.state.step {
                case .selectingInput, .ready: inputView
                case .processing: processingView
                case .review: reviewView
                case .exporting: exportView
                case .completed: completedView
                case .failed: failureView
                }
            }
            .navigationTitle("Book Scanner")
        }
        .task {
            store.send(.cameraPermissionChanged(importer.currentCameraPermission()))
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.image, .movie],
            allowsMultipleSelection: true
        ) { result in
            do {
                store.send(.replaceInput(try importer.importFiles(try result.get())))
            } catch {
                store.send(.fail(.init(code: .importFailed, message: error.localizedDescription, recoveryStep: .selectingInput)))
            }
        }
    }

    private var inputView: some View {
        List {
            Section("Input") {
                PhotosPicker(
                    selection: $importer.photoPickerItems,
                    maxSelectionCount: 1000,
                    matching: .any(of: [.images, .videos])
                ) {
                    Label("Choose photos or video", systemImage: "photo.on.rectangle.angled")
                }
                .onChange(of: importer.photoPickerItems.count) { _, count in
                    guard count > 0 else { return }
                    Task {
                        let assets = await importer.importPhotoPickerSelection()
                        if !assets.isEmpty { store.send(.replaceInput(assets)) }
                    }
                }

                Button { showFileImporter = true } label: {
                    Label("Choose from Files", systemImage: "folder")
                }

                Button {
                    Task {
                        store.send(.cameraPermissionChanged(await importer.requestCameraPermission()))
                    }
                } label: {
                    Label("Check camera permission", systemImage: "camera")
                }
            }

            if !store.state.inputAssets.isEmpty {
                Section("Selected \(store.state.inputAssets.count)") {
                    ForEach(store.state.inputAssets) { asset in
                        Label(asset.displayName, systemImage: asset.kind == .video ? "video" : "photo")
                    }
                    Button("Start processing") { store.send(.startProcessing) }
                        .buttonStyle(.borderedProminent)
                    Button("Clear selection", role: .destructive) { store.send(.replaceInput([])) }
                }
            }

            if importer.isImporting {
                Section { ProgressView("Importing…") }
            }

            if let error = importer.lastError {
                Section("Import warning") { Text(error) }
            }

            if store.state.cameraPermission == .denied || store.state.cameraPermission == .restricted {
                Section("Camera unavailable") {
                    Text("Camera access is unavailable. Photos and Files import still work, so scanning is not blocked.")
                }
            }
        }
    }

    private var processingView: some View {
        VStack(spacing: 20) {
            ProgressView(value: store.state.progress?.fraction ?? 0)
            Text(store.state.progress?.stage.rawValue ?? "processing")
            Button("Cancel", role: .destructive) { store.send(.cancel) }
        }
        .padding()
    }

    private var reviewView: some View {
        VStack(spacing: 16) {
            Text("\(store.state.reviewRequiredCount) page(s) require review")
            Text("ReviewCore will be connected through an adapter without changing the shared contract.")
                .font(.footnote)
            Button("Continue after review") { store.send(.reviewResolved(remaining: 0)) }
        }
        .padding()
    }

    private var exportView: some View {
        VStack(spacing: 16) {
            Text("BookPackage ready")
            if let url = store.state.bookPackageURL {
                Text(url.lastPathComponent).font(.caption)
            }
            Text("Files/share export is connected in a later lane milestone.")
                .font(.footnote)
        }
        .padding()
    }

    private var completedView: some View {
        VStack(spacing: 16) {
            Text("Completed")
            Button("Scan another book") { store.send(.reset) }
        }
        .padding()
    }

    private var failureView: some View {
        VStack(spacing: 16) {
            Text("Processing stopped").font(.headline)
            Text(store.state.failure?.message ?? "Unknown error")
            Button("Retry") { store.send(.retry) }
                .buttonStyle(.borderedProminent)
            Button("Choose different input") { store.send(.replaceInput([])) }
        }
        .padding()
    }
}
#endif
