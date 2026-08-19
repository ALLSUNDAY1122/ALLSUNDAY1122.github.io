import SwiftUI
import WebKit
import UIKit

struct LocalWebView: UIViewRepresentable {
    let store: StoreKitManager

    func makeCoordinator() -> Coordinator { Coordinator(store: store) }

    func makeUIView(context: Context) -> WKWebView {
        let controller = WKUserContentController()
        controller.add(context.coordinator, name: "exportJSON")
        controller.add(context.coordinator, name: "nativeHaptic")
        controller.add(context.coordinator, name: "storekit")
        controller.addUserScript(WKUserScript(
            source: Self.hapticBridge,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        ))

        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        configuration.userContentController = controller
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.scrollView.bounces = false
        webView.allowsBackForwardNavigationGestures = false
        webView.isOpaque = false
        webView.backgroundColor = UIColor(red: 247/255, green: 243/255, blue: 234/255, alpha: 1)
        webView.scrollView.backgroundColor = webView.backgroundColor

        context.coordinator.webView = webView

        guard let webRoot = Bundle.main.resourceURL?.appendingPathComponent("Web", isDirectory: true),
              let indexURL = Bundle.main.url(forResource: "index", withExtension: "html", subdirectory: "Web") else {
            webView.loadHTMLString(Self.missingBundleHTML, baseURL: nil)
            return webView
        }

        webView.loadFileURL(indexURL, allowingReadAccessTo: webRoot)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
        let controller = webView.configuration.userContentController
        controller.removeScriptMessageHandler(forName: "exportJSON")
        controller.removeScriptMessageHandler(forName: "nativeHaptic")
        controller.removeScriptMessageHandler(forName: "storekit")
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        let store: StoreKitManager
        weak var webView: WKWebView?

        init(store: StoreKitManager) { self.store = store }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            let bridge = #"""
            (function(){
              window.exportData = function(){
                try {
                  const key = 'sm2_manabi_sprint_v110';
                  const state = JSON.parse(localStorage.getItem(key) || '{}');
                  const payload = {
                    app: '第二種衛生管理者-manabi-sprint',
                    version: window.SM2_AUDIT_VERSION || '1.0.0',
                    exportedAt: new Date().toISOString(),
                    state: state
                  };
                  window.webkit.messageHandlers.exportJSON.postMessage(JSON.stringify(payload, null, 2));
                } catch (e) {
                  alert('学習データを書き出せませんでした。');
                }
              };
            })();
            """#
            webView.evaluateJavaScript(bridge)
            Task { @MainActor in
                await store.loadProducts()
                await store.refreshEntitlement()
                sendStoreStatus()
            }
        }

        func webView(_ webView: WKWebView,
                     decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let url = navigationAction.request.url else {
                decisionHandler(.cancel)
                return
            }

            if url.isFileURL || url.scheme == "about" || url.scheme == "blob" {
                decisionHandler(.allow)
                return
            }

            if let scheme = url.scheme?.lowercased(), scheme == "https" || scheme == "http" {
                UIApplication.shared.open(url)
                decisionHandler(.cancel)
                return
            }

            decisionHandler(.cancel)
        }

        func userContentController(_ userContentController: WKUserContentController,
                                   didReceive message: WKScriptMessage) {
            switch message.name {
            case "exportJSON":
                guard let text = message.body as? String else { return }
                export(text)
            case "nativeHaptic":
                guard let kind = message.body as? String else { return }
                haptic(kind)
            case "storekit":
                guard let body = message.body as? [String: Any],
                      let action = body["action"] as? String else { return }
                handleStoreKit(action: action, body: body)
            default:
                return
            }
        }

        private func handleStoreKit(action: String, body: [String: Any]) {
            switch action {
            case "status":
                Task { @MainActor in
                    await store.loadProducts()
                    await store.refreshEntitlement()
                    sendStoreStatus()
                }
            case "purchase":
                let tier = body["tier"] as? String
                let productID = tier == "monthly" ? StoreKitManager.monthlyProductID :
                    (tier == "lifetime" ? StoreKitManager.lifetimeProductID : "")
                guard !productID.isEmpty else { return }
                Task { @MainActor in
                    await store.purchase(productID: productID)
                    sendStoreStatus()
                }
            case "restore":
                Task { @MainActor in
                    await store.restore()
                    sendStoreStatus()
                }
            case "manageSubscriptions":
                guard let url = URL(string: "https://apps.apple.com/account/subscriptions") else { return }
                Task { @MainActor in UIApplication.shared.open(url) }
            default:
                return
            }
        }

        @MainActor
        private func sendStoreStatus() {
            guard let webView else { return }
            let payload: [String: Any] = [
                "isPremium": store.isPremium,
                "entitlementSource": store.entitlementSource,
                "monthlyPrice": store.monthlyDisplayPrice,
                "lifetimePrice": store.lifetimeDisplayPrice,
                "monthlyAvailable": store.monthlyAvailable,
                "lifetimeAvailable": store.lifetimeAvailable,
                "message": store.statusMessage
            ]
            guard let data = try? JSONSerialization.data(withJSONObject: payload),
                  let json = String(data: data, encoding: .utf8) else { return }
            webView.evaluateJavaScript("window.__storekitUpdate && window.__storekitUpdate(\(json));")
        }

        private func haptic(_ kind: String) {
            DispatchQueue.main.async {
                switch kind {
                case "success":
                    let generator = UINotificationFeedbackGenerator()
                    generator.prepare()
                    generator.notificationOccurred(.success)
                case "error":
                    let generator = UINotificationFeedbackGenerator()
                    generator.prepare()
                    generator.notificationOccurred(.error)
                case "selection":
                    let generator = UISelectionFeedbackGenerator()
                    generator.prepare()
                    generator.selectionChanged()
                default:
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.prepare()
                    generator.impactOccurred()
                }
            }
        }

        private func export(_ text: String) {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            let name = "第二種衛生管理者_学びスプリント_\(formatter.string(from: Date())).json"
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)

            guard let data = text.data(using: .utf8) else { return }
            do { try data.write(to: url, options: .atomic) } catch { return }

            DispatchQueue.main.async { [weak self] in
                guard let self, let webView = self.webView else { return }
                let share = UIActivityViewController(activityItems: [url], applicationActivities: nil)
                if let popover = share.popoverPresentationController {
                    popover.sourceView = webView
                    popover.sourceRect = CGRect(x: webView.bounds.midX, y: webView.bounds.midY, width: 1, height: 1)
                }
                Self.topViewController()?.present(share, animated: true)
            }
        }

        private static func topViewController(base: UIViewController? = nil) -> UIViewController? {
            let root = base ?? UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first { $0.isKeyWindow }?.rootViewController

            if let navigation = root as? UINavigationController {
                return topViewController(base: navigation.visibleViewController)
            }
            if let tab = root as? UITabBarController, let selected = tab.selectedViewController {
                return topViewController(base: selected)
            }
            if let presented = root?.presentedViewController {
                return topViewController(base: presented)
            }
            return root
        }
    }

    private static let hapticBridge = #"""
    (() => {
      if (window.__sm2NativeHapticInstalled) return;
      window.__sm2NativeHapticInstalled = true;
      const send = (kind) => {
        try { window.webkit.messageHandlers.nativeHaptic.postMessage(kind); } catch (_) {}
      };
      document.addEventListener('click', (event) => {
        const answer = event.target.closest('.choice,.unknown');
        if (answer) {
          requestAnimationFrame(() => {
            const feedback = document.querySelector('.fbhead');
            if (feedback?.classList.contains('ok')) send('success');
            else if (feedback?.classList.contains('ng')) send('error');
            else send('selection');
          });
          return;
        }
        if (event.target.closest('button')) send('light');
      }, true);
    })();
    """#

    private static let missingBundleHTML = """
    <!doctype html><meta name=viewport content='width=device-width,initial-scale=1'>
    <body style='font-family:-apple-system;padding:32px;background:#f7f3ea;color:#1c2331'>
    <h2>教材データを読み込めませんでした</h2><p>アプリを再インストールしてください。</p></body>
    """
}
