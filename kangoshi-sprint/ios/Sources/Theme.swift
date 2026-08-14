import SwiftUI

extension Color {
    init(hex: String) {
        let value = UInt64(hex.replacingOccurrences(of: "#", with: ""), radix: 16) ?? 0
        self.init(.sRGB, red: Double((value >> 16) & 0xff) / 255, green: Double((value >> 8) & 0xff) / 255, blue: Double(value & 0xff) / 255, opacity: 1)
    }
}

enum KSTheme {
    static let paper = Color(hex: "F7F3EA")
    static let card = Color(hex: "FFFDF9")
    static let ink = Color(hex: "1C2331")
    static let secondary = Color(hex: "4A5468")
    static let tertiary = Color(hex: "8B8577")
    static let ai = Color(hex: "2F4A6D")
    static let aiSoft = Color(hex: "EAEFF6")
    static let shu = Color(hex: "D8452C")
    static let shuSoft = Color(hex: "FDEEEA")
    static let green = Color(hex: "2F7D5C")
    static let greenSoft = Color(hex: "EAF6F0")
    static let gold = Color(hex: "B5872B")
    static let line = Color(hex: "ECE4D6")
}

struct KSCard<Content: View>: View {
    let content: Content
    init(content: Content) { self.content = content }
    var body: some View {
        content.padding(16).frame(maxWidth: .infinity, alignment: .leading)
            .background(KSTheme.card).overlay(RoundedRectangle(cornerRadius: 16).stroke(KSTheme.line))
            .clipShape(RoundedRectangle(cornerRadius: 16)).shadow(color: .black.opacity(0.04), radius: 8, y: 3)
    }
}

struct PageHeader: View {
    let eyebrow: String, title: String, tagline: String
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 7) { Capsule().fill(KSTheme.shu).frame(width: 16,height: 2); Text(eyebrow).font(.caption2.bold()).tracking(2).foregroundStyle(KSTheme.tertiary) }
            Text(title).font(.system(size: 29, weight: .bold, design: .serif)).foregroundStyle(KSTheme.ink)
            Text(tagline).font(.footnote).foregroundStyle(KSTheme.secondary)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal,18).padding(.top,14)
    }
}

struct PremiumBadge: View {
    var body: some View { Text("PREMIUM").font(.system(size:9,weight:.heavy)).tracking(1).padding(.horizontal,7).padding(.vertical,4).background(KSTheme.gold.opacity(.14)).foregroundStyle(KSTheme.gold).clipShape(Capsule()) }
}
