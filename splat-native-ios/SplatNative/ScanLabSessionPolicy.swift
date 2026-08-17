import Foundation

enum ScanLabSessionEvent: Equatable {
    case initialSession(hasSession: Bool)
    case signedIn
    case signedOut
    case tokenRefreshed
    case userUpdated
    case passwordRecovery
}

enum ScanLabSessionRecoveryDecision: Equatable {
    case keepAuthenticatedAndRetry
    case requireSignIn
}

struct ScanLabSessionPolicy {
    static func isAuthenticated(after event: ScanLabSessionEvent) -> Bool {
        switch event {
        case .initialSession(let hasSession):
            hasSession
        case .signedIn, .tokenRefreshed, .userUpdated, .passwordRecovery:
            true
        case .signedOut:
            false
        }
    }

    static func shouldReloadPrivateData(after event: ScanLabSessionEvent) -> Bool {
        switch event {
        case .initialSession(let hasSession):
            hasSession
        case .signedIn, .userUpdated, .passwordRecovery:
            true
        case .signedOut, .tokenRefreshed:
            false
        }
    }

    static func recoveryDecision(hasCachedSessionAfterFailure: Bool) -> ScanLabSessionRecoveryDecision {
        hasCachedSessionAfterFailure ? .keepAuthenticatedAndRetry : .requireSignIn
    }
}
