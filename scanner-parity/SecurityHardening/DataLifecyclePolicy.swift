import Foundation

public enum SensitiveBookDataKind: String, Codable, Sendable, CaseIterable {
    case sourceVideo
    case pageImage
    case ocrText
    case searchablePDF
    case bookPackage
}

public enum StorageClass: String, Codable, Sendable {
    case userSelectedPersistent
    case appDocuments
    case cache
    case temporary
    case log
    case network
}

public struct DataLifecycleDecision: Codable, Equatable, Sendable {
    public let allowed: Bool
    public let requiresExplicitUserAction: Bool
    public let purgeAfterUse: Bool
    public let reason: String
}

public struct BookDataLifecyclePolicy: Sendable {
    public init() {}

    public func decision(for kind: SensitiveBookDataKind, storage: StorageClass) -> DataLifecycleDecision {
        switch storage {
        case .userSelectedPersistent:
            return .init(allowed: true, requiresExplicitUserAction: true, purgeAfterUse: false,
                         reason: "User explicitly selected a persistent export destination.")
        case .appDocuments:
            return .init(allowed: kind == .bookPackage, requiresExplicitUserAction: false, purgeAfterUse: false,
                         reason: kind == .bookPackage ? "Final local package may persist in app documents." : "Raw/intermediate book data should not persist in app documents.")
        case .cache:
            return .init(allowed: false, requiresExplicitUserAction: false, purgeAfterUse: true,
                         reason: "Book images and OCR-derived content must not be retained in cache.")
        case .temporary:
            return .init(allowed: true, requiresExplicitUserAction: false, purgeAfterUse: true,
                         reason: "Temporary processing is allowed only with deterministic cleanup after use or failure.")
        case .log:
            return .init(allowed: false, requiresExplicitUserAction: false, purgeAfterUse: true,
                         reason: "Sensitive book data must never be written to logs.")
        case .network:
            return .init(allowed: false, requiresExplicitUserAction: true, purgeAfterUse: true,
                         reason: "Standard path is local-only. Network transmission requires a future explicit, separately gated feature.")
        }
    }

    public func mayLog(_ kind: SensitiveBookDataKind) -> Bool {
        decision(for: kind, storage: .log).allowed
    }

    public func mayTransmit(_ kind: SensitiveBookDataKind) -> Bool {
        decision(for: kind, storage: .network).allowed
    }
}

public enum PrivacySafeLogValue: Equatable, Sendable {
    case event(String)
    case count(Int)
    case durationMS(Int64)
    case opaqueID(String)
}

public struct PrivacySafeLogger: Sendable {
    public init() {}

    public func sanitize(_ values: [PrivacySafeLogValue]) -> [String] {
        values.map { value in
            switch value {
            case .event(let name): return "event=\(name)"
            case .count(let count): return "count=\(count)"
            case .durationMS(let value): return "duration_ms=\(value)"
            case .opaqueID(let id):
                let allowed = id.unicodeScalars.allSatisfy { scalar in
                    CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_" )).contains(scalar)
                }
                return allowed ? "id=\(String(id.prefix(64)))" : "id=<redacted>"
            }
        }
    }
}
