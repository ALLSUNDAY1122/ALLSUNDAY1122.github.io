import Foundation
import ProductFlow

/// Canonical composition point used by the real iOS target. Each closure may
/// internally use the already-integrated FrameExtraction/ImageCorrection/
/// PageAudit/OCRExport/PipelineOCR native types. Only stage artifacts cross
/// into AppShell, so no shared-domain model is duplicated here.
public struct ScannerPipelineBindings: Sendable {
    public let frameExtraction: ProductPipelineStageBinding
    public let imageCorrection: ProductPipelineStageBinding
    public let pageAudit: ProductPipelineStageBinding
    public let ocr: ProductPipelineStageBinding
    public let packageWrite: ProductPipelineStageBinding

    public init(
        frameExtraction: @escaping ProductStageExecutor,
        imageCorrection: @escaping ProductStageExecutor,
        pageAudit: @escaping ProductStageExecutor,
        ocr: @escaping ProductStageExecutor,
        packageWrite: @escaping ProductStageExecutor
    ) {
        self.frameExtraction = .init(stage: .frameExtraction, execute: frameExtraction)
        self.imageCorrection = .init(stage: .imageCorrection, execute: imageCorrection)
        self.pageAudit = .init(stage: .pageAudit, execute: pageAudit)
        self.ocr = .init(stage: .ocr, execute: ocr)
        self.packageWrite = .init(stage: .packageWrite, execute: packageWrite)
    }

    public func makeDriver() -> BoundProductPipelineDriver {
        BoundProductPipelineDriver(bindings: [
            frameExtraction,
            imageCorrection,
            pageAudit,
            ocr,
            packageWrite,
        ])
    }
}

public typealias ProductStageExecutor = @Sendable (
    ProductPipelineRequest,
    [ProductStageArtifact],
    @escaping ProductStageProgressHandler
) async throws -> ProductStageArtifact
