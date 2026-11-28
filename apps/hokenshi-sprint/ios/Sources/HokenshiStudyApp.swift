import SwiftUI

@main
@MainActor
struct HokenshiStudyApp: App {
    @StateObject private var store = QuestionStore.shared
    @StateObject private var premium = PremiumStore()
    @StateObject private var records = StudyRecordStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            HomeView()
                .preferredColorScheme(.light)
                .environmentObject(store)
                .environmentObject(premium)
                .environmentObject(records)
                .task {
                    await premium.refresh()
                }
                .onChange(of: scenePhase) { phase in
                    if phase == .active { Task { await premium.refreshEntitlements() } }
                }
        }
    }
}

/// アプリ共通の色。ダークモードでも崩れないよう固定色を使う（シリーズの教訓）。
enum Palette {
    static let paper = Color(red: 245 / 255, green: 248 / 255, blue: 247 / 255)
    static let card = Color.white
    static let teal = Color(red: 13 / 255, green: 110 / 255, blue: 104 / 255)
    static let tealSoft = Color(red: 13 / 255, green: 110 / 255, blue: 104 / 255).opacity(0.10)
    static let navy = Color(red: 30 / 255, green: 58 / 255, blue: 74 / 255)
    static let line = Color(red: 222 / 255, green: 230 / 255, blue: 228 / 255)
    static let ink = Color(red: 31 / 255, green: 41 / 255, blue: 55 / 255)
    static let sub = Color(red: 91 / 255, green: 105 / 255, blue: 112 / 255)
    static let accent = Color(red: 217 / 255, green: 119 / 255, blue: 6 / 255)
    static let good = Color(red: 22 / 255, green: 128 / 255, blue: 57 / 255)
    static let bad = Color(red: 185 / 255, green: 28 / 255, blue: 28 / 255)
    static let primary = Color(red: 13 / 255, green: 110 / 255, blue: 104 / 255)
}

struct PrimaryButtonStyle: ButtonStyle {
    let background: Color
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(background.opacity(configuration.isPressed ? 0.82 : 1),
                        in: RoundedRectangle(cornerRadius: 14))
    }
}
