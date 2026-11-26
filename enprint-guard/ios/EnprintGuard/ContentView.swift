import SwiftUI
import PhotosUI
import UIKit

struct ContentView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("ホーム", systemImage: "house") }
            CalendarListView()
                .tabItem { Label("カレンダー", systemImage: "calendar") }
            TaskListView()
                .tabItem { Label("やること", systemImage: "checklist") }
            DocumentListView()
                .tabItem { Label("プリント", systemImage: "doc.text") }
        }
    }
}

struct HomeView: View {
    @EnvironmentObject private var store: AppStore
    @State private var showingCapture = false
    @State private var selectedTask: HouseholdTask?
    @State private var showingSettings = false

    private var overdueTasks: [HouseholdTask] {
        store.activeTasks.filter { task in
            guard let date = task.dueDate else { return false }
            return Calendar.current.startOfDay(for: date) < Calendar.current.startOfDay(for: Date())
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(Date.now.formatted(.dateTime.year().month().day().weekday(.wide)))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("今日のやること")
                            .font(.largeTitle.bold())
                    }

                    HStack(spacing: 12) {
                        SummaryCard(title: "確認待ち", value: store.reviewTasks.count, color: .orange)
                        SummaryCard(title: "期限超過", value: overdueTasks.count, color: .red)
                        SummaryCard(title: "対応中", value: store.activeTasks.count, color: .green)
                    }

                    Button {
                        showingCapture = true
                    } label: {
                        Label("プリントを撮影・読み込む", systemImage: "camera.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    }
                    .buttonStyle(.borderedProminent)

                    if !store.reviewTasks.isEmpty {
                        TaskSection(title: "読み取り内容を確認", subtitle: "承認するまで通知されません", tasks: store.reviewTasks) {
                            selectedTask = $0
                        }
                    }

                    if !overdueTasks.isEmpty {
                        TaskSection(title: "期限を過ぎています", subtitle: nil, tasks: overdueTasks) {
                            selectedTask = $0
                        }
                    }

                    TaskSection(title: "これからの予定", subtitle: nil, tasks: Array(store.activeTasks.prefix(8))) {
                        selectedTask = $0
                    }

                    if store.tasks.isEmpty {
                        ContentUnavailableView(
                            "タスクはまだありません",
                            systemImage: "checkmark.circle",
                            description: Text("園のプリントを撮影すると、確認が必要な項目を表示します。")
                        )
                        .padding(.top, 12)
                    }
                }
                .padding()
            }
            .navigationTitle("園プリント")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingSettings = true } label: { Image(systemName: "gearshape") }
                }
            }
            .sheet(isPresented: $showingCapture) { CaptureView() }
            .sheet(item: $selectedTask) { task in TaskReviewView(task: task) }
            .sheet(isPresented: $showingSettings) { SettingsView() }
        }
    }
}

struct SummaryCard: View {
    let title: String
    let value: Int
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text("\(value)").font(.title.bold()).foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }
}

struct TaskSection: View {
    let title: String
    let subtitle: String?
    let tasks: [HouseholdTask]
    let onSelect: (HouseholdTask) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                if let subtitle {
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
            }
            if tasks.isEmpty {
                Text("現在ありません").font(.subheadline).foregroundStyle(.tertiary)
            } else {
                ForEach(tasks) { task in
                    Button { onSelect(task) } label: {
                        TaskRow(task: task)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

struct TaskRow: View {
    let task: HouseholdTask

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: iconName)
                .foregroundStyle(task.state == .review ? .orange : .green)
                .frame(width: 22)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 4) {
                Text(task.title).font(.subheadline.weight(.medium)).foregroundStyle(.primary)
                HStack(spacing: 8) {
                    Text(task.category.title)
                    if let dueDate = task.dueDate {
                        Text(dueDate.formatted(date: .numeric, time: .omitted))
                    } else if let rawDate = task.rawDateText {
                        Text("日付要確認：\(rawDate)")
                    }
                    if let assignee = task.assignee, !assignee.isEmpty {
                        Text("担当：\(assignee)")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            if task.state == .review {
                Text("確認").font(.caption.bold()).foregroundStyle(.orange)
            } else {
                Text(task.state.title).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private var iconName: String {
        switch task.category {
        case .submission: return "doc.text"
        case .event: return "calendar"
        case .item: return "bag"
        case .purchase: return "cart"
        case .response: return "checkmark.message"
        }
    }
}

struct TaskReviewView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let task: HouseholdTask
    @State private var hasDate: Bool
    @State private var date: Date
    @State private var assignee: String

    init(task: HouseholdTask) {
        self.task = task
        _hasDate = State(initialValue: task.dueDate != nil || task.rawDateText != nil)
        _date = State(initialValue: task.dueDate ?? Date())
        _assignee = State(initialValue: task.assignee ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("抽出内容") {
                    Text(task.title)
                    LabeledContent("分類", value: task.category.title)
                    if let rawDate = task.rawDateText {
                        LabeledContent("原文の日付", value: rawDate)
                    }
                    if task.state == .review {
                        LabeledContent("抽出確信度", value: "\(Int(task.confidence * 100))%")
                    }
                }
                if !task.sourceExcerpt.isEmpty {
                    Section("原文の根拠") {
                        Text(task.sourceExcerpt).font(.body)
                    }
                }
                Section("期限・実施日") {
                    Toggle("日付を設定する", isOn: $hasDate)
                    if hasDate {
                        DatePicker("日付", selection: $date, displayedComponents: .date)
                    }
                    if task.rawDateText != nil && !hasDate {
                        Text("原文に日付があるため、日付を確認して設定してください。")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
                Section("担当者") {
                    TextField("例：父・母", text: $assignee)
                }
                if task.state != .review {
                    Section("タスク操作") {
                        Button("対応中にする") {
                            store.setState(.inProgress, for: task)
                            dismiss()
                        }
                        Button("完了にする") {
                            store.setState(.completed, for: task)
                            dismiss()
                        }
                        Button("確認済みにする") {
                            store.setState(.confirmed, for: task)
                            dismiss()
                        }
                        Button("タスクを削除", role: .destructive) {
                            store.deleteTask(task)
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(task.state == .review ? "読み取り確認" : "タスク詳細")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("戻る") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(task.state == .review ? "承認" : "保存") {
                        let assigned = assignee.isEmpty ? nil : assignee
                        if task.state == .review {
                            store.approve(task, dueDate: hasDate ? date : nil, assignee: assigned)
                        } else {
                            store.update(task, dueDate: hasDate ? date : nil, assignee: assigned)
                        }
                        dismiss()
                    }
                    .disabled(task.state == .review && task.rawDateText != nil && !hasDate)
                }
            }
        }
    }
}

struct CalendarListView: View {
    @EnvironmentObject private var store: AppStore
    private var datedTasks: [HouseholdTask] {
        store.tasks.filter { $0.dueDate != nil }.sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(datedTasks) { task in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(task.title).font(.subheadline.weight(.medium))
                        Text("\(task.category.title)・\(task.dueDate?.formatted(date: .long, time: .omitted) ?? "")")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("カレンダー")
            .overlay {
                if datedTasks.isEmpty {
                    ContentUnavailableView("予定はありません", systemImage: "calendar")
                }
            }
        }
    }
}

struct TaskListView: View {
    @EnvironmentObject private var store: AppStore
    @State private var selectedTask: HouseholdTask?

    var body: some View {
        NavigationStack {
            List {
                if !store.reviewTasks.isEmpty {
                    Section("確認待ち") {
                        ForEach(store.reviewTasks) { task in
                            Button { selectedTask = task } label: { TaskRow(task: task) }.buttonStyle(.plain)
                        }
                    }
                }
                Section("未完了") {
                    ForEach(store.activeTasks) { task in
                        Button { selectedTask = task } label: { TaskRow(task: task) }.buttonStyle(.plain)
                    }
                }
                Section("完了") {
                    ForEach(store.completedTasks) { task in
                        TaskRow(task: task)
                    }
                }
            }
            .navigationTitle("やること")
            .overlay {
                if store.tasks.isEmpty {
                    ContentUnavailableView("タスクはありません", systemImage: "checklist")
                }
            }
            .sheet(item: $selectedTask) { task in TaskReviewView(task: task) }
        }
    }
}

struct DocumentListView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        NavigationStack {
            List {
                ForEach(store.documents) { document in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(document.title).font(.subheadline.weight(.medium))
                        Text(document.createdAt.formatted(date: .numeric, time: .shortened))
                            .font(.caption).foregroundStyle(.secondary)
                        Text("関連タスク：\(store.tasks.filter { $0.sourceDocumentID == document.id }.count)件")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("プリント")
            .overlay {
                if store.documents.isEmpty {
                    ContentUnavailableView("プリントはありません", systemImage: "doc.text")
                }
            }
        }
    }
}

struct CaptureView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showingCamera = false
    @State private var isProcessing = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                Image(systemName: "doc.viewfinder").font(.system(size: 52)).foregroundStyle(.green)
                Text("園のプリントを追加").font(.title2.bold())
                Text("読み取り結果は確認待ちで登録され、承認するまで通知されません。")
                    .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    Label("写真から選ぶ", systemImage: "photo")
                        .frame(maxWidth: .infinity).padding()
                }
                .buttonStyle(.borderedProminent)
                Button {
                    showingCamera = true
                } label: {
                    Label("カメラで撮影", systemImage: "camera")
                        .frame(maxWidth: .infinity).padding()
                }
                .buttonStyle(.bordered)
                if isProcessing { ProgressView("文字を読み取っています…") }
                if let errorMessage {
                    Text(errorMessage).font(.caption).foregroundStyle(.red)
                }
                Spacer()
            }
            .padding(24)
            .navigationTitle("プリント追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
            .onChange(of: selectedPhoto) { _, item in
                guard let item else { return }
                Task {
                    guard let data = try? await item.loadTransferable(type: Data.self),
                          let image = UIImage(data: data) else {
                        errorMessage = "画像を読み込めませんでした。"
                        return
                    }
                    await process(image)
                }
            }
            .sheet(isPresented: $showingCamera) {
                CameraPicker { image in
                    Task { await process(image) }
                }
                .ignoresSafeArea()
            }
        }
    }

    @MainActor
    private func process(_ image: UIImage) async {
        isProcessing = true
        errorMessage = nil
        do {
            try await store.importImage(image)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        isProcessing = false
    }
}

struct CameraPicker: UIViewControllerRepresentable {
    var onImage: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: CameraPicker
        init(parent: CameraPicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onImage(image)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var subscriptions = SubscriptionStore()

    var body: some View {
        NavigationStack {
            List {
                Section("Premium") {
                    LabeledContent("状態", value: subscriptions.isPremium ? "利用中" : "無料")
                    ForEach(subscriptions.products, id: \.id) { product in
                        Button {
                            Task { await subscriptions.purchase(product) }
                        } label: {
                            HStack {
                                Text(product.id == SubscriptionStore.monthlyID ? "月額プラン" : "年額プラン")
                                Spacer()
                                Text(product.displayPrice)
                            }
                        }
                    }
                    Button("購入を復元") { Task { await subscriptions.restore() } }
                }
                Section("通知") {
                    Button("通知を許可する") {
                        Task { _ = await NotificationScheduler.shared.requestAuthorization() }
                    }
                }
                Section("データ・プライバシー") {
                    Text("プリント画像と読み取り結果は、この端末内に保存されます。AIクラウド処理・家族同期は接続前です。")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                if let message = subscriptions.message {
                    Section { Text(message).font(.footnote) }
                }
            }
            .navigationTitle("設定")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("閉じる") { dismiss() } }
            }
            .task { await subscriptions.load() }
        }
    }
}
