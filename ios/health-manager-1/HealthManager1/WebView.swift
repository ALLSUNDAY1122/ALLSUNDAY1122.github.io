import SwiftUI
import WebKit
import UIKit

struct WebView: UIViewRepresentable {
    let store: StoreKitManager

    func makeCoordinator() -> Coordinator {
        Coordinator(store: store)
    }

    func makeUIView(context: Context) -> WKWebView {
        let controller = WKUserContentController()
        controller.add(context.coordinator, name: "storekit")

        let config = WKWebViewConfiguration()
        config.userContentController = controller
        config.websiteDataStore = .default()

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        context.coordinator.webView = webView

        guard let url = Bundle.main.url(forResource: "index", withExtension: "html") else {
            assertionFailure("index.html not found")
            return webView
        }
        webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        let store: StoreKitManager
        weak var webView: WKWebView?

        init(store: StoreKitManager) {
            self.store = store
        }

        deinit {
            webView?.configuration.userContentController.removeScriptMessageHandler(forName: "storekit")
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            Task { @MainActor in
                await store.loadProducts()
                await store.refreshEntitlement()
                sendStatus()
            }
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "storekit",
                  let body = message.body as? [String: Any],
                  let action = body["action"] as? String else { return }

            switch action {
            case "status":
                Task { @MainActor in
                    await store.loadProducts()
                    await store.refreshEntitlement()
                    sendStatus()
                }
            case "purchase":
                if let productID = body["productID"] as? String {
                    Task { @MainActor in
                        await store.purchase(productID: productID)
                        sendStatus()
                    }
                }
            case "restore":
                Task { @MainActor in
                    await store.restore()
                    sendStatus()
                }
            case "openURL":
                if let value = body["url"] as? String, let url = URL(string: value) {
                    Task { @MainActor in
                        UIApplication.shared.open(url)
                    }
                }
            default:
                break
            }
        }

        @MainActor
        private func sendStatus() {
            guard let webView else { return }
            let payload: [String: Any] = [
                "isPremium": store.isPremium,
                "entitlementSource": store.entitlementSource,
                "monthlyPrice": store.monthlyDisplayPrice,
                "lifetimePrice": store.lifetimeDisplayPrice,
                "monthlyAvailable": store.monthlyAvailable,
                "lifetimeAvailable": store.lifetimeAvailable,
                "monthlyIntroEligible": store.monthlyIntroEligible,
                "monthlyHasSevenDayFreeTrial": store.monthlyHasSevenDayFreeTrial,
                "message": store.statusMessage
            ]
            guard let data = try? JSONSerialization.data(withJSONObject: payload),
                  let json = String(data: data, encoding: .utf8) else { return }
            webView.evaluateJavaScript("window.__storekitUpdate(\(json));")
        }
    }
}
