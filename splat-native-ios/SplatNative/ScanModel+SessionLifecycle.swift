@preconcurrency import ARKit
import UIKit

extension ScanModel {
    nonisolated func session(_ session: ARSession, didFailWithError error: Error) {
        let message = error.localizedDescription
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.phase = .failed("カメラまたはAR追跡を開始できませんでした。設定でカメラ利用を許可してから再試行してください。\n\n\(message)")
            self.trackingMessage = "ARセッションを開始できませんでした"
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }

    nonisolated func sessionWasInterrupted(_ session: ARSession) {
        Task { @MainActor [weak self] in
            self?.handleSessionInterrupted()
        }
    }

    nonisolated func sessionInterruptionEnded(_ session: ARSession) {
        Task { @MainActor [weak self] in
            self?.handleSessionInterruptionEnded()
        }
    }

    nonisolated func sessionShouldAttemptRelocalization(_ session: ARSession) -> Bool {
        true
    }
}
