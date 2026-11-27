import SwiftUI
import GoogleMobileAds

@main
@MainActor
struct KanjiStudyApp: App {
    @StateObject private var premium = PremiumStore()
    @StateObject private var records = StudyRecordStore()
    @StateObject private var bgm = BGMPlayer.shared
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // 子ども向け設定: child-directed treatment を有効化し、
        // 広告コンテンツのレーティング上限を G にする（パーソナライズなしは
        // リクエスト側でも npa=1 を付ける）。
        let config = GADMobileAds.sharedInstance().requestConfiguration
        config.tagForChildDirectedTreatment = true
        config.maxAdContentRating = GADMaxAdContentRating.general
        GADMobileAds.sharedInstance().start(completionHandler: nil)
    }

    var body: some Scene {
        WindowGroup {
            HomeView()
                .preferredColorScheme(.light)
                .environmentObject(premium)
                .environmentObject(records)
                .environmentObject(bgm)
                .task {
                    await premium.refresh()
                    bgm.startIfEnabled()
                }
                .onChange(of: scenePhase) { phase in
                    if phase == .active {
                        Task { await premium.refreshEntitlements() }
                        bgm.resumeIfEnabled()
                    }
                    if phase == .background {
                        bgm.pause()
                    }
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
    /// 主要ボタンの明るい青。
    static let primary = Color(red: 0.16, green: 0.52, blue: 0.85)

    /// 学年ごとのテーマカラー。範囲外は navy。
    static func gradeColor(_ grade: Int) -> Color {
        switch grade {
        case 1: return Color(red: 0.93, green: 0.36, blue: 0.24)
        case 2: return Color(red: 0.96, green: 0.62, blue: 0.14)
        case 3: return Color(red: 0.55, green: 0.76, blue: 0.29)
        case 4: return Color(red: 0.20, green: 0.70, blue: 0.45)
        case 5: return Color(red: 0.20, green: 0.60, blue: 0.90)
        case 6: return Color(red: 0.56, green: 0.45, blue: 0.85)
        default: return navy
        }
    }

    /// 学年カラーの淡い版（背景用）。
    static func gradeSoft(_ grade: Int) -> Color {
        gradeColor(grade).opacity(0.13)
    }
}

extension Font {
    /// 子ども向けの見出し用フォント（ヒラギノ丸ゴ）。
    static func maru(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .custom("Hiragino Maru Gothic ProN", size: size).weight(weight)
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    let background: Color
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.maru(17))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(background.opacity(configuration.isPressed ? 0.82 : 1), in: RoundedRectangle(cornerRadius: 16))
    }
}
