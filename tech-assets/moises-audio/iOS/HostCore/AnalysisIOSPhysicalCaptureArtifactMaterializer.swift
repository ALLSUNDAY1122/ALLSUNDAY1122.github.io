#if canImport(UIKit) && canImport(Darwin)
import Foundation
import UIKit
import Darwin

public enum AnalysisIOSPhysicalCaptureArtifactMaterializerError: Error, Equatable, Sendable {
    case captureNotStructurallyComplete
    case captureCarriesIssues
    case missingPerformanceEvidence
    case missingPerformanceValidation
    case missingWorkloadExecution
    case missingWorkloadValidation
    case missingAlgorithmEvidence
    case missingExecutionIntegrityEvidence
    case missingExecutionIntegrityValidation
    case currentRuntimeArchiveEvidenceUnavailable
}

@MainActor
public enum AnalysisIOSPhysicalCaptureArtifactMaterializer {
    public static func materialize(
        plan: AnalysisDeviceCapturePlan,
        captureResult: AnalysisIOSPhysicalCaptureResult,
        workloadPolicy: AnalysisDeviceWorkloadPolicy,
        performanceProfile: AnalysisDevicePerformanceAcceptanceProfile
    ) throws -> AnalysisPhysicalCaptureArtifactBundle {
        guard captureResult.status == .structurallyCompletePendingHQ else {
            throw AnalysisIOSPhysicalCaptureArtifactMaterializerError.captureNotStructurallyComplete
        }
        guard captureResult.issues.isEmpty else {
            throw AnalysisIOSPhysicalCaptureArtifactMaterializerError.captureCarriesIssues
        }
        guard let performanceEvidence = captureResult.performanceEvidence else {
            throw AnalysisIOSPhysicalCaptureArtifactMaterializerError.missingPerformanceEvidence
        }
        guard let performanceValidation = captureResult.performanceValidation else {
            throw AnalysisIOSPhysicalCaptureArtifactMaterializerError.missingPerformanceValidation
        }
        guard let workloadExecution = captureResult.workloadExecution else {
            throw AnalysisIOSPhysicalCaptureArtifactMaterializerError.missingWorkloadExecution
        }
        guard let workloadValidation = captureResult.workloadValidation else {
            throw AnalysisIOSPhysicalCaptureArtifactMaterializerError.missingWorkloadValidation
        }
        guard let algorithmEvidence = captureResult.algorithmEvidence else {
            throw AnalysisIOSPhysicalCaptureArtifactMaterializerError.missingAlgorithmEvidence
        }
        guard let integrityEvidence = captureResult.executionIntegrityEvidence else {
            throw AnalysisIOSPhysicalCaptureArtifactMaterializerError.missingExecutionIntegrityEvidence
        }
        guard let integrityValidation = captureResult.executionIntegrityValidation else {
            throw AnalysisIOSPhysicalCaptureArtifactMaterializerError.missingExecutionIntegrityValidation
        }

        let currentRuntimeEvidence: AnalysisCurrentDeviceWorkloadArchiveEvidence
        do {
            currentRuntimeEvidence = try AnalysisCurrentDeviceWorkloadArchiveEvidenceBuilder.build(
                execution: workloadExecution
            )
        } catch {
            throw AnalysisIOSPhysicalCaptureArtifactMaterializerError.currentRuntimeArchiveEvidenceUnavailable
        }

        return try AnalysisPhysicalCaptureArtifactMaterializer.materialize(
            .init(
                plan: plan,
                performanceEvidence: performanceEvidence,
                performanceValidation: performanceValidation,
                workloadReceipt: workloadExecution.receipt,
                workloadValidation: workloadValidation,
                algorithmEvidence: algorithmEvidence,
                currentRuntimeEvidence: currentRuntimeEvidence,
                executionIntegrityEvidence: integrityEvidence,
                executionIntegrityValidation: integrityValidation,
                performanceProfile: performanceProfile,
                workloadPolicy: workloadPolicy
            )
        )
    }

    public static func materializeAndPublish(
        plan: AnalysisDeviceCapturePlan,
        captureResult: AnalysisIOSPhysicalCaptureResult,
        workloadPolicy: AnalysisDeviceWorkloadPolicy,
        performanceProfile: AnalysisDevicePerformanceAcceptanceProfile,
        archiveRootURL: URL,
        fileManager: FileManager = .default
    ) throws -> AnalysisPhysicalCaptureArtifactPublicationReceipt {
        let bundle = try materialize(
            plan: plan,
            captureResult: captureResult,
            workloadPolicy: workloadPolicy,
            performanceProfile: performanceProfile
        )
        return try AnalysisPhysicalCaptureArtifactStager.publish(
            bundle: bundle,
            archiveRootURL: archiveRootURL,
            fileManager: fileManager
        )
    }
}
#endif
