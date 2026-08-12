import SwiftUI
import KanteishiCore

struct KanteishiShortAnswerRootView: View {
    enum Tab: String, CaseIterable {
        case home = "ホーム"
        case mock = "模試"
        case history = "記録"
        case settings = "設定"
    }

    @State private var selection: Tab = .home

    var body: some View {
        TabView(selection: $selection) {
            HomeView()
                .tag(Tab.home)
                .tabItem { Label(Tab.home.rawValue, systemImage: "house") }
            PlaceholderPage(title: "模擬試験", subtitle: "年度・科目構成は問題監査完了後に確定")
                .tag(Tab.mock)
                .tabItem { Label(Tab.mock.rawValue, systemImage: "doc.text") }
            PlaceholderPage(title: "学習記録", subtitle: "達成度・分野別・5週間ヒートマップ・苦手一覧")
                .tag(Tab.history)
                .tabItem { Label(Tab.history.rawValue, systemImage: "chart.bar") }
            PlaceholderPage(title: "設定", subtitle: "文字サイズ・試験日・JSONバックアップ・購入復元")
                .tag(Tab.settings)
                .tabItem { Label(Tab.settings.rawValue, systemImage: "gearshape") }
        }
        .tint(Theme.ai)
        .preferredColorScheme(.light)
    }
}

private struct HomeView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("学びスプリント")
                    .font(.caption.bold())
                    .foregroundStyle(Theme.ai)
                Text("不動産鑑定士試験・短答式")
                    .font(.system(size: 27, weight: .bold, design: .serif))
                    .foregroundStyle(Theme.ink)
                Text("今日も1問、力に変える。")
                    .font(.system(size: 17, design: .serif))
                    .foregroundStyle(Theme.ink2)

                SignatureCard()

                PrimaryAction(title: "今日のスプリント", detail: "8問", systemImage: "bolt.fill")
                SecondaryAction(title: "苦手をつぶす", detail: "3連続正解で苦手解除", systemImage: "arrow.triangle.2.circlepath")
                SecondaryAction(title: "模擬試験", detail: "行政法規＋鑑定理論", systemImage: "doc.text")

                Text("分野から解く")
                    .font(.headline)
                    .foregroundStyle(Theme.ink)
                SubjectCard(title: ExamSubject.administrativeLaw.rawValue)
                SubjectCard(title: ExamSubject.valuationTheory.rawValue)
            }
            .frame(maxWidth: 520, alignment: .leading)
            .padding(18)
        }
        .background(GridPaper())
    }
}

private struct SignatureCard: View {
    var body: some View {
        HStack(spacing: 18) {
            ZStack {
                Circle().stroke(Theme.line, lineWidth: 9)
                Circle()
                    .trim(from: 0, to: 0)
                    .stroke(Theme.shu, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                Text("0/8")
                    .font(.system(size: 17, weight: .bold, design: .serif))
                    .foregroundStyle(Theme.ink)
            }
            .frame(width: 82, height: 82)
            VStack(alignment: .leading, spacing: 4) {
                Text("今日の学習")
                    .font(.headline)
                    .foregroundStyle(Theme.ink)
                Text("標準スプリントは8問")
                    .font(.subheadline)
                    .foregroundStyle(Theme.ink2)
            }
            Spacer()
        }
        .padding(18)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.line))
    }
}

private struct PrimaryAction: View {
    let title: String
    let detail: String
    let systemImage: String

    var body: some View {
        Label {
            HStack {
                Text(title).fontWeight(.bold)
                Spacer()
                Text(detail).font(.caption)
            }
        } icon: {
            Image(systemName: systemImage)
        }
        .foregroundStyle(.white)
        .padding(16)
        .background(Theme.ai, in: RoundedRectangle(cornerRadius: 16))
    }
}

private struct SecondaryAction: View {
    let title: String
    let detail: String
    let systemImage: String

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).fontWeight(.bold)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(Theme.ink2)
            }
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(Theme.ai)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.line))
    }
}

private struct SubjectCard: View {
    let title: String

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Image(systemName: "chevron.right")
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(Theme.ink)
        .padding(16)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.line))
    }
}

private struct PlaceholderPage: View {
    let title: String
    let subtitle: String

    var body: some View {
        ZStack {
            Theme.paper.ignoresSafeArea()
            VStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 26, weight: .bold, design: .serif))
                    .foregroundStyle(Theme.ink)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(Theme.ink2)
                    .multilineTextAlignment(.center)
            }
            .padding(24)
        }
    }
}

private struct GridPaper: View {
    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Theme.paper))
            let step: CGFloat = 28
            var path = Path()
            stride(from: CGFloat.zero, through: size.width, by: step).forEach { x in
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: min(size.height, 420)))
            }
            stride(from: CGFloat.zero, through: min(size.height, 420), by: step).forEach { y in
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
            }
            context.stroke(path, with: .color(Theme.paperLine.opacity(0.55)), lineWidth: 1)
        }
        .ignoresSafeArea()
    }
}

private enum Theme {
    static let paper = Color(red: 247.0 / 255.0, green: 243.0 / 255.0, blue: 234.0 / 255.0)
    static let paperLine = Color(red: 227.0 / 255.0, green: 220.0 / 255.0, blue: 205.0 / 255.0)
    static let card = Color(red: 255.0 / 255.0, green: 253.0 / 255.0, blue: 249.0 / 255.0)
    static let ink = Color(red: 28.0 / 255.0, green: 35.0 / 255.0, blue: 49.0 / 255.0)
    static let ink2 = Color(red: 74.0 / 255.0, green: 84.0 / 255.0, blue: 104.0 / 255.0)
    static let ink3 = Color(red: 139.0 / 255.0, green: 133.0 / 255.0, blue: 119.0 / 255.0)
    static let ai = Color(red: 47.0 / 255.0, green: 74.0 / 255.0, blue: 109.0 / 255.0)
    static let aiSoft = Color(red: 234.0 / 255.0, green: 239.0 / 255.0, blue: 246.0 / 255.0)
    static let shu = Color(red: 216.0 / 255.0, green: 69.0 / 255.0, blue: 44.0 / 255.0)
    static let shuSoft = Color(red: 253.0 / 255.0, green: 238.0 / 255.0, blue: 234.0 / 255.0)
    static let midori = Color(red: 47.0 / 255.0, green: 125.0 / 255.0, blue: 92.0 / 255.0)
    static let midoriSoft = Color(red: 234.0 / 255.0, green: 246.0 / 255.0, blue: 240.0 / 255.0)
    static let kin = Color(red: 181.0 / 255.0, green: 135.0 / 255.0, blue: 43.0 / 255.0)
    static let line = Color(red: 236.0 / 255.0, green: 228.0 / 255.0, blue: 214.0 / 255.0)
}
