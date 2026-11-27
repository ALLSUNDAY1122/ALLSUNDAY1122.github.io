import SwiftUI
import WebKit

struct SVGDiagramView: UIViewRepresentable {
    let relativePath: String
    let symbol: String?

    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeUIView(context: Context) -> WKWebView {
        let view = WKWebView(frame: .zero)
        view.isOpaque = false
        view.backgroundColor = .clear
        view.scrollView.backgroundColor = .clear
        return view
    }
    func updateUIView(_ webView: WKWebView, context: Context) {
        let key = relativePath + "#" + (symbol ?? "")
        guard context.coordinator.loadedKey != key else { return }
        let directory = (relativePath as NSString).deletingLastPathComponent
        let filename = (relativePath as NSString).lastPathComponent
        let stem = (filename as NSString).deletingPathExtension
        let subdirectory = directory.isEmpty ? "figures" : "figures/\(directory)"
        guard let url = Bundle.main.url(forResource: stem, withExtension: "svg", subdirectory: subdirectory) else {
            webView.loadHTMLString("<html><body>図版を読み込めません。</body></html>", baseURL: nil); return
        }
        context.coordinator.loadedKey = key
        if let symbol, !symbol.isEmpty {
            let html = "<!doctype html><html><head><meta name=\"viewport\" content=\"width=device-width,initial-scale=1\"></head><body style=\"margin:0;background:transparent\"><svg xmlns=\"http://www.w3.org/2000/svg\" width=\"100%\" height=\"240\" viewBox=\"0 0 420 390\" preserveAspectRatio=\"xMidYMid meet\"><use href=\"\(filename)#\(symbol)\"></use></svg></body></html>"
            webView.loadHTMLString(html, baseURL: url.deletingLastPathComponent())
        } else { webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent()) }
    }
    final class Coordinator { var loadedKey: String? }
}
