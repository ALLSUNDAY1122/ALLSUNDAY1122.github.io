import SwiftUI

@main
struct KanteishiShortAnswerApp: App {
    @StateObject private var store: LearningStore
    @StateObject private var purchases: PremiumPurchaseStore

    init() {
        _store = StateObject(wrappedValue: LearningStore())
        _purchases = StateObject(
            wrappedValue: PremiumPurchaseStore(productID: Self.configuredProductID())
        )
    }

    var body: some Scene {
        WindowGroup {
            KanteishiShortAnswerRootView()
                .environmentObject(store)
                .environmentObject(purchases)
                .task { await purchases.prepare() }
        }
    }

    private static func configuredProductID(bundle: Bundle = .main) -> String? {
        guard let raw = bundle.object(forInfoDictionaryKey: "PremiumProductID") as? String else {
            return nil
        }
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, !value.contains("$(") else { return nil }
        return value
    }
}
