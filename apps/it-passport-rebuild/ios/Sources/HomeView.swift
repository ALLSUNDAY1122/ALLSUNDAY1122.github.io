import SwiftUI

private struct StudyDomain: Identifiable, Hashable {
    let id: String
    let title: String
    let questionCount: Int
}

private struct QuestionSet: Identifiable, Hashable {
    let id: Int
    let start: Int
    let end: Int

    var title: String { "セット \(id)" }
    var subtitle: String { "問題 \(start)〜\(end)" }
}

struct HomeView: View {
    private let paper = Color(red: 247/255, green: 243/255, blue: 234/255)
    private let card = Color(red: 1.0, green: 253/255, blue: 249/255)
    private let navy = Color(red: 47/255, green: 74/255, blue: 109/255)
    private let line = Color(red: 232/255, green: 223/255, blue: 207/255)

    // Canonical question ingest is still in progress. These counts are deliberately
    // not hard-coded as production totals; the production store will replace them.
    private let domains = [
        StudyDomain(id: "strategy", title: "ストラテジ系", questionCount: 0),
        StudyDomain(id: "management", title: "マネジメント系", questionCount: 0),
        StudyDomain(id: "technology", title: "テクノロジ系", questionCount: 0)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    todayCard
                    Text("分野から解く")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    domainGrid
                    progressCard
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 32)
            }
            .background(paper.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
        }
        .tint(navy)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("学びスプリント")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            Text("ITパスポート")
                .font(.system(size: 31, weight: .bold, design: .serif))
                .minimumScaleFactor(0.8)
                .lineLimit(1)
            Text("今日も1問、力に変える。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var todayCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("今日の学習")
                .font(.system(size: 21, weight: .bold, design: .serif))
            Text("弱点と復習タイミングから、今日やる問題を自動で選びます。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button("今日のスプリントを始める") { }
                .buttonStyle(PrimaryButtonStyle(background: navy))
        }
        .padding(18)
        .background(card, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(line))
    }

    private var domainGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            ForEach(domains) { domain in
                NavigationLink(value: domain) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(domain.title)
                            .font(.system(size: 17, weight: .bold, design: .serif))
                            .foregroundStyle(.primary)
                        Text(domain.questionCount == 0 ? "問題データ接続準備中" : "\(domain.questionCount)問")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer(minLength: 0)
                        HStack {
                            Text("10問ずつ選ぶ")
                            Spacer()
                            Image(systemName: "chevron.right")
                        }
                        .font(.caption.bold())
                        .foregroundStyle(navy)
                    }
                    .padding(15)
                    .frame(maxWidth: .infinity, minHeight: 122, alignment: .leading)
                    .background(card, in: RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(line))
                }
                .buttonStyle(.plain)
                .gridCellColumns(domain.id == "technology" ? 2 : 1)
            }
        }
        .navigationDestination(for: StudyDomain.self) { domain in
            DomainSetView(domain: domain, paper: paper, card: card, navy: navy, line: line)
        }
    }

    private var progressCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("3分野の習熟度")
                .font(.headline)
            ForEach(domains) { domain in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(domain.title)
                        Spacer()
                        Text("0%")
                    }
                    .font(.subheadline.bold())
                    ProgressView(value: 0)
                        .tint(navy)
                }
            }
        }
        .padding(18)
        .background(card, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(line))
    }
}

private struct DomainSetView: View {
    let domain: StudyDomain
    let paper: Color
    let card: Color
    let navy: Color
    let line: Color

    private var sets: [QuestionSet] {
        guard domain.questionCount > 0 else { return [] }
        return stride(from: 0, to: domain.questionCount, by: 10).enumerated().map { offset, start in
            QuestionSet(id: offset + 1, start: start + 1, end: min(start + 10, domain.questionCount))
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(domain.title)
                    .font(.system(size: 28, weight: .bold, design: .serif))
                Text("10問ずつのセットから選択")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if sets.isEmpty {
                    ContentUnavailableView(
                        "問題データ接続準備中",
                        systemImage: "square.stack.3d.up",
                        description: Text("canonical問題バンク接続後、ここに10問単位のセットを自動表示します。")
                    )
                    .padding(.top, 28)
                } else {
                    ForEach(sets) { set in
                        Button { } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(set.title).font(.headline)
                                    Text(set.subtitle).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").foregroundStyle(navy)
                            }
                            .padding(16)
                            .background(card, in: RoundedRectangle(cornerRadius: 15))
                            .overlay(RoundedRectangle(cornerRadius: 15).stroke(line))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(18)
        }
        .background(paper.ignoresSafeArea())
        .navigationTitle(domain.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct PrimaryButtonStyle: ButtonStyle {
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
