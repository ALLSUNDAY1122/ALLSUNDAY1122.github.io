import SwiftUI

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xff) / 255,
            green: Double((hex >> 8) & 0xff) / 255,
            blue: Double(hex & 0xff) / 255,
            opacity: alpha
        )
    }
}

enum AppTheme {
    static let paper = Color(hex: 0xF7F3EA)
    static let paperLine = Color(hex: 0xE3DCCD)
    static let card = Color(hex: 0xFFFDF9)
    static let ink = Color(hex: 0x1C2331)
    static let ink2 = Color(hex: 0x4A5468)
    static let ink3 = Color(hex: 0x8B8577)
    static let ai = Color(hex: 0x2F4A6D)
    static let aiSoft = Color(hex: 0xEAEFF6)
    static let shu = Color(hex: 0xD8452C)
    static let shuSoft = Color(hex: 0xFDEEEA)
    static let midori = Color(hex: 0x2F7D5C)
    static let midoriSoft = Color(hex: 0xEAF6F0)
    static let kin = Color(hex: 0xB5872B)
    static let line = Color(hex: 0xECE4D6)
}

struct PaperGridBackground: View {
    var body: some View {
        GeometryReader { proxy in
            Canvas { context, size in
                var path = Path()
                let step: CGFloat = 28
                var x: CGFloat = 0
                while x <= size.width {
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: min(420, size.height)))
                    x += step
                }
                var y: CGFloat = 0
                while y <= min(420, size.height) {
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y))
                    y += step
                }
                context.stroke(path, with: .color(AppTheme.paperLine.opacity(0.65)), lineWidth: 0.6)
            }
            .mask(
                LinearGradient(
                    colors: [.black, .black.opacity(0)],
                    startPoint: .top,
                    endPoint: UnitPoint(x: 0.5, y: min(1, 420 / max(proxy.size.height, 1)))
                )
            )
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct AppCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(AppTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(AppTheme.line, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 10, y: 5)
    }
}

extension View {
    func appCard() -> some View { modifier(AppCardModifier()) }
}

struct ProgressRing: View {
    let progress: Double
    let value: String
    let caption: String
    var size: CGFloat = 82

    var body: some View {
        ZStack {
            Circle()
                .stroke(AppTheme.aiSoft, lineWidth: 8)
            Circle()
                .trim(from: 0, to: max(0, min(1, progress)))
                .stroke(AppTheme.ai, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text(value)
                    .appSerif(22, weight: .bold)
                    .foregroundStyle(AppTheme.ink)
                Text(caption)
                    .appSans(10, weight: .bold)
                    .foregroundStyle(AppTheme.ink3)
            }
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("進捗 \(value) \(caption)")
    }
}

struct BottomTabBar: View {
    @Binding var selection: MainTab

    var body: some View {
        HStack(spacing: 6) {
            ForEach(MainTab.allCases) { tab in
                Button {
                    selection = tab
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.systemImage)
                            .font(.system(size: 20, weight: .semibold))
                        Text(tab.title)
                            .appSans(11, weight: .bold)
                    }
                    .foregroundStyle(selection == tab ? AppTheme.ai : AppTheme.ink3)
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .background(selection == tab ? AppTheme.aiSoft : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("tab.\(tab.rawValue)")
                .accessibilityLabel(tab.title)
                .accessibilityAddTraits(selection == tab ? .isSelected : [])
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 7)
        .padding(.bottom, 5)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) { Divider().overlay(AppTheme.line) }
    }
}
