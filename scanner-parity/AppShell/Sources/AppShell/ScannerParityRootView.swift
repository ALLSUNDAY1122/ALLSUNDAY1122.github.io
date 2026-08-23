#if canImport(SwiftUI) && canImport(PhotosUI) && canImport(UniformTypeIdentifiers)
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers
import ProductFlow

public struct ScannerParityRootView: View {
    @StateObject private var store: ProductFlowStore
    @StateObject private var importer = MediaImportCoordinator()
    @Environment(\.scenePhase) private var scenePhase
    @State private var showFileImporter = false
    @State private var showPackageExporter = false
    #if canImport(UIKit)
    @State private var backgroundTaskController: ProductBackgroundTaskController?
    #endif

    public init(
        driver: any ProductPipelineDriving = BoundProductPipelineDriver(bindings: []),
        reviewWorkflowFactory: @escaping @Sendable ([ProductReviewItem]) -> any ProductReviewWorkflow = { InMemoryProductReviewWorkflow(items: $0) }
    ) {
        _store = StateObject(wrappedValue: ProductFlowStore(
            driver: driver,
            reviewWorkflowFactory: reviewWorkflowFactory
        ))
    }

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
            store.restoreCheckpoint()
        }
        .onChange(of: scenePhase) { _, phase in
            handleScenePhase(phase)
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.image, .movie],
            allowsMultipleSelection: true
        ) { result in
            do {
                replaceImportedInput(try importer.importFiles(try result.get()))
            } catch {
                store.send(.fail(.init(code: .importFailed, message: error.localizedDescription, recoveryStep: .selectingInput)))
            }
        }
        #if canImport(UIKit)
        .sheet(isPresented: $showPackageExporter) {
            if let url = store.state.bookPackageURL {
                BookPackageDocumentExporter(packageURL: url) { succeeded in
                    showPackageExporter = false
                    if succeeded { store.markExportFinished() }
                }
            }
        }
        #endif
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
                        if !assets.isEmpty { replaceImportedInput(assets) }
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
                    Button("Start processing") { store.startProcessing() }
                        .buttonStyle(.borderedProminent)
                    Button("Clear selection", role: .destructive) { clearImportedInput() }
                }
            }

            if store.resumeAvailable && !store.state.inputAssets.isEmpty {
                Section("Saved progress") {
                    Button("Resume processing") { store.resumeProcessing() }
                        .buttonStyle(.borderedProminent)
                    Text("Completed stages are reused; the current unfinished stage is rerun safely.")
                        .font(.footnote)
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
                .font(.headline)
            if let progress = store.state.progress {
                if let total = progress.totalUnits, total > 0 {
                    Text("\(progress.completedUnits) / \(total)")
                        .font(.caption.monospacedDigit())
                } else if progress.completedUnits > 0 {
                    Text("Processed \(progress.completedUnits)")
                        .font(.caption.monospacedDigit())
                }
            }
            Text("Long books are processed stage-by-stage and checkpointed. Leaving the app may pause work; saved progress can be resumed.")
                .font(.footnote)
                .multilineTextAlignment(.center)
            Button("Cancel", role: .destructive) { store.cancelProcessing() }
        }
        .padding()
    }

    private var reviewView: some View {
        List {
            Section("Needs review") {
                Text("\(store.reviewItems.count) page issue(s) remain. Recovery actions are routed through a replaceable ReviewCore adapter.")
                    .font(.footnote)
            }
            ForEach(store.reviewItems) { item in
                Section(item.pageIDs.isEmpty ? "Book" : item.pageIDs.joined(separator: ", ")) {
                    Text(item.reason).font(.headline)
                    Text(item.detail).font(.footnote)
                    HStack {
                        Button("Accept") { store.resolveReviewItem(item.id, decision: .accept) }
                        Button("Exclude", role: .destructive) { store.resolveReviewItem(item.id, decision: .exclude) }
                    }
                }
            }
        }
    }

    private var exportView: some View {
        VStack(spacing: 16) {
            Text("BookPackage ready").font(.headline)
            if let url = store.state.bookPackageURL {
                Text(url.lastPathComponent).font(.caption)
                ShareLink(item: url) {
                    Label("Share BookPackage", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.borderedProminent)
                #if canImport(UIKit)
                Button {
                    showPackageExporter = true
                } label: {
                    Label("Save to Files", systemImage: "folder.badge.plus")
                }
                #endif
                Button("Finish") { store.markExportFinished() }
            }
        }
        .padding()
    }

    private var completedView: some View {
        VStack(spacing: 16) {
            Text("Completed").font(.headline)
            if let url = store.state.bookPackageURL {
                ShareLink(item: url) { Label("Share again", systemImage: "square.and.arrow.up") }
            }
            Button("Scan another book") {
                importer.discardImportedAssets(store.state.inputAssets)
                store.replaceInput([])
                store.send(.reset)
            }
        }
        .padding()
    }

    private var failureView: some View {
        VStack(spacing: 16) {
            Text("Processing stopped").font(.headline)
            Text(store.state.failure?.message ?? "Unknown error")
            if store.resumeAvailable && !store.state.inputAssets.isEmpty {
                Button("Resume saved progress") { store.resumeProcessing() }
                    .buttonStyle(.borderedProminent)
            } else {
                Button("Retry") { store.send(.retry) }
                    .buttonStyle(.borderedProminent)
            }
            Button("Choose different input") { clearImportedInput() }
        }
        .padding()
    }

    private func replaceImportedInput(_ assets: [ProductInputAsset]) {
        importer.discardImportedAssets(store.state.inputAssets)
        store.replaceInput(assets)
    }

    private func clearImportedInput() {
        importer.discardImportedAssets(store.state.inputAssets)
        store.replaceInput([])
    }

    private func handleScenePhase(_ phase: ScenePhase) {
        #if canImport(UIKit)
        if phase == .background && store.isRunning {
            if backgroundTaskController == nil { backgroundTaskController = ProductBackgroundTaskController() }
            backgroundTaskController?.begin { store.cancelProcessing() }
        } else if phase == .active {
            backgroundTaskController?.end()
        }
        #endif
    }
}
#endif
