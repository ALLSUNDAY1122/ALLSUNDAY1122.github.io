@preconcurrency import ARKit
import UIKit

extension ScanModel {
    nonisolated func session(_ session: ARSession, didFailWithError error: Error) {
        let message = error.localizedDescription
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.phase = .failed("カメラまたはAR追跡を開始できませんでした。設定でカメラ利用を許可してから再試行してください。\n\n\(message)")
            self.trackingMessage = "ARセッションを開始できませんでした。保存済みrawデータは削除されていません"
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }

    nonisolated func sessionWasInterrupted(_ session: ARSession) {
        Task { @MainActor [weak self] in
            guard let self, self.phase == .capturing else { return }
            self.trackingMessage = "カメラが一時中断されました。撮影途中の状態を保存しています"
        }
    }

    nonisolated func sessionInterruptionEnded(_ session: ARSession) {
        Task { @MainActor [weak self] in
            guard let self, self.phase == .capturing else { return }
            guard self.session != nil else {
                self.phase = .failed("ARセッションを再開できませんでした。保存済みrawデータはライブラリに残っています")
                UIApplication.shared.isIdleTimerDisabled = false
                return
            }
            // Never reset tracking here. Captured camera transforms and feature points share the
            // current AR world coordinate system; resetting would silently corrupt a resumed raw scan.
            self.restartAfterSessionInterruption()
        }
    }
}
