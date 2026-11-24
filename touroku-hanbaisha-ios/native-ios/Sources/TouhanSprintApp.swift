import SwiftUI
import WebKit
import UIKit

private enum ReleaseConfig {
    static var root: URL? { Bundle.main.resourceURL?.appendingPathComponent("OfflineWeb", isDirectory: true) }
    static var homeURL: URL? { root?.appendingPathComponent("official-practice.html") }
}

@main
struct TouhanSprintApp: App {
    var body: some Scene {
        WindowGroup { TouhanWebView().ignoresSafeArea(.container, edges: .bottom) }
    }
}

struct TouhanWebView: UIViewRepresentable {
    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        let saved = StudyStore.load()
        configuration.userContentController.addUserScript(WKUserScript(source: "window.__touhanStudyState = " + saved + ";", injectionTime: .atDocumentStart, forMainFrameOnly: true))
        configuration.userContentController.add(context.coordinator, name: "studyRecord")
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        if let home = ReleaseConfig.homeURL, let root = ReleaseConfig.root {
            webView.loadFileURL(home, allowingReadAccessTo: root)
        } else {
            context.coordinator.showFailure(in: webView)
        }
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}
    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        uiView.configuration.userContentController.removeScriptMessageHandler(forName: "studyRecord")
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "studyRecord", message.frameInfo.isMainFrame,
                  let url = message.frameInfo.request.url, isLocal(url),
                  url.lastPathComponent == "official-practice.html",
                  let raw = message.body as? String else { return }
            if !StudyStore.save(raw) { message.webView?.evaluateJavaScript("window.studySaveFailed?.()") }
        }

        private func isLocal(_ url: URL) -> Bool {
            guard url.isFileURL, let root = ReleaseConfig.root else { return false }
            return url.standardizedFileURL.path.hasPrefix(root.standardizedFileURL.path + "/")
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let url = navigationAction.request.url else { decisionHandler(.cancel); return }
            if isLocal(url) { decisionHandler(.allow); return }
            if url.absoluteString == "about:blank" { decisionHandler(.allow); return }
            if navigationAction.navigationType == .linkActivated,
               let scheme = url.scheme?.lowercased(), ["https", "mailto"].contains(scheme) {
                UIApplication.shared.open(url)
            }
            decisionHandler(.cancel)
        }

        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                     for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            guard let url = navigationAction.request.url else { return nil }
            if isLocal(url), let root = ReleaseConfig.root {
                webView.loadFileURL(url, allowingReadAccessTo: root)
            } else if navigationAction.navigationType == .linkActivated,
                      let scheme = url.scheme?.lowercased(), ["https", "mailto"].contains(scheme) {
                UIApplication.shared.open(url)
            }
            return nil
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            if (error as NSError).code != NSURLErrorCancelled { showFailure(in: webView) }
        }
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            if (error as NSError).code != NSURLErrorCancelled { showFailure(in: webView) }
        }

        func showFailure(in webView: WKWebView) {
            webView.loadHTMLString("<html lang='ja'><meta name='viewport' content='width=device-width'><h1>学習データを読み込めませんでした</h1><p>アプリを終了して再起動してください。</p></html>", baseURL: nil)
        }
    }
}

private enum StudyStore {
    static let key = "touhan.study.v1"
    static func load() -> String {
        guard let raw = UserDefaults.standard.string(forKey: key), valid(raw) else { return "null" }
        return raw
    }
    static func valid(_ raw: String) -> Bool {
        guard raw.utf8.count <= 2_000_000, let data = raw.data(using: .utf8),
              let dict = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              dict["version"] as? Int == 1, dict["stats"] is [String: Any], dict["history"] is [[String: Any]] else { return false }
        return true
    }
    static func save(_ raw: String) -> Bool {
        guard valid(raw) else { return false }
        UserDefaults.standard.set(raw, forKey: key)
        return true
    }
}
