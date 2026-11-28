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

struct FigureView: View {
    let relativePath: String
    let symbol: String?
    var body: some View {
        if relativePath.lowercased().hasSuffix(".png") || relativePath.lowercased().hasSuffix(".jpg") {
            PNGFigureView(relativePath: relativePath)
        } else {
            SVGDiagramView(relativePath: relativePath, symbol: symbol)
        }
    }
}

struct PNGFigureView: View {
    let relativePath: String
    @State private var showZoom = false
    var body: some View {
        if let image = Self.loadImage(relativePath: relativePath) {
            Image(uiImage: image).resizable().scaledToFit()
                .onTapGesture { showZoom = true }
                .sheet(isPresented: $showZoom) {
                    NavigationStack {
                        ZoomableImageView(image: image).ignoresSafeArea(edges: .bottom)
                            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("閉じる") { showZoom = false } } }
                    }
                }
        } else {
            Text("図版を読み込めません。").font(.footnote).foregroundStyle(.secondary)
        }
    }
    static func loadImage(relativePath: String) -> UIImage? {
        let directory = (relativePath as NSString).deletingLastPathComponent
        let filename = (relativePath as NSString).lastPathComponent
        let stem = (filename as NSString).deletingPathExtension
        let subdirectory = directory.isEmpty ? "figures" : "figures/\(directory)"
        guard let url = Bundle.main.url(forResource: stem, withExtension: "png", subdirectory: subdirectory) else { return nil }
        return UIImage(contentsOfFile: url.path)
    }
}

struct ZoomableImageView: UIViewRepresentable {
    let image: UIImage
    func makeUIView(context: Context) -> UIScrollView {
        let scroll = UIScrollView()
        scroll.minimumZoomScale = 1.0
        scroll.maximumZoomScale = 5.0
        scroll.backgroundColor = .white
        let iv = UIImageView(image: image)
        iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(iv)
        NSLayoutConstraint.activate([
            iv.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
            iv.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
            iv.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            iv.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
            iv.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor),
            iv.heightAnchor.constraint(equalTo: scroll.frameLayoutGuide.heightAnchor)
        ])
        scroll.delegate = context.coordinator
        return scroll
    }
    func updateUIView(_ uiView: UIScrollView, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator() }
    final class Coordinator: NSObject, UIScrollViewDelegate {
        func viewForZooming(in scrollView: UIScrollView) -> UIView? { scrollView.subviews.first }
    }
}
