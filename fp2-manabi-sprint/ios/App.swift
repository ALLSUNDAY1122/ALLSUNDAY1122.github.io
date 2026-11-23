import SwiftUI
import WebKit

@main
struct FP2ManabiSprintApp: App {
    var body: some Scene {
        WindowGroup {
            FP2WebAppView()
                .ignoresSafeArea(.keyboard)
        }
    }
}

struct FP2WebAppView: UIViewRepresentable {
    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        config.preferences.javaScriptCanOpenWindowsAutomatically = false
        let web = WKWebView(frame: .zero, configuration: config)
        web.navigationDelegate = context.coordinator
        web.isOpaque = false
        web.backgroundColor = UIColor(red: 253/255, green: 246/255, blue: 239/255, alpha: 1)
        web.scrollView.contentInsetAdjustmentBehavior = .never
        if let index = Bundle.main.url(forResource: "index", withExtension: "html", subdirectory: "Web"),
           let root = Bundle.main.resourceURL?.appendingPathComponent("Web", isDirectory: true) {
            web.loadFileURL(index, allowingReadAccessTo: root)
        } else {
            web.loadHTMLString("<html lang='ja'><body>教材を読み込めませんでした。</body></html>", baseURL: nil)
        }
        return web
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKNavigationDelegate {
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
