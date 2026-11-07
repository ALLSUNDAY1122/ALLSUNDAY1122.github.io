import SwiftUI
import UIKit
import PhotosUI
import UniformTypeIdentifiers
import TedoriLogCore
import TedoriLogVision

/// 画面A｜入力。PDFを第一導線にし、写真は撮影ガイドつきで補助にする。
struct InputView: View {
    @ObservedObject var state: ImportFlowState
    @State private var showPDFImporter = false
    @State private var photoItem: PhotosPickerItem?
    @State private var showCamera = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("給与明細を取り込む")
                    .font(.title2).bold()
                Text("解析はすべてこの端末の中で行います。明細の画像・PDF・読み取り結果を外部へ送信しません。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(10)
                    .background(Color.green.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))

                pickerCard(
                    title: "PDFを選ぶ",
                    subtitle: "いちばん正確で速い方法です。給与明細サイトからダウンロードしたPDFがあればこちら。",
                    systemImage: "doc.text"
                ) { showPDFImporter = true }

                PhotosPicker(selection: $photoItem, matching: .images) {
                    cardBody(title: "スクリーンショットを選ぶ",
                             subtitle: "給与明細の画面を撮ったスクリーンショット。",
                             systemImage: "photo.on.rectangle")
                }
                .buttonStyle(.plain)

                pickerCard(
                    title: "紙の明細を撮影する",
                    subtitle: "明るい場所で、明細全体が入るように真上から撮ってください。",
                    systemImage: "camera"
                ) { showCamera = true }

                if let quality = state.qualityMessage {
                    Label(quality, systemImage: "exclamationmark.triangle")
                        .font(.callout)
                        .foregroundStyle(.orange)
                }
                if let error = state.errorMessage {
                    Label(error, systemImage: "xmark.octagon")
                        .font(.callout)
                        .foregroundStyle(.red)
                }
                if state.isAnalyzing {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("解析しています…")
                    }
                }
            }
            .padding()
        }
        .navigationTitle("手取りログ 入力試作")
        .navigationBarTitleDisplayMode(.inline)
        .fileImporter(isPresented: $showPDFImporter, allowedContentTypes: [UTType.pdf]) { result in
            switch result {
            case .success(let url): analyzePDF(url)
            case .failure(let error): state.fail("PDFを開けませんでした: \(error.localizedDescription)")
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraCaptureView { image in
                showCamera = false
                if let image { analyzeImage(image) }
            }
        }
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data)?.cgImage {
                    analyzeImage(image)
                } else {
                    state.fail("画像を読み込めませんでした")
                }
            }
        }
    }

    private func pickerCard(title: String, subtitle: String, systemImage: String,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            cardBody(title: title, subtitle: subtitle, systemImage: systemImage)
        }
        .buttonStyle(.plain)
    }

    private func cardBody(title: String, subtitle: String, systemImage: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage).font(.title2).frame(width: 32)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private func analyzePDF(_ url: URL) {
        state.beginTiming()
        state.isAnalyzing = true
        Task.detached(priority: .userInitiated) {
            let needsScope = url.startAccessingSecurityScopedResource()
            defer { if needsScope { url.stopAccessingSecurityScopedResource() } }
            do {
                let imported = try PayslipImporter.importPDF(url: url)
                await MainActor.run {
                    state.isAnalyzing = false
                    state.handle(imported)
                }
            } catch {
                await MainActor.run { state.fail("解析に失敗しました: \(error.localizedDescription)") }
            }
        }
    }

    private func analyzeImage(_ image: CGImage) {
        state.beginTiming()
        state.isAnalyzing = true
        Task.detached(priority: .userInitiated) {
            do {
                let imported = try PayslipImporter.importImage(image)
                await MainActor.run {
                    state.isAnalyzing = false
                    state.handle(imported)
                }
            } catch {
                await MainActor.run { state.fail("解析に失敗しました: \(error.localizedDescription)") }
            }
        }
    }
}

/// 撮影ガイド（枠と注意書き）つきのカメラ。
struct CameraCaptureView: UIViewControllerRepresentable {
    let onCapture: (CGImage?) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
        picker.delegate = context.coordinator
        if picker.sourceType == .camera {
            picker.cameraOverlayView = Self.makeOverlay(frame: UIScreen.main.bounds)
        }
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onCapture: onCapture) }

    private static func makeOverlay(frame: CGRect) -> UIView {
        let overlay = UIView(frame: frame)
        overlay.isUserInteractionEnabled = false
        overlay.backgroundColor = .clear

        let guideRect = frame.insetBy(dx: frame.width * 0.06, dy: frame.height * 0.18)
        let guide = UIView(frame: guideRect)
        guide.layer.borderColor = UIColor.systemYellow.cgColor
        guide.layer.borderWidth = 2
        guide.layer.cornerRadius = 10
        overlay.addSubview(guide)

        let label = UILabel(frame: CGRect(x: 16, y: guideRect.minY - 56, width: frame.width - 32, height: 44))
        label.numberOfLines = 2
        label.textAlignment = .center
        label.textColor = .white
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.text = "明細全体が枠に入るように、真上から明るい場所で撮ってください"
        overlay.addSubview(label)
        return overlay
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onCapture: (CGImage?) -> Void
        init(onCapture: @escaping (CGImage?) -> Void) { self.onCapture = onCapture }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            let image = (info[.originalImage] as? UIImage)?.cgImage
            onCapture(image)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onCapture(nil)
        }
    }
}
