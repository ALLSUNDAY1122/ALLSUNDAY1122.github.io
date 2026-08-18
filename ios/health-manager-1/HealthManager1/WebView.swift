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
        webView.isOpaque = false
        webView.backgroundColor = UIColor(red: 247 / 255, green: 243 / 255, blue: 234 / 255, alpha: 1)
        webView.scrollView.backgroundColor = webView.backgroundColor
        context.coordinator.webView = webView

        guard let url = Bundle.main.url(forResource: "index", withExtension: "html") else {
            context.coordinator.fallbackShown = true
            webView.loadHTMLString(Self.missingBundleHTML, baseURL: nil)
            return webView
        }

        webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        let store: StoreKitManager
        weak var webView: WKWebView?
        var fallbackShown = false

        init(store: StoreKitManager) {
            self.store = store
        }

        deinit {
            webView?.configuration.userContentController.removeScriptMessageHandler(forName: "storekit")
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            guard !fallbackShown else { return }

            webView.evaluateJavaScript("document.getElementById('app')?.children.length ?? 0") { [weak self, weak webView] value, error in
                guard let self, let webView else { return }
                let renderedChildren = (value as? NSNumber)?.intValue ?? 0

                guard error == nil, renderedChildren > 0 else {
                    self.showFallback(Self.runtimeFailureMessage, in: webView)
                    return
                }

                Task { @MainActor in
                    await self.store.loadProducts()
                    await self.store.refreshEntitlement()
                    self.sendStatus()
                }
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            showFallback("教材画面の読み込みに失敗しました。", in: webView)
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            showFallback("教材画面を開始できませんでした。", in: webView)
        }

        private func showFallback(_ message: String, in webView: WKWebView) {
            guard !fallbackShown else { return }
            fallbackShown = true
            let escaped = message
                .replacingOccurrences(of: "&", with: "&amp;")
                .replacingOccurrences(of: "<", with: "&lt;")
                .replacingOccurrences(of: ">", with: "&gt;")
            webView.loadHTMLString(WebView.failureHTML(message: escaped), baseURL: nil)
        }

        private static let runtimeFailureMessage = "教材データは読み込まれましたが、画面の初期化に失敗しました。"

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

    private static let missingBundleHTML = failureHTML(message: "教材データがアプリに同梱されていません。")

    private static func failureHTML(message: String) -> String {
        """
        <!doctype html>
        <html lang="ja">
        <meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">
        <body style="margin:0;background:#f7f3ea;color:#1c2331;font-family:-apple-system,BlinkMacSystemFont,sans-serif;display:flex;min-height:100vh;align-items:center;justify-content:center;padding:32px;box-sizing:border-box">
          <main style="max-width:360px;text-align:center">
            <div style="font-size:42px;margin-bottom:14px">!</div>
            <h2 style="font-size:20px;margin:0 0 10px">教材画面を表示できません</h2>
            <p style="font-size:14px;line-height:1.7;margin:0;color:#59616d">\(message)<br>最新版へ更新して、もう一度起動してください。</p>
          </main>
        </body>
        </html>
        """
    }
}
