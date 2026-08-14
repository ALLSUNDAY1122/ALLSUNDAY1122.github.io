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
            guard let self, self.phase == .capturing else { return }
            self.trackingMessage = "カメラが一時中断されました。アプリへ戻ると追跡を再開します"
        }
    }

    nonisolated func sessionInterruptionEnded(_ session: ARSession) {
        Task { @MainActor [weak self] in
            guard let self, self.phase == .capturing else { return }
            self.trackingMessage = "位置を再確認しています。対象を中央にしてゆっくり動かしてください"
            guard let activeSession = self.session else {
                self.phase = .failed("ARセッションを再開できませんでした")
                UIApplication.shared.isIdleTimerDisabled = false
                return
            }
            let config = ARWorldTrackingConfiguration()
            config.worldAlignment = .gravity
            config.isLightEstimationEnabled = true
            config.environmentTexturing = .none
            activeSession.run(config, options: [.resetTracking, .removeExistingAnchors])
        }
    }
}
