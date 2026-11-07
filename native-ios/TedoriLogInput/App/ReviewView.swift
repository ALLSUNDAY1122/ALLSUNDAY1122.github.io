import SwiftUI
import UIKit
import TedoriLogCore

/// 画面B｜解析結果の確認と修正。
/// 原文のどこを読んだかを見ながら直せるようにする。確認しない限り保存はできない。
struct ReviewView: View {
    @ObservedObject var state: ImportFlowState

    var body: some View {
        VStack(spacing: 0) {
            if let result = state.result {
                summaryBar(result)
                List {
                    Section {
                        ForEach(ItemKey.allCases, id: \.self) { key in
                            if let item = result.items[key] {
                                ItemRow(state: state, item: item)
                            }
                        }
                    } header: {
                        Text("読み取り結果（保存前に確認してください）")
                    } footer: {
                        Text("確定候補＝合計との検算が合った候補です。数字はどれもそのまま保存されず、確認したものだけ保存されます。")
                    }

                    if !state.pageImages.isEmpty {
                        Section("原文の該当箇所") {
                            DocumentPreview(images: state.pageImages,
                                            highlight: state.focusedItem.flatMap { result.items[$0] })
                                .frame(height: 320)
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }

            if let error = state.errorMessage {
                Text(error).font(.callout).foregroundStyle(.red).padding(.horizontal)
            }

            HStack {
                Button("表示どおり全部確認") {
                    for key in ItemKey.allCases {
                        state.confirmations[key]?.confirmed = true
                    }
                }
                .buttonStyle(.bordered)
                Spacer()
                Button("確認した内容で保存") {
                    _ = state.save()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .navigationTitle("確認と修正")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("入力へ戻る") { state.restart() }
            }
        }
    }

    private func summaryBar(_ result: PayslipResult) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("経路: \(routeLabel(result.route))　確定候補 \(result.confidentCount) / 要確認 \(result.needsReviewCount) / 未検出 \(result.notFoundCount)")
                .font(.caption)
            Text(String(format: "解析 %.0fms（OCR %d回）", state.analyzeMs, state.ocrPasses))
                .font(.caption2).foregroundStyle(.secondary)
            if let quality = state.qualityMessage {
                Label(quality, systemImage: "camera.badge.ellipsis")
                    .font(.caption).foregroundStyle(.orange)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.secondarySystemBackground))
    }

    private func routeLabel(_ route: String) -> String {
        switch route {
        case "pdf_text": return "PDFの文字を直接読取"
        case "pdf_fallback_ocr": return "PDFに文字が無いためOCR"
        default: return "端末内OCR(Vision)"
        }
    }
}

private struct ItemRow: View {
    @ObservedObject var state: ImportFlowState
    let item: ItemCandidate
    @State private var text: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Button {
                    state.focusedItem = item.key
                } label: {
                    Text(item.label).font(.headline).underline()
                }
                .buttonStyle(.plain)
                StatusBadge(status: item.status)
                if item.corrected { Tag("桁誤りを補正") }
                if item.derived { Tag("合計から算出") }
                Spacer()
            }

            HStack {
                TextField("未入力", text: $text)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 160)
                    .onChange(of: text) { _, newValue in commit(newValue) }
                Button("未設定") {
                    text = ""
                    state.confirmations[item.key] = .init(value: nil, confirmed: true, edited: item.value != nil)
                }
                .buttonStyle(.bordered)
                Toggle("確認した", isOn: Binding(
                    get: { state.confirmations[item.key]?.confirmed ?? false },
                    set: { state.confirmations[item.key]?.confirmed = $0 }
                ))
                .labelsHidden()
                Text("確認").font(.caption)
            }

            if !item.alternatives.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(Array(item.alternatives.prefix(3).enumerated()), id: \.offset) { _, alt in
                            Button("別候補 \(alt.value.formatted())") {
                                text = String(alt.value)
                                state.confirmations[item.key] = .init(value: alt.value, confirmed: true, edited: true)
                                state.editCount += 1
                            }
                            .font(.caption)
                            .buttonStyle(.bordered)
                        }
                    }
                }
            }
            if !item.reasons.isEmpty {
                Text(item.reasons.joined(separator: " / "))
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .onAppear { text = item.value.map(String.init) ?? "" }
    }

    private func commit(_ newValue: String) {
        let digits = newValue.filter { $0.isNumber }
        let value = digits.isEmpty ? nil : Int(digits)
        let edited = value != item.value
        if edited {
            if item.value == nil { state.manualCount += 1 } else { state.editCount += 1 }
        }
        state.confirmations[item.key] = .init(value: value, confirmed: true, edited: edited)
    }
}

private struct StatusBadge: View {
    let status: CandidateStatus

    var body: some View {
        Text(label)
            .font(.caption2)
            .padding(.horizontal, 8).padding(.vertical, 2)
            .background(color.opacity(0.15), in: Capsule())
            .foregroundStyle(color)
    }

    private var label: String {
        switch status {
        case .confident: return "確定候補"
        case .needsReview: return "要確認"
        case .notFound: return "未検出"
        }
    }

    private var color: Color {
        switch status {
        case .confident: return .green
        case .needsReview: return .orange
        case .notFound: return .gray
        }
    }
}

private struct Tag: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text)
            .font(.caption2)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(Color.orange.opacity(0.15), in: Capsule())
            .foregroundStyle(.orange)
    }
}

private struct HighlightMark: Identifiable {
    let box: BoundingBox
    let isLabel: Bool
    var id: String { "\(box.page)-\(box.x)-\(box.y)-\(isLabel)" }
}

/// 原文画像と、読み取り位置のハイライト。
struct DocumentPreview: View {
    let images: [CGImage]
    let highlight: ItemCandidate?

    var body: some View {
        GeometryReader { geo in
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(Array(images.enumerated()), id: \.offset) { index, image in
                        ZStack(alignment: .topLeading) {
                            Image(decorative: image, scale: 1)
                                .resizable()
                                .scaledToFit()
                            if let highlight {
                                overlay(for: highlight, page: index + 1,
                                        displayWidth: geo.size.width,
                                        imageWidth: Double(image.width),
                                        imageHeight: Double(image.height))
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func overlay(for item: ItemCandidate, page: Int, displayWidth: Double,
                         imageWidth: Double, imageHeight: Double) -> some View {
        // トークン座標はポイント基準（幅595）。表示サイズへ合わせる。
        let pointWidth = 595.0
        let scale = displayWidth / pointWidth
        let pageHeight = 842.0
        let marks = item.evidence.flatMap { evidence -> [HighlightMark] in
            [HighlightMark(box: evidence.labelBox, isLabel: true),
             HighlightMark(box: evidence.amountBox, isLabel: false)]
        }.filter { $0.box.page == page || images.count == 1 }

        ForEach(marks) { mark in
            let offsetY = images.count == 1 ? 0 : Double(page - 1) * pageHeight
            Rectangle()
                .stroke(mark.isLabel ? Color.blue : Color.orange, lineWidth: 2)
                .background((mark.isLabel ? Color.blue : Color.orange).opacity(0.15))
                .frame(width: max(8, mark.box.w * scale), height: max(8, mark.box.h * scale))
                .offset(x: mark.box.x * scale, y: (mark.box.y - offsetY) * scale)
        }
    }
}
