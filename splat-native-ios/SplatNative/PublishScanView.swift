import CoreLocation
import SwiftUI
import UIKit

@MainActor
final class ScanLabLocationPicker: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published private(set) var location: CLLocation?
    @Published private(set) var statusMessage = "位置情報はまだ付与していません"
    @Published private(set) var isRequesting = false
    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func requestCurrentLocation() {
        location = nil; isRequesting = true
        switch manager.authorizationStatus {
        case .notDetermined: statusMessage = "位置情報の許可を確認しています"; manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse: statusMessage = "現在地を取得しています"; manager.requestLocation()
        case .denied, .restricted: isRequesting = false; statusMessage = "位置情報が許可されていません。設定から許可してください。"
        @unknown default: isRequesting = false; statusMessage = "位置情報を利用できません"
        }
    }
    func clear() { location = nil; isRequesting = false; statusMessage = "位置情報はまだ付与していません" }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let authorizationStatus = manager.authorizationStatus
        Task { @MainActor [weak self] in
            guard let self else { return }
            switch authorizationStatus {
            case .authorizedAlways, .authorizedWhenInUse: self.statusMessage = "現在地を取得しています"; self.manager.requestLocation()
            case .denied, .restricted: self.isRequesting = false; self.statusMessage = "位置情報が許可されていません。設定から許可してください。"
            case .notDetermined: break
            @unknown default: self.isRequesting = false; self.statusMessage = "位置情報を利用できません"
            }
        }
    }
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latest = locations.last else { return }
        Task { @MainActor [weak self] in self?.location = latest; self?.isRequesting = false; self?.statusMessage = "公開地点を取得しました（投稿するまで送信されません）" }
    }
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor [weak self] in self?.isRequesting = false; self?.statusMessage = "現在地を取得できませんでした: \(error.localizedDescription)" }
    }
}

struct PublishScanView: View {
    @EnvironmentObject var backend: ScanLabBackend
    @Environment(\.dismiss) private var dismiss
    let resultURL: URL
    let previewImage: UIImage?
    @StateObject private var locationPicker = ScanLabLocationPicker()
    @State private var title = ""
    @State private var caption = ""
    @State private var visibility: ScanLabVisibility = .unlisted
    @State private var locationLabel = ""
    @State private var publicPlaceConfirmed = false
    @State private var privacyConfirmed = false
    @State private var rightsConfirmed = false
    @State private var contentConfirmed = false
    @State private var busy = false
    @State private var errorMessage: String?
    @State private var published: ScanLabPublishResponse?

    var body: some View {
        NavigationStack {
            Group {
                if !backend.isAuthenticated {
                    VStack(spacing: 16) {
                        ContentUnavailableView("オンライン共有にはログインが必要です", systemImage: "person.crop.circle.badge.exclamationmark", description: Text("撮影と端末内3D生成はログインなしで使えます。"))
                        ScanLabAuthView()
                    }
                } else if let published { successView(published) } else { publishForm }
            }
            .navigationTitle("クラウド共有").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarLeading) { Button("閉じる") { dismiss() } } }
        }
    }

    private var publishForm: some View {
        Form {
            Section("投稿内容") { TextField("タイトル", text: $title); TextField("説明（任意）", text: $caption, axis: .vertical).lineLimit(2...5) }
            Section("公開範囲") {
                Picker("公開範囲", selection: $visibility) {
                    ForEach(ScanLabVisibility.allCases) { option in
                        Text(option == .public ? "公開（Discover）" : option.title).tag(option)
                    }
                }
                Text(
                    visibility == .public
                        ? "Discoverに公開します。Mapへ載せる場合だけ、位置情報を任意で追加できます。"
                        : visibility.explanation
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
            if visibility != .private {
                Section("コミュニティ安全確認") {
                    Toggle("性的・暴力的・嫌がらせ等の不適切な内容ではなく、共有に適した3Dです", isOn: $contentConfirmed)
                    Text("不適切な投稿はサーバー側の確認で拒否される場合があり、報告を受けた投稿は確認のため非表示になります。").font(.footnote).foregroundStyle(.secondary)
                }
            }
            if visibility == .public {
                Section("マップ位置（任意）") {
                    Text("位置情報は自動取得・自動送信しません。位置情報を付けなくてもDiscoverへ公開できます。Mapへ載せる場合だけ、下のボタンを押してください。").font(.footnote).foregroundStyle(.secondary)
                    Button {
                        publicPlaceConfirmed = false
                        locationPicker.requestCurrentLocation()
                    } label: {
                        Label("現在地を公開地点に設定", systemImage: "location")
                    }
                    .disabled(locationPicker.isRequesting)
                    if locationPicker.isRequesting { ProgressView() }
                    Text(locationPicker.statusMessage).font(.caption).foregroundStyle(.secondary)
                    if locationPicker.location != nil {
                        TextField("場所名（任意）", text: $locationLabel)
                        Toggle("この地点は私有住宅や立入禁止区域ではなく、公開可能な場所です", isOn: $publicPlaceConfirmed)
                        Button("位置情報を外す", role: .destructive) {
                            locationPicker.clear()
                            locationLabel = ""
                            publicPlaceConfirmed = false
                        }
                    }
                }
                Section("公開前の確認") {
                    Toggle("識別できる人物・住所・車両番号などの私的情報を含まない、または必要な許可があります", isOn: $privacyConfirmed)
                    Toggle("公開する3Dに必要な権利があります", isOn: $rightsConfirmed)
                }
            }
            Section {
                Button { Task { await submit() } } label: { HStack { if busy { ProgressView() }; Text(busy ? "アップロード中…" : actionTitle) } }
                    .disabled(busy || title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !canSubmit)
                if let errorMessage { Text(errorMessage).foregroundStyle(.red).font(.footnote) }
            } footer: { Text("このボタンを押すまで3Dファイル・位置情報はサーバーへ送信されません。") }
        }
        .onChange(of: visibility) { _, newValue in
            if newValue != .public { locationPicker.clear(); locationLabel = ""; publicPlaceConfirmed = false; privacyConfirmed = false; rightsConfirmed = false }
            if newValue == .private { contentConfirmed = false }
        }
    }

    private var canSubmit: Bool {
        if visibility == .private { return true }
        guard contentConfirmed else { return false }
        if visibility == .public {
            guard privacyConfirmed, rightsConfirmed else { return false }
            if locationPicker.location != nil { return publicPlaceConfirmed }
        }
        return true
    }
    private var actionTitle: String {
        switch visibility {
        case .private: "非公開でクラウド保存"
        case .unlisted: "限定リンクを作成"
        case .public: locationPicker.location == nil ? "Discoverへ公開" : "Map・Discoverへ公開"
        }
    }

    @ViewBuilder private func successView(_ response: ScanLabPublishResponse) -> some View {
        VStack(spacing: 18) {
            Spacer(); Image(systemName: "checkmark.circle.fill").font(.system(size: 66)).foregroundStyle(.mint)
            Text(successTitle(response)).font(.title2.bold())
            Text(successExplanation(response)).multilineTextAlignment(.center).foregroundStyle(.secondary)
            if let shareURL = response.shareUrl { ShareLink(item: shareURL) { Label("共有リンクを送る", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity) }.buttonStyle(PrimaryButtonStyle()) }
            Button("完了") { dismiss() }.buttonStyle(SecondaryButtonStyle()); Spacer()
        }.padding(24)
    }
    private func successTitle(_ r: ScanLabPublishResponse) -> String { switch r.visibility { case "public": "公開しました"; case "unlisted": "限定リンクを作成しました"; default: "クラウドへ保存しました" } }
    private func successExplanation(_ r: ScanLabPublishResponse) -> String {
        switch r.visibility {
        case "public":
            locationPicker.location == nil
                ? "Discoverから開けます。Mapには掲載していません。ブラウザ共有URLでも3Dを操作できます。"
                : "MapとDiscoverから開けます。ブラウザ共有URLでも3Dを操作できます。"
        case "unlisted": "MapやDiscoverには表示されません。専用URLを知る人だけが開けます。"
        default: "自分のアカウントからだけ確認できます。共有URLは発行しません。"
        }
    }

    private func submit() async {
        busy = true; errorMessage = nil; defer { busy = false }
        let location: ScanLabLocation? = visibility == .public && locationPicker.location != nil ? ScanLabLocation(latitude: locationPicker.location!.coordinate.latitude, longitude: locationPicker.location!.coordinate.longitude, label: locationLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : locationLabel.trimmingCharacters(in: .whitespacesAndNewlines)) : nil
        do { published = try await backend.publishTrustedPackage(resultURL: resultURL, previewImage: previewImage, title: title, caption: caption, visibility: visibility, location: location, publicPlaceConfirmed: publicPlaceConfirmed, privacyConfirmed: privacyConfirmed, rightsConfirmed: rightsConfirmed, contentConfirmed: contentConfirmed) }
        catch { errorMessage = error.localizedDescription }
    }
}
