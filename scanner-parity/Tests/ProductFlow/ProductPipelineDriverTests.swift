import Foundation

@main
struct ProductPipelineDriverTests {
    static func main() async {
        var passed = 0
        var failed = 0

        func run(_ name: String, _ body: () async throws -> Void) async {
            do {
                try await body()
                print("PASS \(name)")
                passed += 1
            } catch {
                print("FAIL \(name): \(error)")
                failed += 1
            }
        }

        await run("five stages execute in canonical order") {
            let root = temp("order")
            let recorder = Recorder()
            let driver = BoundProductPipelineDriver(bindings: makeBindings(root: root, recorder: recorder))
            let result = try await driver.run(
                request: request(root: root),
                resume: nil,
                progress: { value in await recorder.record(progress: value) },
                checkpoint: { value in await recorder.record(checkpoint: value) }
            )
            let stages = await recorder.stages
            let checkpoints = await recorder.checkpoints
            try require(stages == ProductProcessingStage.allCases)
            try require(checkpoints.count == 5)
            try require(checkpoints.last?.inputAssets?.map(\.id) == ["input-1"])
            try require(checkpoints.last?.completion == nil)
            try require(result.pageCount == 200)
            try require(result.bookPackageURL.lastPathComponent == "package")
        }

        await run("resume skips completed stages") {
            let root = temp("resume")
            let recorder = Recorder()
            let inputs = request(root: root).inputs
            let artifacts = try ProductProcessingStage.allCases.prefix(3).map { stage in
                ProductStageArtifact(stage: stage, outputURL: try stageOutput(root: root, stage: stage), pageCount: 200)
            }
            let checkpoint = ProductPipelineCheckpoint(
                runID: "run-1",
                bookID: "book-fixture",
                inputAssetIDs: ["input-1"],
                inputAssets: inputs,
                completedArtifacts: artifacts,
                lastProgress: .init(stage: .pageAudit, fraction: 1, completedUnits: 200, totalUnits: 200)
            )
            let driver = BoundProductPipelineDriver(bindings: makeBindings(root: root, recorder: recorder))
            _ = try await driver.run(request: request(root: root), resume: checkpoint, progress: { _ in }, checkpoint: { _ in })
            let stages = await recorder.stages
            try require(stages == [.ocr, .packageWrite])
        }

        await run("mismatched checkpoint fails closed") {
            let root = temp("invalid")
            let checkpoint = ProductPipelineCheckpoint(
                runID: "run-x",
                bookID: "other-book",
                inputAssetIDs: ["input-1"],
                completedArtifacts: [],
                lastProgress: nil
            )
            do {
                _ = try await BoundProductPipelineDriver(bindings: makeBindings(root: root, recorder: Recorder()))
                    .run(request: request(root: root), resume: checkpoint, progress: { _ in }, checkpoint: { _ in })
                throw TestError.expectedFailure
            } catch ProductPipelineDriverError.invalidResumeCheckpoint {}
        }

        await run("missing resume artifact fails closed") {
            let root = temp("missing-artifact")
            let missing = root.appendingPathComponent("does-not-exist")
            let checkpoint = ProductPipelineCheckpoint(
                runID: "run-missing",
                bookID: "book-fixture",
                inputAssetIDs: ["input-1"],
                inputAssets: request(root: root).inputs,
                completedArtifacts: [.init(stage: .frameExtraction, outputURL: missing, pageCount: 200)],
                lastProgress: .init(stage: .frameExtraction, fraction: 1, completedUnits: 200, totalUnits: 200)
            )
            do {
                _ = try await BoundProductPipelineDriver(bindings: makeBindings(root: root, recorder: Recorder()))
                    .run(request: request(root: root), resume: checkpoint, progress: { _ in }, checkpoint: { _ in })
                throw TestError.expectedFailure
            } catch ProductPipelineDriverError.invalidResumeCheckpoint {}
        }

        await run("non-prefix resume artifact order fails closed") {
            let root = temp("order-invalid")
            let ocrURL = try stageOutput(root: root, stage: .ocr)
            let checkpoint = ProductPipelineCheckpoint(
                runID: "run-order",
                bookID: "book-fixture",
                inputAssetIDs: ["input-1"],
                inputAssets: request(root: root).inputs,
                completedArtifacts: [.init(stage: .ocr, outputURL: ocrURL, pageCount: 200)],
                lastProgress: .init(stage: .ocr, fraction: 1, completedUnits: 200, totalUnits: 200)
            )
            do {
                _ = try await BoundProductPipelineDriver(bindings: makeBindings(root: root, recorder: Recorder()))
                    .run(request: request(root: root), resume: checkpoint, progress: { _ in }, checkpoint: { _ in })
                throw TestError.expectedFailure
            } catch ProductPipelineDriverError.invalidResumeCheckpoint {}
        }

        await run("review items are stable-id deduplicated") {
            let root = temp("review")
            let review = ProductReviewItem(id: "review-1", pageIDs: ["page-7"], reason: "low-confidence", detail: "fixture")
            let bindings = ProductProcessingStage.allCases.map { stage in
                ProductPipelineStageBinding(stage: stage) { _, _, _ in
                    ProductStageArtifact(
                        stage: stage,
                        outputURL: try stageOutput(root: root, stage: stage),
                        pageCount: 8,
                        reviewItems: stage == .pageAudit || stage == .ocr ? [review] : []
                    )
                }
            }
            let result = try await BoundProductPipelineDriver(bindings: bindings)
                .run(request: request(root: root), resume: nil, progress: { _ in }, checkpoint: { _ in })
            try require(result.reviewItems == [review])
        }

        await run("200-page progress remains incremental") {
            let root = temp("long")
            let recorder = Recorder()
            var bindings = makeBindings(root: root, recorder: recorder)
            bindings = bindings.map { binding in
                guard binding.stage == .imageCorrection else { return binding }
                return ProductPipelineStageBinding(stage: .imageCorrection) { request, _, progress in
                    for page in 1...200 {
                        await progress(.init(stage: .imageCorrection, fraction: Double(page) / 200, completedUnits: page, totalUnits: 200))
                    }
                    return ProductStageArtifact(
                        stage: .imageCorrection,
                        outputURL: try stageOutput(root: request.workspaceURL, stage: .imageCorrection),
                        pageCount: 200
                    )
                }
            }
            _ = try await BoundProductPipelineDriver(bindings: bindings).run(
                request: request(root: root),
                resume: nil,
                progress: { value in await recorder.record(progress: value) },
                checkpoint: { _ in }
            )
            let units = await recorder.imageCorrectionProgressUnits
            try require(units.contains(1))
            try require(units.contains(200))
            try require(units.count >= 200)
        }

        await run("checkpoint store roundtrip retains durable active input") {
            let root = temp("checkpoint")
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            let inputURL = root.appendingPathComponent("book.mov")
            try Data([0x00]).write(to: inputURL)
            let input = ProductInputAsset(id: "input-1", kind: .video, localURL: inputURL, displayName: "book.mov")
            let stageURL = try stageOutput(root: root, stage: .frameExtraction)
            let url = root.appendingPathComponent("state/checkpoint.json")
            let store = FileProductCheckpointStore(fileURL: url)
            let value = ProductPipelineCheckpoint(
                runID: "r1", bookID: "book-fixture", inputAssetIDs: ["input-1"], inputAssets: [input],
                completedArtifacts: [.init(stage: .frameExtraction, outputURL: stageURL, pageCount: 200)],
                lastProgress: .init(stage: .frameExtraction, fraction: 1, completedUnits: 200, totalUnits: 200)
            )
            try await store.save(value)
            let loaded = try await store.load()
            try require(loaded?.runID == "r1")
            try require(loaded?.completedArtifacts.count == 1)
            try require(loaded?.inputAssets == [input])
            try require(loaded?.completion == nil)
            try require(loaded?.hasCanonicalExistingArtifacts == true)
            try await store.clear()
            try require(try await store.load() == nil)
        }

        await run("schema v3 terminal checkpoint retains only completion snapshot") {
            let root = temp("terminal")
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            let package = root.appendingPathComponent("completed-package", isDirectory: true)
            try FileManager.default.createDirectory(at: package, withIntermediateDirectories: true)
            let review = ProductReviewItem(id: "r-1", pageIDs: ["p-1"], reason: "ocr_low_confidence", detail: "fixture")
            let checkpoint = ProductPipelineCheckpoint(
                schemaVersion: 3,
                runID: "terminal-run",
                bookID: "book-terminal",
                inputAssetIDs: ["old-input"],
                inputAssets: nil,
                completedArtifacts: [],
                lastProgress: .init(stage: .packageWrite, fraction: 1, completedUnits: 200, totalUnits: 200),
                completion: .init(bookPackageURL: package, reviewItems: [review], pageCount: 200)
            )
            let store = FileProductCheckpointStore(fileURL: root.appendingPathComponent("checkpoint.json"))
            try await store.save(checkpoint)
            let loaded = try await store.load()
            try require(loaded?.schemaVersion == 3)
            try require(loaded?.inputAssets == nil)
            try require(loaded?.completedArtifacts.isEmpty == true)
            try require(loaded?.terminalCompletion?.bookPackageURL == package)
            try require(loaded?.terminalCompletion?.reviewItems == [review])
            try require(loaded?.hasCanonicalExistingArtifacts == false)
        }

        await run("legacy full checkpoint derives terminal completion") {
            let root = temp("legacy-completed")
            let review = ProductReviewItem(id: "legacy-r", pageIDs: ["p-9"], reason: "audit", detail: "fixture")
            let artifacts = try ProductProcessingStage.allCases.map { stage -> ProductStageArtifact in
                ProductStageArtifact(
                    stage: stage,
                    outputURL: try stageOutput(root: root, stage: stage),
                    pageCount: 9,
                    reviewItems: stage == .ocr ? [review] : []
                )
            }
            let checkpoint = ProductPipelineCheckpoint(
                schemaVersion: 2,
                runID: "legacy-complete",
                bookID: "book-legacy",
                inputAssetIDs: ["input-1"],
                inputAssets: request(root: root).inputs,
                completedArtifacts: artifacts,
                lastProgress: .init(stage: .packageWrite, fraction: 1, completedUnits: 9, totalUnits: 9)
            )
            try require(checkpoint.terminalCompletion?.pageCount == 9)
            try require(checkpoint.terminalCompletion?.reviewItems == [review])
            try require(checkpoint.isCompletedPackageCheckpoint)
        }

        await run("terminal checkpoint with missing package fails closed") {
            let root = temp("terminal-missing")
            let missing = root.appendingPathComponent("missing-package")
            let checkpoint = ProductPipelineCheckpoint(
                schemaVersion: 3,
                runID: "terminal-missing",
                bookID: "book-terminal-missing",
                inputAssetIDs: [],
                completedArtifacts: [],
                lastProgress: .init(stage: .packageWrite, fraction: 1),
                completion: .init(bookPackageURL: missing, reviewItems: [], pageCount: 1)
            )
            try require(checkpoint.terminalCompletion == nil)
            try require(!checkpoint.isCompletedPackageCheckpoint)
        }

        await run("schema v1 checkpoint remains decodable") {
            let root = temp("v1")
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            let url = root.appendingPathComponent("checkpoint.json")
            let json = """
            {
              "schemaVersion": 1,
              "runID": "legacy-run",
              "bookID": "book-fixture",
              "inputAssetIDs": ["input-1"],
              "completedArtifacts": [],
              "lastProgress": null,
              "updatedAt": "2026-08-23T08:00:00Z"
            }
            """
            try Data(json.utf8).write(to: url)
            let loaded = try await FileProductCheckpointStore(fileURL: url).load()
            try require(loaded?.schemaVersion == 1)
            try require(loaded?.inputAssets == nil)
            try require(loaded?.completion == nil)
        }

        await run("missing binding is explicit failure") {
            let root = temp("missing")
            do {
                _ = try await BoundProductPipelineDriver(bindings: []).run(
                    request: request(root: root), resume: nil, progress: { _ in }, checkpoint: { _ in }
                )
                throw TestError.expectedFailure
            } catch ProductPipelineDriverError.missingStageBinding(let stage) {
                try require(stage == .frameExtraction)
            }
        }

        print("RESULT passed=\(passed) failed=\(failed)")
        if failed > 0 { exit(1) }
    }

    actor Recorder {
        private(set) var stages: [ProductProcessingStage] = []
        private(set) var checkpoints: [ProductPipelineCheckpoint] = []
        private(set) var imageCorrectionProgressUnits: [Int] = []

        func append(_ stage: ProductProcessingStage) { stages.append(stage) }
        func record(checkpoint: ProductPipelineCheckpoint) { checkpoints.append(checkpoint) }
        func record(progress: ProductProgress) {
            if progress.stage == .imageCorrection && progress.completedUnits > 0 {
                imageCorrectionProgressUnits.append(progress.completedUnits)
            }
        }
    }

    static func makeBindings(root: URL, recorder: Recorder) -> [ProductPipelineStageBinding] {
        ProductProcessingStage.allCases.map { stage in
            ProductPipelineStageBinding(stage: stage) { request, _, progress in
                await recorder.append(stage)
                await progress(.init(stage: stage, fraction: 0.5, completedUnits: 100, totalUnits: 200))
                return ProductStageArtifact(
                    stage: stage,
                    outputURL: try stageOutput(root: request.workspaceURL, stage: stage),
                    pageCount: 200
                )
            }
        }
    }

    static func stageOutput(root: URL, stage: ProductProcessingStage) throws -> URL {
        let name = stage == .packageWrite ? "package" : stage.rawValue
        let url = root.appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static func request(root: URL) -> ProductPipelineRequest {
        ProductPipelineRequest(
            bookID: "book-fixture",
            inputs: [ProductInputAsset(id: "input-1", kind: .video, localURL: root.appendingPathComponent("book.mov"), displayName: "book.mov")],
            workspaceURL: root
        )
    }

    static func temp(_ suffix: String) -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("scanner-parity-product-\(suffix)-\(UUID().uuidString)")
    }

    static func require(_ condition: @autoclosure () -> Bool) throws {
        if !condition() { throw TestError.assertionFailed }
    }

    enum TestError: Error { case assertionFailed, expectedFailure }
}
