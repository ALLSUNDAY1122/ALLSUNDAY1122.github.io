import SwiftUI
import WebKit
import StoreKit
import UIKit

@main
struct PharmacistSprintApp: App {
    @StateObject private var store = StoreKitManager()

    var body: some Scene {
        WindowGroup {
            WebAppView(store: store)
                .ignoresSafeArea(.keyboard)
        }
    }
}

@MainActor
final class StoreKitManager: ObservableObject {
    static let monthlyID = "jp.allsunday1122.yakuzaishi.monthly"
    static let lifetimeID = "jp.allsunday1122.yakuzaishi.lifetime"
    static let productIDs: Set<String> = [monthlyID, lifetimeID]

    @Published private(set) var isPremium = false
    @Published private(set) var monthlyPrice = ""
    @Published private(set) var lifetimePrice = ""
    @Published private(set) var monthlyAvailable = false
    @Published private(set) var lifetimeAvailable = false
    @Published private(set) var introEligible = false
    @Published private(set) var introConfigured = false
    @Published private(set) var hasMonthlyEntitlement = false
    @Published private(set) var hasLifetimeEntitlement = false
    @Published private(set) var status = "loading"

    private var products: [String: Product] = [:]
    private var transactionUpdatesTask: Task<Void, Never>?

    init() {
        transactionUpdatesTask = Task { [weak self] in
            for await result in Transaction.updates {
                guard !Task.isCancelled else { return }
                guard case .verified(let transaction) = result,
                      Self.productIDs.contains(transaction.productID) else { continue }
                await transaction.finish()
                await self?.refresh()
            }
        }
    }

    func setStatus(_ value: String) { status = value }

    func refresh() async {
        do {
            let loaded = try await Product.products(for: Array(Self.productIDs))
            products = Dictionary(uniqueKeysWithValues: loaded.map { ($0.id, $0) })
            monthlyPrice = products[Self.monthlyID]?.displayPrice ?? ""
            lifetimePrice = products[Self.lifetimeID]?.displayPrice ?? ""
            monthlyAvailable = products[Self.monthlyID] != nil
            lifetimeAvailable = products[Self.lifetimeID] != nil

            if let subscription = products[Self.monthlyID]?.subscription {
                introConfigured = subscription.introductoryOffer != nil
                introEligible = await subscription.isEligibleForIntroOffer
            } else {
                introConfigured = false
                introEligible = false
            }
            status = (monthlyAvailable || lifetimeAvailable) ? "ready" : "product_unavailable"
        } catch {
            status = "product_error"
        }

        var monthly = false
        var lifetime = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result,
                  transaction.revocationDate == nil else { continue }
            if transaction.productID == Self.monthlyID { monthly = true }
            if transaction.productID == Self.lifetimeID { lifetime = true }
        }
        hasMonthlyEntitlement = monthly
        hasLifetimeEntitlement = lifetime
        isPremium = monthly || lifetime
    }

    func purchase(kind: String) async {
        if products.isEmpty { await refresh() }
        let id: String
        switch kind {
        case "monthly": id = Self.monthlyID
        case "lifetime": id = Self.lifetimeID
        default:
            status = "invalid_product"
            return
        }
        guard AppStore.canMakePayments else {
            status = "payments_disabled"
            return
        }
        guard let product = products[id] else {
            status = "product_unavailable"
            return
        }

        do {
            switch try await product.purchase() {
            case .success(let verification):
                guard case .verified(let transaction) = verification else {
                    status = "unverified"
                    return
                }
                await transaction.finish()
                await refresh()
                status = "purchased"
            case .pending:
                status = "pending"
            case .userCancelled:
                status = "cancelled"
            @unknown default:
                status = "unknown"
            }
        } catch {
            status = "purchase_error"
        }
    }

    func restore() async {
        do {
            try await AppStore.sync()
            await refresh()
            status = isPremium ? "restored" : "no_entitlement"
        } catch {
            status = "restore_error"
        }
    }

    func payload() -> [String: Any] {
        [
            "premium": isPremium,
            "monthlyPrice": monthlyPrice,
            "lifetimePrice": lifetimePrice,
            "monthlyAvailable": monthlyAvailable,
            "lifetimeAvailable": lifetimeAvailable,
            "introEligible": introEligible,
            "introConfigured": introConfigured,
            "monthlyEntitled": hasMonthlyEntitlement,
            "lifetimeEntitled": hasLifetimeEntitlement,
            "status": status
        ]
    }
}

struct WebAppView: UIViewRepresentable {
    @ObservedObject var store: StoreKitManager

    func makeCoordinator() -> Coordinator { Coordinator(store: store) }

    func makeUIView(context: Context) -> WKWebView {
        let controller = WKUserContentController()
        controller.add(context.coordinator, name: "storeKit")
        controller.add(context.coordinator, name: "openExternal")

        let configuration = WKWebViewConfiguration()
        configuration.userContentController = controller
        configuration.websiteDataStore = .default()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.isOpaque = false
        webView.backgroundColor = UIColor(red: 247/255, green: 243/255, blue: 234/255, alpha: 1)
        webView.scrollView.backgroundColor = webView.backgroundColor
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.scrollView.alwaysBounceHorizontal = false
        webView.scrollView.showsHorizontalScrollIndicator = false
        context.coordinator.webView = webView

        guard let webRoot = Bundle.main.resourceURL?.appendingPathComponent("Web", isDirectory: true),
              let url = Bundle.main.url(forResource: "index", withExtension: "html", subdirectory: "Web") else {
            webView.loadHTMLString(Self.missingBundleHTML, baseURL: nil)
            return webView
        }
        webView.loadFileURL(url, allowingReadAccessTo: webRoot)
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        context.coordinator.store = store
        context.coordinator.pushStoreKitState()
    }

    static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
        let controller = webView.configuration.userContentController
        controller.removeScriptMessageHandler(forName: "storeKit")
        controller.removeScriptMessageHandler(forName: "openExternal")
    }

    final class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        var store: StoreKitManager
        weak var webView: WKWebView?

        init(store: StoreKitManager) { self.store = store }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            Task { @MainActor in
                await store.refresh()
                pushStoreKitState()
            }
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let url = navigationAction.request.url else {
                decisionHandler(.cancel)
                return
            }
            if url.isFileURL || url.scheme == "about" {
                decisionHandler(.allow)
                return
            }
            if let scheme = url.scheme?.lowercased(), scheme == "https" || scheme == "http" {
                openAllowedURL(url)
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.cancel)
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "openExternal" {
                guard let body = message.body as? [String: Any],
                      let raw = body["url"] as? String,
                      let url = URL(string: raw) else { return }
                openAllowedURL(url)
                return
            }

            guard message.name == "storeKit",
                  let body = message.body as? [String: Any],
                  let action = body["action"] as? String else { return }

            Task { @MainActor in
                switch action {
                case "purchase": await store.purchase(kind: body["product"] as? String ?? "")
                case "restore": await store.restore()
                case "manage": await showManageSubscriptions()
                default: await store.refresh()
                }
                pushStoreKitState()
            }
        }

        @MainActor
        private func showManageSubscriptions() async {
            guard let scene = webView?.window?.windowScene else {
                store.setStatus("manage_unavailable")
                return
            }
            do {
                try await AppStore.showManageSubscriptions(in: scene)
                await store.refresh()
            } catch {
                store.setStatus("manage_error")
            }
        }

        private func openAllowedURL(_ url: URL) {
            guard url.scheme?.lowercased() == "https",
                  let host = url.host?.lowercased(),
                  ["allsunday1122.github.io", "www.mhlw.go.jp", "mhlw.go.jp", "apps.apple.com"].contains(host) else { return }
            Task { @MainActor in UIApplication.shared.open(url, options: [:], completionHandler: nil) }
        }

        @MainActor
        func pushStoreKitState() {
            guard let webView,
                  JSONSerialization.isValidJSONObject(store.payload()),
                  let data = try? JSONSerialization.data(withJSONObject: store.payload()),
                  let json = String(data: data, encoding: .utf8) else { return }
            webView.evaluateJavaScript("window.__nativeStoreKitUpdate && window.__nativeStoreKitUpdate(\(json));")
        }
    }

    private static let missingBundleHTML = """
    <!doctype html><meta name=viewport content='width=device-width,initial-scale=1'>
    <body style='font-family:-apple-system;padding:32px;background:#f7f3ea;color:#1c2331'>
    <h2>教材データを読み込めませんでした</h2><p>アプリを再インストールしてください。</p></body>
    """
}
