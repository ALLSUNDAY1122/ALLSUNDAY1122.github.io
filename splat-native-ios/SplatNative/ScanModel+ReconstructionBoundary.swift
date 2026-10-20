import Foundation
import UIKit

/// Stable owner-facing contract for Gaussian Splat reconstruction work.
///
/// A2 may evolve reconstruction behind this boundary without reaching into
/// persistence or app-lifecycle implementation details owned elsewhere.
@MainActor
protocol ScanReconstructionBoundary: AnyObject {
    var phase: ScanModel.Phase { get }
    var trainingProgress: Double { get }
    var trainingIteration: Int { get }
    var splatCount: Int { get }
    var resultURL: URL? { get }
    var previewImage: UIImage? { get }
    var canRetryGeneration: Bool { get }
    var trainingStageText: String { get }

    func train()
    func retryGeneration()
    func enhanceResult()
}

extension ScanModel: ScanReconstructionBoundary {}
