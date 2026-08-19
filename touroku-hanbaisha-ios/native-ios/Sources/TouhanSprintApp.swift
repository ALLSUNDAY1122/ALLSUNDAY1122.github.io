import SwiftUI
import WebKit
import UIKit

private enum ReleaseConfig {
    static let homeURL = URL(string: "https://allsunday1122.github.io/touroku-hanbaisha-sprint/")!
    static let allowedHost = "allsunday1122.github.io"
    static let allowedPathPrefix = "/touroku-hanbaisha-sprint/"
}

@main
struct TouhanSprintApp: App {
    var body: some Scene {
        WindowGroup {
            TouhanWebView()
                .ignoresSafeArea(.container, edges: .bottom)
        }
    }
}

struct TouhanWebView: UIViewRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.contentInsetAdjustmentBehavior = .automatic
        webView.load(URLRequest(url: ReleaseConfig.homeURL, cachePolicy: .reloadRevalidatingCacheData, timeoutInterval: 30))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKNavigationDelegate {
        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            guard let url = navigationAction.request.url else {
                decisionHandler(.cancel)
                return
            }

            if isInAppURL(url) {
                decisionHandler(.allow)
                return
            }

            if let scheme = url.scheme?.lowercased(), ["http", "https", "mailto"].contains(scheme) {
                UIApplication.shared.open(url)
            }
            decisionHandler(.cancel)
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            showNetworkFallback(in: webView)
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            showNetworkFallback(in: webView)
        }

        private func isInAppURL(_ url: URL) -> Bool {
            guard url.scheme?.lowercased() == "https",
                  url.host?.lowercased() == ReleaseConfig.allowedHost else {
                return false
            }
            return url.path == "/touroku-hanbaisha-sprint" || url.path.hasPrefix(ReleaseConfig.allowedPathPrefix)
        }

        private func showNetworkFallback(in webView: WKWebView) {
            let home = ReleaseConfig.homeURL.absoluteString
                .replacingOccurrences(of: "&", with: "&amp;")
                .replacingOccurrences(of: "\"", with: "&quot;")
            let html = """
            <!doctype html><html lang="ja"><head><meta name="viewport" content="width=device-width,initial-scale=1">
            <style>body{font-family:-apple-system,sans-serif;background:#f7f8fa;color:#173a5e;margin:0;padding:48px 24px;text-align:center}main{max-width:520px;margin:auto}a{display:inline-block;margin-top:20px;padding:14px 22px;border-radius:12px;background:#173a5e;color:#fff;text-decoration:none;font-weight:700}</style></head>
            <body><main><h1>通信を確認してください</h1><p>学習画面を読み込めませんでした。通信状態を確認して、もう一度お試しください。</p><a href="\(home)">再読み込み</a></main></body></html>
            """
            webView.loadHTMLString(html, baseURL: nil)
        }
    }
}
