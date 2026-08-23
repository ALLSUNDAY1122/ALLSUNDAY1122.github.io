import SwiftUI

enum Otsu4Theme {
    static let paper = Color(hex: 0xF7F3EA)
    static let paperLine = Color(hex: 0xE3DCCD)
    static let card = Color(hex: 0xFFFDF9)
    static let ink = Color(hex: 0x1C2331)
    static let ink2 = Color(hex: 0x4A5468)
    static let ink3 = Color(hex: 0x665F54)
    static let ai = Color(hex: 0x2F4A6D)
    static let aiSoft = Color(hex: 0xEAEFF6)
    static let shu = Color(hex: 0xD8452C)
    static let shuSoft = Color(hex: 0xFDEEEA)
    static let midori = Color(hex: 0x2F7D5C)
    static let midoriSoft = Color(hex: 0xEAF6F0)
    static let kin = Color(hex: 0xB5872B)
    static let line = Color(hex: 0xECE4D6)

    static func serif(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(textStyle(for: size), design: .serif, weight: weight)
    }

    static func sans(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(textStyle(for: size), design: .default, weight: weight)
    }

    private static func textStyle(for size: CGFloat) -> Font.TextStyle {
        switch size {
        case ..<12.5: return .caption2
        case ..<13.5: return .caption
        case ..<14.5: return .footnote
        case ..<15.5: return .subheadline
        case ..<16.5: return .callout
        case ..<18.5: return .body
        case ..<20.5: return .headline
        case ..<23.5: return .title3
        case ..<27.5: return .title2
        case ..<31.5: return .title
        default: return .largeTitle
        }
    }
}

struct Otsu4PaperBackground: View {
    var body: some View {
        ZStack(alignment: .top) {
            Otsu4Theme.paper.ignoresSafeArea()
            Canvas { context, size in
                let spacing: CGFloat = 28
                var path = Path()
                var x: CGFloat = 0
                while x <= size.width {
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: min(420, size.height)))
                    x += spacing
                }
                var y: CGFloat = 0
                while y <= min(420, size.height) {
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y))
                    y += spacing
                }
                context.stroke(path, with: .color(Otsu4Theme.paperLine.opacity(0.55)), lineWidth: 1)
            }
            .frame(height: 420)
            .mask(
                LinearGradient(
                    colors: [.black, .black.opacity(0.72), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .allowsHitTesting(false)
        }
    }
}

struct Otsu4Card<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(16)
            .background(Otsu4Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Otsu4Theme.line, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.05), radius: 12, y: 5)
    }
}

struct Otsu4ProgressRing: View {
    let value: Double
    let label: String

    var body: some View {
        ZStack {
            Circle()
                .stroke(Otsu4Theme.line, lineWidth: 8)
            Circle()
                .trim(from: 0, to: min(1, max(0, value)))
                .stroke(Otsu4Theme.shu, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.35), value: value)
            Text(label)
                .font(Otsu4Theme.sans(16, weight: .bold))
                .foregroundStyle(Otsu4Theme.ink)
                .minimumScaleFactor(0.72)
        }
        .frame(width: 82, height: 82)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("今日の進捗")
        .accessibilityValue(label)
    }
}

struct Otsu4MemoryBlock: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("ここだけ覚える")
                .font(Otsu4Theme.sans(12, weight: .bold))
                .foregroundStyle(Otsu4Theme.kin)
            Text(text)
                .font(Otsu4Theme.serif(18, weight: .semibold))
                .foregroundStyle(Otsu4Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(hex: 0xFFF6D8))
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(Otsu4Theme.kin)
                .frame(width: 4)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier("memoryBlock")
        .accessibilityLabel("ここだけ覚える")
        .accessibilityValue(text)
    }
}

struct Otsu4MarkOverlay: View {
    let correct: Bool
    @State private var appeared = false

    var body: some View {
        Text(correct ? "○" : "×")
            .font(.system(size: 106, weight: .medium, design: .serif))
            .foregroundStyle(Otsu4Theme.shu.opacity(0.86))
            .rotationEffect(.degrees(correct ? -8 : 5))
            .scaleEffect(appeared ? 1 : 1.8)
            .opacity(appeared ? 1 : 0)
            .onAppear {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.62)) {
                    appeared = true
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}
