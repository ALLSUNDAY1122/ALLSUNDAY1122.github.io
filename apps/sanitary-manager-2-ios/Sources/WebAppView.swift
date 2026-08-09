import SwiftUI
import UIKit
import WebKit

struct WebAppView: UIViewRepresentable {
    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> WKWebView {
        let controller = WKUserContentController()
        controller.add(context.coordinator, name: "nativeHaptic")
        controller.addUserScript(WKUserScript(
            source: Self.hapticBridgeScript,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        ))

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
        webView.allowsBackForwardNavigationGestures = false

        guard let indexURL = Bundle.main.url(
            forResource: "index",
            withExtension: "html",
            subdirectory: "WebApp"
        ) else {
            webView.loadHTMLString(Self.missingBundleHTML, baseURL: nil)
            return webView
        }

        webView.loadFileURL(indexURL, allowingReadAccessTo: indexURL.deletingLastPathComponent())
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        uiView.configuration.userContentController.removeScriptMessageHandler(forName: "nativeHaptic")
    }

    final class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "nativeHaptic", let kind = message.body as? String else { return }
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

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            guard let url = navigationAction.request.url else {
                decisionHandler(.cancel)
                return
            }

            if url.isFileURL || url.scheme == "about" {
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
    }

    private static let hapticBridgeScript = #"""
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
