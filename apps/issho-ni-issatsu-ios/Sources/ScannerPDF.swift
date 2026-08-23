import SwiftUI
import VisionKit
import PDFKit
import UIKit

struct ScannedBookShelfView: View {
    @EnvironmentObject private var store: PDFBookStore
    @State private var gate = false
    @State private var scanner = false
    @State private var pending: VNDocumentCameraScan?

    var body: some View {
        Group {
            if store.books.isEmpty {
                ContentUnavailableView("保存した絵本はありません", systemImage: "doc.viewfinder", description: Text("所有する絵本をスキャンし、端末内PDFとして保存できます。"))
            } else {
                List {
                    ForEach(store.books) { book in
                        NavigationLink {
                            LandscapePDFReaderScreen(title: book.title, url: store.pdfURL(for: book))
                        } label: {
                            Label {
                                VStack(alignment: .leading) {
                                    Text(book.title).font(.headline)
                                    Text("\(book.pageCount)ページ").font(.caption).foregroundStyle(.secondary)
                                }
                            } icon: { Image(systemName: "book.closed.fill") }
                        }
                    }
                    .onDelete(perform: store.deleteBooks)
                }
            }
        }
        .toolbar { Button { gate = true } label: { Label("スキャン", systemImage: "doc.viewfinder") } }
        .sheet(isPresented: $gate) {
            ParentGateView {
                gate = false
                scanner = true
            }.presentationDetents([.medium])
        }
        .fullScreenCover(isPresented: $scanner) {
            DocumentScannerView(
                onCancel: { scanner = false },
                onComplete: { pending = $0; scanner = false },
                onFailure: { _ in scanner = false }
            ).ignoresSafeArea()
        }
        .sheet(isPresented: Binding(get: { pending != nil }, set: { if !$0 { pending = nil } })) {
            if let pending { ScanSaveView(scan: pending) { self.pending = nil }.environmentObject(store) }
        }
    }
}

struct ParentGateView: View {
    let success: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var answer = ""
    var body: some View {
        NavigationStack {
            Form {
                Text("スキャン画像はOCRを使わず、PDFとしてこの端末だけに保存します。")
                Section("保護者確認") {
                    Text("3 ＋ 4 は？").font(.title2.bold())
                    TextField("答え", text: $answer).keyboardType(.numberPad)
                }
            }
            .navigationTitle("絵本をスキャン")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("やめる") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("つづける") { success() }.disabled(answer != "7") }
            }
        }
    }
}

struct ScanSaveView: View {
    let scan: VNDocumentCameraScan
    let finished: () -> Void
    @EnvironmentObject private var store: PDFBookStore
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var saving = false
    var body: some View {
        NavigationStack {
            Form {
                TextField("絵本の名前", text: $title)
                LabeledContent("ページ数", value: "\(scan.pageCount)")
                Label("文字認識は行いません", systemImage: "text.magnifyingglass")
                Label("補正済み画像をPDFへまとめます", systemImage: "doc.richtext")
                Label("共有・外部送信なし", systemImage: "lock")
            }
            .navigationTitle("PDFとして保存")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("やめる") { dismiss(); finished() }.disabled(saving) }
                ToolbarItem(placement: .confirmationAction) {
                    Button(saving ? "保存中…" : "保存") {
                        saving = true
                        do { try store.save(scan: scan, title: title); dismiss(); finished() }
                        catch { saving = false }
                    }.disabled(saving || title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

struct DocumentScannerView: UIViewControllerRepresentable {
    let onCancel: () -> Void
    let onComplete: (VNDocumentCameraScan) -> Void
    let onFailure: (Error) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }
    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}
    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let parent: DocumentScannerView
        init(_ parent: DocumentScannerView) { self.parent = parent }
        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) { parent.onCancel() }
        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) { parent.onComplete(scan) }
        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) { parent.onFailure(error) }
    }
}

@MainActor
final class PDFBookStore: ObservableObject {
    @Published private(set) var books: [ScannedBook] = []
    private let fm = FileManager.default
    private let root: URL
    private let index: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init() {
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? fm.temporaryDirectory
        root = base.appendingPathComponent("ScannedBooks", isDirectory: true)
        index = root.appendingPathComponent("index.json")
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
        try? fm.createDirectory(at: root, withIntermediateDirectories: true)
        if let data = try? Data(contentsOf: index), let decoded = try? decoder.decode([ScannedBook].self, from: data) { books = decoded }
    }

    func save(scan: VNDocumentCameraScan, title: String) throws {
        let images = (0..<scan.pageCount).map(scan.imageOfPage(at:))
        let id = UUID()
        let fileName = "\(id.uuidString).pdf"
        let data = PDFBuilder.makePDF(images)
        try data.write(to: root.appendingPathComponent(fileName), options: .atomic)
        books.insert(ScannedBook(id: id, title: title, fileName: fileName, pageCount: scan.pageCount, createdAt: Date()), at: 0)
        try encoder.encode(books).write(to: index, options: .atomic)
    }
    func pdfURL(for book: ScannedBook) -> URL { root.appendingPathComponent(book.fileName) }
    func deleteBooks(at offsets: IndexSet) {
        offsets.map { books[$0] }.forEach { try? fm.removeItem(at: pdfURL(for: $0)) }
        books.remove(atOffsets: offsets)
        try? encoder.encode(books).write(to: index, options: .atomic)
    }
}

enum PDFBuilder {
    static func makePDF(_ images: [UIImage]) -> Data {
        UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 100, height: 100)).pdfData { context in
            for original in images {
                let image = original.downsampled(maxDimension: 2400)
                let ratio = image.size.width / image.size.height
                let size = ratio >= 1 ? CGSize(width: 1200, height: 1200 / ratio) : CGSize(width: 1200 * ratio, height: 1200)
                let bounds = CGRect(origin: .zero, size: size)
                context.beginPage(withBounds: bounds, pageInfo: [:])
                image.draw(in: bounds)
            }
        }
    }
}

private extension UIImage {
    func downsampled(maxDimension: CGFloat) -> UIImage {
        let maxSide = max(size.width, size.height)
        guard maxSide > maxDimension else { return normalized() }
        let scale = maxDimension / maxSide
        let target = CGSize(width: floor(size.width * scale), height: floor(size.height * scale))
        let format = UIGraphicsImageRendererFormat(); format.scale = 1; format.opaque = true
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in normalized().draw(in: CGRect(origin: .zero, size: target)) }
    }
    func normalized() -> UIImage {
        guard imageOrientation != .up else { return self }
        let format = UIGraphicsImageRendererFormat(); format.scale = 1; format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in draw(in: CGRect(origin: .zero, size: size)) }
    }
}

struct LandscapePDFReaderScreen: View {
    let title: String
    let url: URL
    @Environment(\.dismiss) private var dismiss
    @State private var page = ""
    var body: some View {
        ZStack(alignment: .top) {
            Color.black.ignoresSafeArea()
            PDFKitReader(url: url, page: $page).ignoresSafeArea()
            HStack {
                Button { dismiss() } label: { Image(systemName: "xmark").frame(width: 44, height: 44).background(.black.opacity(0.65), in: Circle()) }
                Text(title).font(.headline).lineLimit(1)
                Spacer()
                Text(page).font(.footnote.monospacedDigit())
            }.foregroundStyle(.white).padding()
        }
        .toolbar(.hidden, for: .navigationBar)
        .statusBarHidden()
        .onAppear { OrientationManager.request(.landscape) }
        .onDisappear { OrientationManager.request(.portrait) }
    }
}

struct PDFKitReader: UIViewRepresentable {
    let url: URL
    @Binding var page: String
    func makeCoordinator() -> Coordinator { Coordinator(page: $page) }
    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.backgroundColor = .black
        view.autoScales = true
        view.displayMode = .singlePage
        view.displayDirection = .horizontal
        view.usePageViewController(true, withViewOptions: [UIPageViewController.OptionsKey.interPageSpacing: 12])
        view.document = PDFDocument(url: url)
        NotificationCenter.default.addObserver(context.coordinator, selector: #selector(Coordinator.changed(_:)), name: Notification.Name.PDFViewPageChanged, object: view)
        context.coordinator.update(view)
        return view
    }
    func updateUIView(_ uiView: PDFView, context: Context) { context.coordinator.update(uiView) }
    static func dismantleUIView(_ uiView: PDFView, coordinator: Coordinator) { NotificationCenter.default.removeObserver(coordinator) }
    final class Coordinator: NSObject {
        @Binding var page: String
        init(page: Binding<String>) { _page = page }
        @objc func changed(_ note: Notification) { if let view = note.object as? PDFView { update(view) } }
        func update(_ view: PDFView) {
            guard let document = view.document, let current = view.currentPage else { page = ""; return }
            page = "\(document.index(for: current) + 1) / \(document.pageCount)"
        }
    }
}

enum OrientationManager {
    static func request(_ mask: UIInterfaceOrientationMask) {
        guard let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first else { return }
        scene.requestGeometryUpdate(UIWindowScene.GeometryPreferences.iOS(interfaceOrientations: mask)) { _ in }
        scene.windows.first(where: \.isKeyWindow)?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
    }
}
