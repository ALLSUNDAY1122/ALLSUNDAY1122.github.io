import Foundation

enum ScanLabAuthPhase: Equatable {
    case resolving
    case signedOut
    case signedIn
}

enum ScanLabAuthSignal: Equatable {
    case sessionResolved(hasSession: Bool)
    case signedOut
}

enum ScanLabAuthStatePolicy {
    static func reduce(current: ScanLabAuthPhase, signal: ScanLabAuthSignal) -> ScanLabAuthPhase {
        switch signal {
        case .sessionResolved(let hasSession):
            return hasSession ? .signedIn : .signedOut
        case .signedOut:
            return .signedOut
        }
    }
}
