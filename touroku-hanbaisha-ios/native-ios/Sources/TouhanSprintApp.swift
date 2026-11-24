import SwiftUI
import WebKit
import UIKit

private enum ReleaseConfig {
    static var root: URL? { Bundle.main.resourceURL?.appendingPathComponent("OfflineWeb", isDirectory: true) }
    static var homeURL: URL? { root?.appendingPathComponent("official-practice.html") }
}

@main
struct TouhanSprintApp: App {
    @StateObject private var premium = TouhanPremium()
    @State private var paywall = false
    @Environment(\.scenePhase) private var phase
    var body: some Scene {
        WindowGroup {
            TouhanWebView(unlocked: premium.unlocked, openPaywall: { paywall = true })
                .ignoresSafeArea(.container, edges: .bottom)
                .sheet(isPresented: $paywall) { TouhanPaywall(premium: premium) }
                .task { await premium.start() }
                .onChange(of: phase) { value in if value == .active { Task { await premium.refresh() } } }
        }
    }
}

struct TouhanWebView: UIViewRepresentable {
    let unlocked: Bool
    let openPaywall: () -> Void
    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        StudyStore.installSnapshot(in: configuration.userContentController)
        configuration.userContentController.add(context.coordinator, name: "studyRecord")
        configuration.userContentController.add(context.coordinator, name: "premiumPaywall")
        context.coordinator.openPaywall = openPaywall
        context.coordinator.unlocked = unlocked
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

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.openPaywall = openPaywall
        context.coordinator.unlocked = unlocked
        context.coordinator.syncEntitlement(webView)
    }
    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        uiView.configuration.userContentController.removeScriptMessageHandler(forName: "studyRecord")
        uiView.configuration.userContentController.removeScriptMessageHandler(forName: "premiumPaywall")
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
        var openPaywall: (() -> Void)?
        var unlocked = false
        func syncEntitlement(_ webView: WKWebView) {
            guard webView.url?.lastPathComponent == "official-practice.html" else { return }
            webView.evaluateJavaScript("window.setPremiumEntitlement?.(" + (unlocked ? "true" : "false") + ")")
        }
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "premiumPaywall", message.frameInfo.isMainFrame,
               let url = message.frameInfo.request.url, isLocal(url), url.lastPathComponent == "official-practice.html" { openPaywall?(); return }
            guard message.name == "studyRecord", message.frameInfo.isMainFrame,
                  let url = message.frameInfo.request.url, isLocal(url),
                  url.lastPathComponent == "official-practice.html",
                  let raw = message.body as? String else { return }
            if StudyStore.save(raw) {
                StudyStore.installSnapshot(in: userContentController)
            } else {
                message.webView?.evaluateJavaScript("window.studySaveFailed?.()")
            }
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


#if DEBUG
        private var smokeStarted = false
#endif
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            syncEntitlement(webView)
#if DEBUG
            guard !smokeStarted, webView.url?.lastPathComponent == "official-practice.html" else { return }
            let args = ProcessInfo.processInfo.arguments
            let write = args.contains("--touhan-ui-smoke-write")
            let read = args.contains("--touhan-ui-smoke-read")
            guard write || read else { return }
            smokeStarted = true
            webView.evaluateJavaScript("window.setPremiumEntitlement?.(true)")
            let script: String
            if write {
                script = """
                (()=>{const check=(v,m)=>{if(!v)throw Error(m)};
                check(records.length===599,'bank');check(!document.getElementById('home').classList.contains('hidden'),'home');
                document.getElementById('homeStart').click();document.getElementById('year').value='2024';document.getElementById('chapter').value=records.find(q=>q.year===2024&&q.questionNo===81).chapter;updateCount();
                document.getElementById('start').click();check(subset.every(q=>q.year===2024),'scope');
                const first=subset[0];document.querySelectorAll('#choices button')[first.answer].click();
                check(document.querySelector('#feedback .result').textContent==='正解','answer');
                document.getElementById('next').click();check(position===1,'next');
                document.getElementById('navRecords').click();check(document.getElementById('yearRecords').children.length===5,'years');
                check(document.getElementById('chapterRecords').children.length===5,'chapters');
                check(document.getElementById('answerHistory').children.length===1,'history');
                return JSON.stringify({phase:'write',status:'PASS',question:first.id,position:1,progress:statsFor(records).done,accuracy:rate(statsFor(records))})})()
                """
            } else {
                script = """
                (()=>{const check=(v,m)=>{if(!v)throw Error(m)};
                check(records.length===599,'bank');check(!document.getElementById('home').classList.contains('hidden'),'home');
                check(statsFor(records).done===1,'persisted progress');check(rate(statsFor(records))==='100%','persisted accuracy');
                check(!document.getElementById('resume').disabled,'resume');document.getElementById('resume').click();
                check(position===1,'resumed position');check(correct===1&&denominator===1,'resumed score');
                document.getElementById('unknown').click();document.getElementById('navHome').click();
                document.getElementById('resume').click();check(selected&&denominator===2,'resume after answer');
                check(statsFor(records).n===2,'no duplicate attempt');document.getElementById('navRecords').click();
                check(document.getElementById('answerHistory').children.length===2,'restored history');
                check(rate(statsFor(records))==='50%','updated accuracy');
                return JSON.stringify({phase:'read',status:'PASS',progress:statsFor(records).done,accuracy:rate(statsFor(records)),position,attempts:statsFor(records).n})})()
                """
            }
            webView.evaluateJavaScript(script) { result, error in
                let output: Data
                if let result = result as? String, error == nil {
                    output = Data(result.utf8)
                } else {
                    output = (try? JSONSerialization.data(withJSONObject: ["status": "FAIL", "error": error?.localizedDescription ?? "No result"])) ?? Data()
                }
                if let folder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                    try? output.write(to: folder.appendingPathComponent(write ? "touhan-smoke-write.json" : "touhan-smoke-read.json"), options: .atomic)
                }
            }
 #endif
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
    @MainActor
    static func installSnapshot(in controller: WKUserContentController) {
        controller.removeAllUserScripts()
        let source = "if(location.protocol==='file:' && location.pathname.endsWith('/official-practice.html')) window.__touhanStudyState = " + load() + ";"
        controller.addUserScript(WKUserScript(source: source, injectionTime: .atDocumentStart, forMainFrameOnly: true))
    }
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
