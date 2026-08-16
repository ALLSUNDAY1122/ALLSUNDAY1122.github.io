import Foundation

enum ScanLabPasswordRecoveryPhase: String, Equatable {
    case idle
    case linkRequested
    case passwordUpdateRequired
}

enum ScanLabPasswordRecoverySignal: Equatable {
    case resetRequested
    case callbackSucceeded
    case callbackFailed
    case standardAuthStarted
    case passwordUpdated
    case cancelled
}

enum ScanLabPasswordRecoveryPolicy {
    static func reduce(
        current: ScanLabPasswordRecoveryPhase,
        signal: ScanLabPasswordRecoverySignal
    ) -> ScanLabPasswordRecoveryPhase {
        switch signal {
        case .resetRequested:
            return .linkRequested
        case .callbackSucceeded:
            return current == .linkRequested ? .passwordUpdateRequired : current
        case .callbackFailed, .standardAuthStarted, .passwordUpdated, .cancelled:
            return .idle
        }
    }

    static func isValidNewPassword(_ password: String) -> Bool {
        password.count >= 6
    }
}

enum ScanLabPasswordRecoveryStore {
    private static let key = "scanlab.password-recovery.phase"

    static func load(from defaults: UserDefaults = .standard) -> ScanLabPasswordRecoveryPhase {
        guard let rawValue = defaults.string(forKey: key),
              let phase = ScanLabPasswordRecoveryPhase(rawValue: rawValue)
        else {
            return .idle
        }
        return phase
    }

    static func save(_ phase: ScanLabPasswordRecoveryPhase, to defaults: UserDefaults = .standard) {
        if phase == .idle {
            defaults.removeObject(forKey: key)
        } else {
            defaults.set(phase.rawValue, forKey: key)
        }
    }
}
