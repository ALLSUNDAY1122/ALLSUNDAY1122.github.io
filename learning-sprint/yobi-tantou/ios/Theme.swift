import SwiftUI

enum SprintTheme {
    static let paper = Color(red: 247/255, green: 243/255, blue: 234/255)
    static let paperLine = Color(red: 227/255, green: 220/255, blue: 205/255)
    static let card = Color(red: 255/255, green: 253/255, blue: 249/255)
    static let ink = Color(red: 28/255, green: 35/255, blue: 49/255)
    static let ink2 = Color(red: 74/255, green: 84/255, blue: 104/255)
    static let ink3 = Color(red: 139/255, green: 133/255, blue: 119/255)
    static let indigo = Color(red: 47/255, green: 74/255, blue: 109/255)
    static let indigoSoft = Color(red: 234/255, green: 239/255, blue: 246/255)
    static let vermilion = Color(red: 216/255, green: 69/255, blue: 44/255)
    static let vermilionSoft = Color(red: 253/255, green: 238/255, blue: 234/255)
    static let green = Color(red: 47/255, green: 125/255, blue: 92/255)
    static let greenSoft = Color(red: 234/255, green: 246/255, blue: 240/255)
    static let gold = Color(red: 181/255, green: 135/255, blue: 43/255)
    static let line = Color(red: 236/255, green: 228/255, blue: 214/255)
    static let memory = Color(red: 255/255, green: 248/255, blue: 218/255)

    static func serif(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .custom("Hiragino Mincho ProN", size: size).weight(weight)
    }
}

struct PaperGridBackground: View {
    var body: some View {
        ZStack(alignment: .top) {
            SprintTheme.paper.ignoresSafeArea()
            Canvas { context, size in
                var path = Path()
                stride(from: 0.0, through: min(size.height, 420), by: 28).forEach { y in
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y))
                }
                stride(from: 0.0, through: size.width, by: 28).forEach { x in
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: min(size.height, 420)))
                }
                context.stroke(path, with: .color(SprintTheme.paperLine.opacity(0.5)), lineWidth: 0.7)
            }
            .frame(height: 420)
            .mask(LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom))
            .allowsHitTesting(false)
        }
    }
}

struct PaperCard<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View {
        content
            .padding(16)
            .background(SprintTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(SprintTheme.line, lineWidth: 1))
            .shadow(color: .black.opacity(0.04), radius: 12, y: 6)
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(SprintTheme.indigo.opacity(configuration.isPressed ? 0.8 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(SprintTheme.indigo)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(SprintTheme.card.opacity(configuration.isPressed ? 0.75 : 1))
            .overlay(RoundedRectangle(cornerRadius: 13).stroke(SprintTheme.line, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
    }
}
