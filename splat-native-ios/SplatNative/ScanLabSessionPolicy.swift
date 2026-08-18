import Foundation

enum ScanLabSessionEvent: Equatable {
    case initialSession(hasSession: Bool, isExpired: Bool)
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
        case .initialSession(let hasSession, _): hasSession
        case .signedIn, .tokenRefreshed, .userUpdated, .passwordRecovery: true
        case .signedOut: false
        }
    }
    static func shouldReloadPrivateData(after event: ScanLabSessionEvent) -> Bool {
        switch event {
        case .initialSession(let hasSession, let isExpired): hasSession && !isExpired
        case .signedIn, .userUpdated, .passwordRecovery: true
        case .signedOut, .tokenRefreshed: false
        }
    }
    static func needsRefreshBeforePrivateData(after event: ScanLabSessionEvent) -> Bool {
        if case .initialSession(let hasSession, let isExpired) = event { return hasSession && isExpired }
        return false
    }
    static func recoveryDecision(hasCachedSessionAfterFailure: Bool) -> ScanLabSessionRecoveryDecision {
        hasCachedSessionAfterFailure ? .keepAuthenticatedAndRetry : .requireSignIn
    }
}
