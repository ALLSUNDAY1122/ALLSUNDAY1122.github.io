import SwiftUI
import WebKit
import StoreKit
import UIKit

@main
struct TsukanshiSprintApp: App {
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
    static let productID = "jp.allsunday1122.tsukanshi.premium"

    @Published private(set) var isPremium = false
    @Published private(set) var displayPrice = ""
    @Published private(set) var status = "unknown"

    private var product: Product?
    private var transactionUpdatesTask: Task<Void, Never>?

    init() {
        transactionUpdatesTask = Task { [weak self] in
            for await result in Transaction.updates {
                guard !Task.isCancelled else { return }
                guard case .verified(let transaction) = result,
                      transaction.productID == Self.productID else { continue }
                await transaction.finish()
                await self?.refresh()
            }
        }
    }

    func refresh() async {
        var productLoadFailed = false
        if product == nil {
            do {
                product = try await Product.products(for: [Self.productID]).first
                displayPrice = product?.displayPrice ?? ""
            } catch {
                productLoadFailed = true
            }
        }

        var entitled = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            if transaction.productID == Self.productID,
               transaction.revocationDate == nil {
                entitled = true
            }
        }
        isPremium = entitled

        if productLoadFailed {
            status = "error"
        } else {
            status = product == nil ? "product_unavailable" : "known"
        }
    }

    func purchase() async {
        if product == nil { await refresh() }
        guard let product else {
            status = "product_unavailable"
            return
        }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    await transaction.finish()
                    await refresh()
                }
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
            "premium": isPremium,
            "displayPrice": displayPrice,
            "status": status
        ]
    }
}

struct WebAppView: UIViewRepresentable {
    @ObservedObject var store: StoreKitManager

    func makeCoordinator() -> Coordinator {
        Coordinator(store: store)
    }

    func makeUIView(context: Context) -> WKWebView {
        let controller = WKUserContentController()
        controller.add(context.coordinator, name: "storeKit")
        controller.add(context.coordinator, name: "state")
        controller.add(context.coordinator, name: "openExternal")

        let configuration = WKWebViewConfiguration()
        configuration.userContentController = controller
        configuration.websiteDataStore = .default()
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.isOpaque = false
        webView.backgroundColor = UIColor(red: 247/255, green: 243/255, blue: 234/255, alpha: 1)
        webView.scrollView.backgroundColor = webView.backgroundColor
        webView.scrollView.contentInsetAdjustmentBehavior = .never
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
        controller.removeScriptMessageHandler(forName: "state")
        controller.removeScriptMessageHandler(forName: "openExternal")
    }

    final class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        var store: StoreKitManager
        weak var webView: WKWebView?

        init(store: StoreKitManager) {
            self.store = store
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            Task { @MainActor in
                await store.refresh()
                pushStoreKitState()
            }
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "state" {
                persistState(message.body)
                return
            }
            if message.name == "openExternal" {
                openExternal(message.body)
                return
            }
            guard message.name == "storeKit",
                  let body = message.body as? [String: Any],
                  let action = body["action"] as? String else { return }

            Task { @MainActor in
                switch action {
                case "purchase": await store.purchase()
                case "restore": await store.restore()
                default: await store.refresh()
                }
                pushStoreKitState()
            }
        }

        private func openExternal(_ body: Any) {
            guard let payload = body as? [String: Any],
                  let urlString = payload["url"] as? String,
                  let url = URL(string: urlString),
                  url.scheme == "https",
                  let host = url.host?.lowercased(),
                  ["www.customs.go.jp", "customs.go.jp", "allsunday1122.github.io"].contains(host) else { return }
            Task { @MainActor in
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
        }

        private func persistState(_ body: Any) {
            guard JSONSerialization.isValidJSONObject(body),
                  let data = try? JSONSerialization.data(withJSONObject: body) else { return }
            UserDefaults.standard.set(data, forKey: "tsukanshiSprint.webStateBackup")
        }

        @MainActor
        func pushStoreKitState() {
            guard let webView,
                  JSONSerialization.isValidJSONObject(store.payload()),
                  let data = try? JSONSerialization.data(withJSONObject: store.payload()),
                  let json = String(data: data, encoding: .utf8) else { return }
            webView.evaluateJavaScript("window.__nativeStoreKitUpdate(\(json));")
        }
    }

    private static let missingBundleHTML = """
    <!doctype html><meta name=viewport content='width=device-width,initial-scale=1'>
    <body style='font-family:-apple-system;padding:32px;background:#f7f3ea;color:#1c2331'>
    <h2>教材データを読み込めませんでした</h2><p>アプリを再インストールしてください。</p></body>
    """
}
