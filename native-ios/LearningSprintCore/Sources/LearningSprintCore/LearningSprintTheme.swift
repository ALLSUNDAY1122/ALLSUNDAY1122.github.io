import SwiftUI

public enum LearningSprintTheme {
    public static let paper = Color(hex: 0xF7F3EA)
    public static let paperLine = Color(hex: 0xE3DCCD)
    public static let card = Color(hex: 0xFFFDF9)
    public static let ink = Color(hex: 0x1C2331)
    public static let ink2 = Color(hex: 0x4A5468)
    public static let ink3 = Color(hex: 0x8B8577)
    public static let indigo = Color(hex: 0x2F4A6D)
    public static let indigoSoft = Color(hex: 0xEAEFF6)
    public static let vermilion = Color(hex: 0xD8452C)
    public static let vermilionSoft = Color(hex: 0xFDEEEA)
    public static let green = Color(hex: 0x2F7D5C)
    public static let greenSoft = Color(hex: 0xEAF6F0)
    public static let gold = Color(hex: 0xB5872B)
    public static let line = Color(hex: 0xECE4D6)

    public static func serif(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .custom("Hiragino Mincho ProN", size: size, relativeTo: textStyle(for: size)).weight(weight)
    }

    public static func sans(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(textStyle(for: size), design: .default, weight: weight)
    }

    private static func textStyle(for size: CGFloat) -> Font.TextStyle {
        switch size {
        case 0..<12: return .caption2
        case 12..<14: return .caption
        case 14..<17: return .body
        case 17..<22: return .title3
        case 22..<28: return .title2
        default: return .title
        }
    }
}

public struct LearningSprintPaperBackground: View {
    public init() {}

    public var body: some View {
        ZStack(alignment: .top) {
            LearningSprintTheme.paper
                .ignoresSafeArea()
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
                context.stroke(path, with: .color(LearningSprintTheme.paperLine.opacity(0.42)), lineWidth: 0.7)
            }
            .frame(height: 420)
            .mask(
                LinearGradient(
                    colors: [.black, .black.opacity(0)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .allowsHitTesting(false)
        }
    }
}

public struct LearningSprintProgressRing: View {
    let progress: Double
    let label: String

    public init(progress: Double, label: String) {
        self.progress = min(1, max(0, progress))
        self.label = label
    }

    public var body: some View {
        ZStack {
            Circle()
                .stroke(LearningSprintTheme.line, lineWidth: 8)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    LearningSprintTheme.indigo,
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            Text(label)
                .font(LearningSprintTheme.sans(13, weight: .bold))
                .foregroundStyle(LearningSprintTheme.ink)
                .minimumScaleFactor(0.75)
        }
        .frame(width: 82, height: 82)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("今日の学習進捗")
        .accessibilityValue(label)
    }
}

public struct LearningSprintMemoryBlock: View {
    let text: String

    public init(_ text: String) {
        self.text = text
    }

    public var body: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(LearningSprintTheme.gold)
                .frame(width: 4)
            VStack(alignment: .leading, spacing: 6) {
                Text("ここだけ覚える")
                    .font(LearningSprintTheme.sans(12, weight: .bold))
                    .foregroundStyle(LearningSprintTheme.gold)
                Text(text)
                    .font(LearningSprintTheme.serif(17, weight: .semibold))
                    .foregroundStyle(LearningSprintTheme.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
        }
        .background(Color(hex: 0xFFF7DA))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

public struct LearningSprintHeatmap: View {
    let values: [Date: Int]
    let calendar: Calendar
    let endDate: Date

    public init(values: [Date: Int], calendar: Calendar = .current, endDate: Date = Date()) {
        self.values = values
        self.calendar = calendar
        self.endDate = endDate
    }

    public var body: some View {
        let days = makeDays()
        LazyHGrid(rows: Array(repeating: GridItem(.fixed(14), spacing: 4), count: 7), spacing: 4) {
            ForEach(days, id: \.self) { day in
                let count = values[calendar.startOfDay(for: day), default: 0]
                RoundedRectangle(cornerRadius: 3)
                    .fill(fill(for: count))
                    .frame(width: 14, height: 14)
                    .accessibilityLabel(accessibilityLabel(day: day, count: count))
            }
        }
        .frame(height: 7 * 14 + 6 * 4)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("直近5週間の学習記録")
    }

    private func makeDays() -> [Date] {
        let end = calendar.startOfDay(for: endDate)
        guard let start = calendar.date(byAdding: .day, value: -34, to: end) else { return [] }
        return (0..<35).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    private func fill(for count: Int) -> Color {
        switch count {
        case 0: return LearningSprintTheme.line
        case 1...3: return LearningSprintTheme.vermilion.opacity(0.28)
        case 4...7: return LearningSprintTheme.vermilion.opacity(0.55)
        default: return LearningSprintTheme.vermilion
        }
    }

    private func accessibilityLabel(day: Date, count: Int) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M月d日"
        return "\(formatter.string(from: day))、\(count)問"
    }
}

public extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}
