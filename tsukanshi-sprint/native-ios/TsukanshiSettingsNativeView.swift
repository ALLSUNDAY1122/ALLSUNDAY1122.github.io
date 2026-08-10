import SwiftUI
import UniformTypeIdentifiers
import LearningSprintCore

struct TsukanshiSettingsNativeView: View {
    @ObservedObject var model: TsukanshiAppModel
    @ObservedObject private var purchase: PurchaseController
    let showPaywall: () -> Void
    @State private var exporting = false
    @State private var importing = false
    @State private var exportDocument = TsukanshiJSONBackupDocument()

    init(model: TsukanshiAppModel, showPaywall: @escaping () -> Void) {
        self.model = model
        self.purchase = model.purchaseController
        self.showPaywall = showPaywall
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LearningSprintPaperBackground()
                Form {
                    learningSection
                    premiumSection
                    backupSection
                    auditSection
                }
                .scrollContentBackground(.hidden)
                .frame(maxWidth: 520)
            }
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.inline)
        }
        .fileExporter(
            isPresented: $exporting,
            document: exportDocument,
            contentType: .json,
            defaultFilename: "tsukanshi-learning-backup"
        ) { result in
            if case .failure(let error) = result {
                model.transientMessage = "書き出せません: \(error.localizedDescription)"
            }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
            switch result {
            case .success(let url): importJSON(from: url)
            case .failure(let error): model.transientMessage = "読み込めません: \(error.localizedDescription)"
            }
        }
    }

    private var learningSection: some View {
        Section("学習") {
            Picker("1回の問題数", selection: Binding(
                get: { model.state.dailyTarget },
                set: model.setDailyTarget
            )) {
                Text("4問").tag(4)
                Text("8問").tag(8)
                Text("16問").tag(16)
            }
            .pickerStyle(.segmented)
            .accessibilityLabel("1回の問題数")

            Picker("文字サイズ", selection: Binding(
                get: { model.state.textSizeStep },
                set: model.setTextSizeStep
            )) {
                Text("小").tag(0)
                Text("標準").tag(1)
                Text("大").tag(2)
            }
            .pickerStyle(.segmented)
            .accessibilityLabel("文字サイズ")

            if let date = model.state.examDate {
                DatePicker("試験日", selection: Binding(
                    get: { date },
                    set: { model.setExamDate($0) }
                ), displayedComponents: .date)
            }
        }
    }

    private var premiumSection: some View {
        Section("プレミアム") {
            HStack {
                Text(purchase.isPremium ? "プレミアム解放済み" : "無料版")
                Spacer()
                if let price = purchase.displayPrice, !purchase.isPremium {
                    Text(price).fontWeight(.bold)
                }
            }
            if !purchase.isPremium {
                Button("プレミアムを確認") { showPaywall() }
            }
            Button("購入を復元") {
                Task { await purchase.restore() }
            }
        }
    }

    private var backupSection: some View {
        Section("バックアップ") {
            Button("JSONを書き出す") {
                do {
                    exportDocument = TsukanshiJSONBackupDocument(data: try model.backupData())
                    exporting = true
                } catch {
                    model.transientMessage = "書き出せません: \(error.localizedDescription)"
                }
            }
            Button("JSONから復元") { importing = true }
            Text("学習履歴・苦手・設定・完答回数を保存します。別資格のJSONは読み込みません。")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var auditSection: some View {
        Section("教材監査") {
            if let bank = model.content?.bank {
                LabeledContent("contentVersion", value: bank.contentVersion)
                LabeledContent("lawBaselineDate", value: bank.lawBaselineDate)
                LabeledContent("学習問題", value: "\(bank.studyQuestionCount)")
                LabeledContent("申告書", value: "\(bank.declarationCount)")
                LabeledContent("構造化メタデータ警告", value: "\(bank.auditWarnings.count)")
                if !bank.auditWarnings.isEmpty {
                    Text("警告は推測で補完せず監査記録として保持します。TestFlight前のRelease Gateで再確認します。")
                        .font(.footnote)
                        .foregroundStyle(LearningSprintTheme.vermilion)
                }
            }
        }
    }

    private func importJSON(from url: URL) {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        do { model.importBackup(try Data(contentsOf: url)) }
        catch { model.transientMessage = "読み込めません: \(error.localizedDescription)" }
    }
}

struct TsukanshiPaywallNativeView: View {
    @ObservedObject var purchase: PurchaseController
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                Text("通関士 プレミアム")
                    .font(LearningSprintTheme.serif(30, weight: .bold))
                Text("計算問題の全範囲と申告書演習を買い切りで解放します。")
                    .font(LearningSprintTheme.sans(14))
                    .foregroundStyle(LearningSprintTheme.ink2)
                LearningSprintMemoryBlock("価格はApp Storeから取得した正式価格だけを表示します。")
                Spacer()
                purchaseAction
                Button("購入を復元") { Task { await purchase.restore() } }
                    .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: 520)
            .padding(20)
            .background(LearningSprintTheme.paper)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("閉じる") { dismiss() } }
            }
        }
    }

    @ViewBuilder private var purchaseAction: some View {
        if purchase.isPremium {
            Label("購入済み", systemImage: "checkmark.seal.fill")
                .foregroundStyle(LearningSprintTheme.green)
                .font(LearningSprintTheme.sans(17, weight: .bold))
        } else if let price = purchase.displayPrice {
            Button {
                Task { await purchase.purchase() }
            } label: {
                Text("\(price)で解放")
                    .font(LearningSprintTheme.sans(17, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(LearningSprintTheme.indigo)
            .disabled(purchase.state == .purchasing)
            .accessibilityLabel("\(price)でプレミアムを解放")
        } else {
            Text("価格を取得できません")
                .font(LearningSprintTheme.sans(15, weight: .bold))
                .foregroundStyle(LearningSprintTheme.vermilion)
        }
    }
}

struct TsukanshiJSONBackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data = Data("{}".utf8)

    init() {}
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
