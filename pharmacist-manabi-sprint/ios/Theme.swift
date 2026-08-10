import SwiftUI

extension Color {
    static let sprintPaper = Color(red: 247/255, green: 243/255, blue: 234/255)
    static let sprintPaperLine = Color(red: 227/255, green: 220/255, blue: 205/255)
    static let sprintCard = Color(red: 255/255, green: 253/255, blue: 249/255)
    static let sprintInk = Color(red: 28/255, green: 35/255, blue: 49/255)
    static let sprintInk2 = Color(red: 74/255, green: 84/255, blue: 104/255)
    static let sprintInk3 = Color(red: 139/255, green: 133/255, blue: 119/255)
    static let sprintAi = Color(red: 47/255, green: 74/255, blue: 109/255)
    static let sprintAiSoft = Color(red: 234/255, green: 239/255, blue: 246/255)
    static let sprintShu = Color(red: 216/255, green: 69/255, blue: 44/255)
    static let sprintShuSoft = Color(red: 253/255, green: 238/255, blue: 234/255)
    static let sprintMidori = Color(red: 47/255, green: 125/255, blue: 92/255)
    static let sprintMidoriSoft = Color(red: 234/255, green: 246/255, blue: 240/255)
    static let sprintKin = Color(red: 181/255, green: 135/255, blue: 43/255)
    static let sprintLine = Color(red: 236/255, green: 228/255, blue: 214/255)
}

struct PaperBackground: View {
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                Color.sprintPaper
                Canvas { context, size in
                    let step: CGFloat = 28
                    var path = Path()
                    var x: CGFloat = 0
                    while x <= size.width {
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: min(size.height, 420)))
                        x += step
                    }
                    var y: CGFloat = 0
                    while y <= min(size.height, 420) {
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: size.width, y: y))
                        y += step
                    }
                    context.stroke(path, with: .color(.sprintPaperLine.opacity(0.45)), lineWidth: 0.7)
                }
                .frame(height: min(geo.size.height, 420))
                .mask(LinearGradient(colors: [.black, .black.opacity(0)], startPoint: .top, endPoint: .bottom))
            }
            .ignoresSafeArea()
        }
    }
}

struct SprintCard<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View {
        content
            .padding(18)
            .background(Color.sprintCard)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.sprintLine, lineWidth: 1))
            .shadow(color: Color.black.opacity(0.05), radius: 12, x: 0, y: 5)
    }
}

struct ScreenTitle: View {
    let brand: String
    let title: String
    let tagline: String
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(brand)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color.sprintShu)
                .textCase(.uppercase)
            Text(title)
                .font(.system(size: 34, weight: .semibold, design: .serif))
                .foregroundStyle(Color.sprintInk)
            Text(tagline)
                .font(.system(size: 16))
                .foregroundStyle(Color.sprintInk2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ProgressRing<Center: View>: View {
    let progress: Double
    let center: Center
    init(progress: Double, @ViewBuilder center: () -> Center) {
        self.progress = progress
        self.center = center()
    }
    var body: some View {
        ZStack {
            Circle().stroke(Color.sprintLine.opacity(0.9), lineWidth: 8)
            Circle()
                .trim(from: 0, to: max(0, min(1, progress)))
                .stroke(Color.sprintShu, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.3), value: progress)
            center
        }
        .frame(width: 82, height: 82)
    }
}

struct BottomNav: View {
    @Binding var selected: MainTab
    var body: some View {
        HStack(spacing: 5) {
            ForEach(MainTab.allCases) { tab in
                Button {
                    selected = tab
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.symbol)
                            .font(.system(size: 20, weight: .semibold))
                        Text(tab.rawValue)
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundStyle(selected == tab ? Color.sprintAi : Color.sprintInk3)
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .background(selected == tab ? Color.sprintAiSoft : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.rawValue)
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 7)
        .padding(.bottom, 4)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) { Rectangle().fill(Color.sprintLine).frame(height: 1) }
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity, minHeight: 58)
            .background(LinearGradient(colors: [Color(red: 53/255, green: 82/255, blue: 122/255), Color(red: 35/255, green: 58/255, blue: 88/255)], startPoint: .topLeading, endPoint: .bottomTrailing))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .opacity(configuration.isPressed ? 0.84 : 1)
    }
}

struct FieldProgressBar: View {
    let progress: Double
    let color: Color
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.sprintLine)
                Capsule().fill(color).frame(width: max(0, geo.size.width * min(1, max(0, progress))))
            }
        }
        .frame(height: 7)
    }
}

extension View {
    func sprintScreenMargins() -> some View { self.padding(.horizontal, 18) }
}
