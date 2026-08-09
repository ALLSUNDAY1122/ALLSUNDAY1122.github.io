import SwiftUI
import WebKit
import UIKit

struct LocalWebView: UIViewRepresentable {
    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> WKWebView {
        let controller = WKUserContentController()
        controller.add(context.coordinator, name: "exportJSON")

        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        configuration.userContentController = controller

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.scrollView.bounces = false
        webView.isOpaque = false
        webView.backgroundColor = UIColor(red: 247/255, green: 243/255, blue: 234/255, alpha: 1)

        context.coordinator.webView = webView

        guard let webRoot = Bundle.main.resourceURL?.appendingPathComponent("Web", isDirectory: true),
              let indexURL = Bundle.main.url(forResource: "index", withExtension: "html", subdirectory: "Web") else {
            assertionFailure("Bundled Web/index.html was not found")
            return webView
        }

        webView.loadFileURL(indexURL, allowingReadAccessTo: webRoot)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "exportJSON")
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        weak var webView: WKWebView?

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

            decisionHandler(.allow)
        }

        func userContentController(_ userContentController: WKUserContentController,
                                   didReceive message: WKScriptMessage) {
            guard message.name == "exportJSON", let text = message.body as? String else { return }
            export(text)
        }

        private func export(_ text: String) {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            let name = "第二種衛生管理者_学びスプリント_\(formatter.string(from: Date())).json"
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)

            do {
                try text.data(using: .utf8)?.write(to: url, options: .atomic)
            } catch {
                return
            }

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
}
