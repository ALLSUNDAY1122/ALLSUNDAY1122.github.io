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
            try require(result.pageCount == 200)
            try require(result.bookPackageURL.lastPathComponent == "package")
        }

        await run("resume skips completed stages") {
            let root = temp("resume")
            let recorder = Recorder()
            let inputs = request(root: root).inputs
            let artifacts = ProductProcessingStage.allCases.prefix(3).map {
                ProductStageArtifact(stage: $0, outputURL: root.appendingPathComponent($0.rawValue), pageCount: 200)
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

        await run("review items are stable-id deduplicated") {
            let root = temp("review")
            let review = ProductReviewItem(id: "review-1", pageIDs: ["page-7"], reason: "low-confidence", detail: "fixture")
            let bindings = ProductProcessingStage.allCases.map { stage in
                ProductPipelineStageBinding(stage: stage) { _, _, _ in
                    ProductStageArtifact(
                        stage: stage,
                        outputURL: root.appendingPathComponent(stage == .packageWrite ? "package" : stage.rawValue),
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
                    return ProductStageArtifact(stage: .imageCorrection, outputURL: request.workspaceURL.appendingPathComponent("imageCorrection"), pageCount: 200)
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

        await run("checkpoint store roundtrip retains durable input") {
            let root = temp("checkpoint")
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            let inputURL = root.appendingPathComponent("book.mov")
            try Data([0x00]).write(to: inputURL)
            let input = ProductInputAsset(id: "input-1", kind: .video, localURL: inputURL, displayName: "book.mov")
            let url = root.appendingPathComponent("state/checkpoint.json")
            let store = FileProductCheckpointStore(fileURL: url)
            let value = ProductPipelineCheckpoint(
                runID: "r1", bookID: "book-fixture", inputAssetIDs: ["input-1"], inputAssets: [input],
                completedArtifacts: [.init(stage: .frameExtraction, outputURL: root, pageCount: 200)],
                lastProgress: .init(stage: .frameExtraction, fraction: 1, completedUnits: 200, totalUnits: 200)
            )
            try await store.save(value)
            let loaded = try await store.load()
            try require(loaded?.runID == "r1")
            try require(loaded?.completedArtifacts.count == 1)
            try require(loaded?.inputAssets == [input])
            try require(FileManager.default.fileExists(atPath: loaded!.inputAssets!.first!.localURL.path))
            try await store.clear()
            let cleared = try await store.load()
            try require(cleared == nil)
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
            ProductPipelineStageBinding(stage: stage) { _, _, progress in
                await recorder.append(stage)
                await progress(.init(stage: stage, fraction: 0.5, completedUnits: 100, totalUnits: 200))
                return ProductStageArtifact(
                    stage: stage,
                    outputURL: root.appendingPathComponent(stage == .packageWrite ? "package" : stage.rawValue),
                    pageCount: 200
                )
            }
        }
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
