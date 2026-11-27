import SwiftUI
import GoogleMobileAds

@main
@MainActor
struct KanjiStudyApp: App {
    @StateObject private var premium = PremiumStore()
    @StateObject private var records = StudyRecordStore()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // 子ども向け設定: child-directed treatment を有効化し、
        // 広告コンテンツのレーティング上限を G にする（パーソナライズなしは
        // リクエスト側でも npa=1 を付ける）。
        let config = GADMobileAds.sharedInstance().requestConfiguration
        config.tagForChildDirectedTreatment = true
        config.maxAdContentRating = GADAdContentRating.general
        GADMobileAds.sharedInstance().start(completionHandler: nil)
    }

    var body: some Scene {
        WindowGroup {
            HomeView()
                .preferredColorScheme(.light)
                .environmentObject(premium)
                .environmentObject(records)
                .task { await premium.refresh() }
                .onChange(of: scenePhase) { phase in
                    if phase == .active { Task { await premium.refreshEntitlements() } }
                }
        }
    }
}

/// アプリ共通の色。ダークモードでも崩れないよう、文字色には
/// システムの .primary / .secondary を使わず固定色を使う（ITパスポートの教訓）。
enum Palette {
    static let paper = Color(red: 247 / 255, green: 243 / 255, blue: 234 / 255)
    static let card = Color(red: 1.0, green: 253 / 255, blue: 249 / 255)
    static let navy = Color(red: 47 / 255, green: 74 / 255, blue: 109 / 255)
    static let line = Color(red: 232 / 255, green: 223 / 255, blue: 207 / 255)
    static let ink = Color(red: 31 / 255, green: 41 / 255, blue: 55 / 255)
    static let sub = Color(red: 91 / 255, green: 100 / 255, blue: 112 / 255)
    static let accent = Color(red: 217 / 255, green: 119 / 255, blue: 6 / 255)
    static let good = Color(red: 22 / 255, green: 128 / 255, blue: 57 / 255)
    static let bad = Color(red: 185 / 255, green: 28 / 255, blue: 28 / 255)
}

struct PrimaryButtonStyle: ButtonStyle {
    let background: Color
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(background.opacity(configuration.isPressed ? 0.82 : 1), in: RoundedRectangle(cornerRadius: 14))
    }
}
