import Foundation

public enum HokenshiReleaseContentStoreError: Error, Equatable {
    case missingBundledQuestions
}

public enum HokenshiReleaseContentStore {
    public static let resourceName = "questions"
    public static let resourceExtension = "json"
    public static let contentVersion = "hokenshi-release-2026-08-13"
    public static let stateNamespace = "hokenshi-sprint"

    public static func load() throws -> HokenshiContentStore {
        #if SWIFT_PACKAGE
        let bundle = Bundle.module
        #else
        let bundle = Bundle.main
        #endif
        guard let url = bundle.url(forResource: resourceName, withExtension: resourceExtension) else {
            throw HokenshiReleaseContentStoreError.missingBundledQuestions
        }
        return try HokenshiContentStore(url: url, requireReleaseReady: true)
    }
}
