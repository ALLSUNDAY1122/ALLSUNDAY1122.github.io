import Foundation

public enum ProductInputKind: String, Codable, Sendable, Equatable { case image, video }

public struct ProductInputAsset: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let kind: ProductInputKind
    public let localURL: URL
    public let displayName: String
    public init(id: String = UUID().uuidString, kind: ProductInputKind, localURL: URL, displayName: String) {
        self.id = id; self.kind = kind; self.localURL = localURL; self.displayName = displayName
    }
}

public enum ProductPermissionKind: String, Codable, Sendable, Equatable { case camera }
public enum ProductPermissionState: String, Codable, Sendable, Equatable { case notDetermined, authorized, denied, restricted }
public enum ProductFlowStep: String, Codable, Sendable, Equatable { case selectingInput, ready, processing, review, exporting, completed, failed }
public enum ProductProcessingStage: String, Codable, Sendable, Equatable, CaseIterable { case frameExtraction, imageCorrection, pageAudit, ocr, packageWrite }

public struct ProductProgress: Codable, Sendable, Equatable {
    public var stage: ProductProcessingStage
    public var fraction: Double
    public var completedUnits: Int
    public var totalUnits: Int?
    public init(stage: ProductProcessingStage, fraction: Double, completedUnits: Int = 0, totalUnits: Int? = nil) {
        self.stage = stage; self.fraction = min(1, max(0, fraction)); self.completedUnits = max(0, completedUnits); self.totalUnits = totalUnits.map { max(0, $0) }
    }
}

public enum ProductFailureCode: String, Codable, Sendable, Equatable { case permissionDenied, importFailed, processingFailed, exportFailed, cancelled }

public struct ProductFlowFailure: Codable, Sendable, Equatable {
    public let code: ProductFailureCode
    public let message: String
    public let recoveryStep: ProductFlowStep
    public init(code: ProductFailureCode, message: String, recoveryStep: ProductFlowStep) { self.code = code; self.message = message; self.recoveryStep = recoveryStep }
}

public struct ProductFlowState: Codable, Sendable, Equatable {
    public var step: ProductFlowStep
    public var inputAssets: [ProductInputAsset]
    public var cameraPermission: ProductPermissionState
    public var progress: ProductProgress?
    public var reviewRequiredCount: Int
    public var bookPackageURL: URL?
    public var failure: ProductFlowFailure?
    public init(step: ProductFlowStep = .selectingInput, inputAssets: [ProductInputAsset] = [], cameraPermission: ProductPermissionState = .notDetermined, progress: ProductProgress? = nil, reviewRequiredCount: Int = 0, bookPackageURL: URL? = nil, failure: ProductFlowFailure? = nil) {
        self.step = step; self.inputAssets = inputAssets; self.cameraPermission = cameraPermission; self.progress = progress; self.reviewRequiredCount = max(0, reviewRequiredCount); self.bookPackageURL = bookPackageURL; self.failure = failure
    }
}

public enum ProductFlowAction: Sendable, Equatable {
    case replaceInput([ProductInputAsset]); case cameraPermissionChanged(ProductPermissionState); case startProcessing; case updateProgress(ProductProgress); case processingFinished(bookPackageURL: URL, reviewRequiredCount: Int); case reviewResolved(remaining: Int); case beginExport; case exportFinished; case fail(ProductFlowFailure); case retry; case cancel; case reset
}

public enum ProductFlowReducer {
    public static func reduce(state: inout ProductFlowState, action: ProductFlowAction) {
        switch action {
        case .replaceInput(let assets):
            state.inputAssets = deduplicated(assets); state.bookPackageURL = nil; state.progress = nil; state.reviewRequiredCount = 0; state.failure = nil; state.step = state.inputAssets.isEmpty ? .selectingInput : .ready
        case .cameraPermissionChanged(let permission):
            state.cameraPermission = permission
            if permission == .denied || permission == .restricted {
                state.failure = ProductFlowFailure(code: .permissionDenied, message: "Camera access is unavailable. You can continue by importing from Photos or Files.", recoveryStep: state.inputAssets.isEmpty ? .selectingInput : .ready)
            } else if state.failure?.code == .permissionDenied { state.failure = nil; state.step = state.inputAssets.isEmpty ? .selectingInput : .ready }
        case .startProcessing:
            guard !state.inputAssets.isEmpty else { state.failure = ProductFlowFailure(code: .importFailed, message: "Select at least one video or image before processing.", recoveryStep: .selectingInput); state.step = .failed; return }
            state.failure = nil; state.bookPackageURL = nil; state.reviewRequiredCount = 0; state.progress = ProductProgress(stage: .frameExtraction, fraction: 0); state.step = .processing
        case .updateProgress(let progress):
            guard state.step == .processing else { return }; state.progress = progress
        case .processingFinished(let packageURL, let reviewCount):
            guard state.step == .processing else { return }; state.progress = ProductProgress(stage: .packageWrite, fraction: 1); state.bookPackageURL = packageURL; state.reviewRequiredCount = max(0, reviewCount); state.failure = nil; state.step = reviewCount > 0 ? .review : .exporting
        case .reviewResolved(let remaining):
            guard state.step == .review else { return }; state.reviewRequiredCount = max(0, remaining); if remaining <= 0 { state.step = .exporting }
        case .beginExport:
            guard state.bookPackageURL != nil else { state.failure = ProductFlowFailure(code: .exportFailed, message: "BookPackage is not available for export.", recoveryStep: .ready); state.step = .failed; return }; state.step = .exporting
        case .exportFinished:
            guard state.step == .exporting, state.bookPackageURL != nil else { return }; state.failure = nil; state.step = .completed
        case .fail(let failure): state.failure = failure; state.step = .failed
        case .retry:
            guard let failure = state.failure else { return }; let recovery = failure.recoveryStep; state.failure = nil; state.progress = nil; state.step = recovery; if recovery == .selectingInput { state.bookPackageURL = nil }
        case .cancel:
            guard state.step == .processing || state.step == .review || state.step == .exporting else { return }; state.failure = ProductFlowFailure(code: .cancelled, message: "Processing was cancelled. Your imported input remains available.", recoveryStep: state.inputAssets.isEmpty ? .selectingInput : .ready); state.progress = nil; state.step = .failed
        case .reset:
            let permission = state.cameraPermission; state = ProductFlowState(cameraPermission: permission)
        }
    }
    private static func deduplicated(_ assets: [ProductInputAsset]) -> [ProductInputAsset] { var seen = Set<String>(); return assets.filter { seen.insert($0.localURL.standardizedFileURL.path).inserted } }
}
