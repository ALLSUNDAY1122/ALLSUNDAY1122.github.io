import SwiftUI
import WebKit
import StoreKit
import UIKit

@main
struct FP2ManabiSprintApp: App {
    @StateObject private var store = FP2StoreKitManager()

    var body: some Scene {
        WindowGroup {
            FP2WebAppView(store: store)
                .ignoresSafeArea(.keyboard)
        }
    }
}

@MainActor
final class FP2StoreKitManager: ObservableObject {
    // Same bundle-qualified ID pattern as FP3; FP2 IDs are new App Store Connect products.
    static let lifetimeID = "com.allsunday1122.fp2manabisprint.premium.lifetime"
    static let monthlyID = "com.allsunday1122.fp2manabisprint.premium.monthly"
    static let productIDs: Set<String> = [lifetimeID, monthlyID]

    @Published private(set) var isPremium = false
    @Published private(set) var prices: [String: String] = [:]
    @Published private(set) var status = "unknown"

    private var products: [String: Product] = [:]
    private var updatesTask: Task<Void, Never>?

    init() {
        updatesTask = Task { [weak self] in
            for await result in Transaction.updates {
                guard !Task.isCancelled else { return }
                guard case .verified(let transaction) = result,
                      Self.productIDs.contains(transaction.productID) else { continue }
                await transaction.finish()
                await self?.refresh()
            }
        }
    }

    func refresh() async {
        var loadFailed = false
        do {
            let fetched = try await Product.products(for: Array(Self.productIDs))
            products = Dictionary(uniqueKeysWithValues: fetched.map { ($0.id, $0) })
            prices = products.mapValues { $0.displayPrice }
        } catch {
            loadFailed = true
        }
        var entitled = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result,
                  Self.productIDs.contains(transaction.productID),
                  transaction.revocationDate == nil,
                  !transaction.isUpgraded else { continue }
            if transaction.productID == Self.lifetimeID {
                entitled = true
            } else if transaction.productID == Self.monthlyID,
                      let expiry = transaction.expirationDate, expiry > Date() {
                entitled = true
            }
        }
        isPremium = entitled
        status = loadFailed ? "error" : (products.count == Self.productIDs.count ? "known" : "product_unavailable")
    }

    func purchase(_ id: String) async {
        guard Self.productIDs.contains(id) else { status = "invalid_product"; return }
        if products[id] == nil { await refresh() }
        guard let product = products[id] else { status = "product_unavailable"; return }
        do {
            switch try await product.purchase() {
            case .success(let verification):
                guard case .verified(let transaction) = verification else {
                    status = "unverified"
                    return
                }
                await transaction.finish()
                await refresh()
            case .pending:
                status = "pending"
            case .userCancelled:
                status = "cancelled"
            @unknown default:
                status = "unknown"
            }
        } catch {
            status = "error"
        }
    }

    func restore() async {
        do {
            try await AppStore.sync()
            await refresh()
        } catch {
            status = "error"
        }
    }

    func payload() -> [String: Any] {
        [
            "native": true,
            "premium": isPremium,
            "status": status,
            "prices": [
                "lifetime": prices[Self.lifetimeID] ?? "",
                "monthly": prices[Self.monthlyID] ?? ""
            ]
        ]
    }
}

struct FP2WebAppView: UIViewRepresentable {
    @ObservedObject var store: FP2StoreKitManager

    func makeCoordinator() -> Coordinator { Coordinator(store: store) }

    func makeUIView(context: Context) -> WKWebView {
        let userContent = WKUserContentController()
        userContent.add(context.coordinator, name: "storeKit")
        userContent.addUserScript(WKUserScript(
            source: "window.__fp2NativeStoreKit = true;",
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        ))
        let config = WKWebViewConfiguration()
        config.userContentController = userContent
        config.websiteDataStore = .default()
        config.preferences.javaScriptCanOpenWindowsAutomatically = false
        let web = WKWebView(frame: .zero, configuration: config)
        web.navigationDelegate = context.coordinator
        web.isOpaque = false
        web.backgroundColor = UIColor(red: 253/255, green: 246/255, blue: 239/255, alpha: 1)
        web.scrollView.contentInsetAdjustmentBehavior = .never
        context.coordinator.webView = web
        if let index = Bundle.main.url(forResource: "index", withExtension: "html", subdirectory: "Web"),
           let root = Bundle.main.resourceURL?.appendingPathComponent("Web", isDirectory: true) {
            web.loadFileURL(index, allowingReadAccessTo: root)
        } else {
            web.loadHTMLString("<html lang='ja'><body>教材を読み込めませんでした。</body></html>", baseURL: nil)
        }
        return web
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        context.coordinator.store = store
        context.coordinator.pushState()
    }

    static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "storeKit")
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var store: FP2StoreKitManager
        weak var webView: WKWebView?

        init(store: FP2StoreKitManager) { self.store = store }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            Task { @MainActor in
                await store.refresh()
                pushState()
            }
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "storeKit",
                  let body = message.body as? [String: Any],
                  let action = body["action"] as? String else { return }
            Task { @MainActor in
                switch action {
                case "purchase":
                    guard let productID = body["productID"] as? String else { return }
                    await store.purchase(productID)
                case "restore":
                    await store.restore()
                case "refresh":
                    await store.refresh()
                default:
                    return
                }
                pushState()
            }
        }

        @MainActor
        func pushState() {
            guard let webView,
                  JSONSerialization.isValidJSONObject(store.payload()),
                  let data = try? JSONSerialization.data(withJSONObject: store.payload()),
                  let json = String(data: data, encoding: .utf8) else { return }
            webView.evaluateJavaScript("window.__fp2StoreKitUpdate && window.__fp2StoreKitUpdate(\(json));")
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let url = navigationAction.request.url else {
                decisionHandler(.cancel)
                return
            }
            if url.isFileURL || url.scheme == "about" {
                decisionHandler(.allow)
                return
            }
            if (url.scheme == "https" || url.scheme == "http"),
               navigationAction.navigationType == .linkActivated {
                UIApplication.shared.open(url)
            }
            decisionHandler(.cancel)
        }
    }
}
