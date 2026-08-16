import SwiftUI

struct ScanLabVisibilityChangeView: View {
    @EnvironmentObject private var backend: ScanLabBackend
    @Environment(\.dismiss) private var dismiss
    let scan: ScanLabOwnerScan

    @StateObject private var locationPicker = ScanLabLocationPicker()
    @State private var visibility: ScanLabVisibility
    @State private var locationLabel = ""
    @State private var contentConfirmed = false
    @State private var publicPlaceConfirmed = false
    @State private var privacyConfirmed = false
    @State private var rightsConfirmed = false
    @State private var busy = false
    @State private var errorMessage: String?

    init(scan: ScanLabOwnerScan) {
        self.scan = scan
        _visibility = State(initialValue: ScanLabVisibility(rawValue: scan.visibility) ?? .private)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("現在") {
                    LabeledContent("公開範囲", value: ScanLabOwnerVisibilityPresentation.visibilityText(scan.visibility))
                    Text("3Dファイルを再アップロードせず、サーバー上の公開範囲だけを変更します。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("変更後") {
                    Picker("公開範囲", selection: $visibility) {
                        ForEach(ScanLabVisibility.allCases) { Text($0.title).tag($0) }
                    }
                    Text(visibility.explanation).font(.footnote).foregroundStyle(.secondary)
                    Text(changeExplanation).font(.footnote).foregroundStyle(.secondary)
                }

                if visibility != .private {
                    Section("共有前の確認") {
                        Toggle("性的・暴力的・嫌がらせ等の不適切な内容ではなく、共有に適した3Dです", isOn: $contentConfirmed)
                    }
                }

                if visibility == .public {
                    Section("マップ位置") {
                        Text("Publicへ変更するたびに、公開地点と確認事項を新しく指定します。以前の位置情報は自動再利用しません。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Button { locationPicker.requestCurrentLocation() } label: {
                            Label("現在地を公開地点に設定", systemImage: "location")
                        }
                        .disabled(locationPicker.isRequesting)
                        if locationPicker.isRequesting { ProgressView() }
                        Text(locationPicker.statusMessage).font(.caption).foregroundStyle(.secondary)
                        if locationPicker.location != nil {
                            TextField("場所名（任意）", text: $locationLabel)
                            Button("位置情報を外す", role: .destructive) { locationPicker.clear() }
                        }
                    }

                    Section("公開前の確認") {
                        Toggle("私有住宅や立入禁止区域ではなく、公開可能な場所です", isOn: $publicPlaceConfirmed)
                        Toggle("識別できる人物・住所・車両番号などの私的情報を含まない、または必要な許可があります", isOn: $privacyConfirmed)
                        Toggle("公開する3Dに必要な権利があります", isOn: $rightsConfirmed)
                    }
                }

                Section {
                    Button { Task { await submit() } } label: {
                        HStack {
                            if busy { ProgressView() }
                            Text(busy ? "変更中…" : actionTitle)
                        }
                    }
                    .disabled(busy || visibility.rawValue == scan.visibility || !canSubmit)
                    if let errorMessage { Text(errorMessage).foregroundStyle(.red).font(.footnote) }
                }
            }
            .navigationTitle("公開範囲を変更")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarLeading) { Button("閉じる") { dismiss() } } }
            .onChange(of: visibility) { _, newValue in
                if newValue != .public {
                    locationPicker.clear()
                    locationLabel = ""
                    publicPlaceConfirmed = false
                    privacyConfirmed = false
                    rightsConfirmed = false
                }
                if newValue == .private { contentConfirmed = false }
            }
        }
    }

    private var canSubmit: Bool {
        if visibility == .private { return true }
        guard contentConfirmed else { return false }
        if visibility == .public {
            return locationPicker.location != nil && publicPlaceConfirmed && privacyConfirmed && rightsConfirmed
        }
        return true
    }

    private var actionTitle: String {
        switch visibility {
        case .private: "非公開へ変更"
        case .unlisted: "限定リンクへ変更"
        case .public: "Map・Discoverへ公開"
        }
    }

    private var changeExplanation: String {
        switch visibility {
        case .private:
            "公開・限定リンクを停止します。Publicで保存していた位置情報もサーバーから削除します。"
        case .unlisted:
            "新しい限定リンクを発行します。以前の限定リンクは再利用できないように無効化します。位置情報は保持しません。"
        case .public:
            "IDベースの公開URLでMap・Discoverから閲覧可能になります。新しい位置情報と安全確認が必要です。"
        }
    }

    private func submit() async {
        busy = true
        errorMessage = nil
        defer { busy = false }

        let location: ScanLabLocation? = visibility == .public && locationPicker.location != nil
            ? ScanLabLocation(
                latitude: locationPicker.location!.coordinate.latitude,
                longitude: locationPicker.location!.coordinate.longitude,
                label: locationLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? nil
                    : locationLabel.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            : nil

        do {
            try await backend.changeVisibility(
                scan,
                to: visibility,
                location: location,
                contentConfirmed: contentConfirmed,
                publicPlaceConfirmed: publicPlaceConfirmed,
                privacyConfirmed: privacyConfirmed,
                rightsConfirmed: rightsConfirmed
            )
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
