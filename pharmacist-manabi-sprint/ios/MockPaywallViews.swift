import SwiftUI

struct MockView: View {
    @EnvironmentObject private var learning: LearningStore

    private let exams = [111, 110, 109]
    private let sections = ["必須", "理論", "実践"]

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ScreenTitle(brand: "模擬試験", title: "本番形式", tagline: "3回分を必須・理論・実践に分けて解けます。")
                    .padding(.top, 18)
                ForEach(exams, id: \.self) { exam in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("第\(exam)回")
                                .font(.system(size: 21, weight: .semibold, design: .serif))
                                .foregroundStyle(Color.sprintInk)
                            Spacer()
                            let done = sections.filter { learning.state.mock["\(exam)-\($0)"] != nil }.count
                            Text("完答 \(done)/3 区分")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Color.sprintInk3)
                        }
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible())], spacing: 10) {
                            ForEach(sections, id: \.self) { section in
                                mockCard(exam: exam, section: section)
                            }
                        }
                    }
                }
            }
            .sprintScreenMargins()
            .padding(.bottom, 18)
        }
        .scrollIndicators(.hidden)
        .accessibilityIdentifier("mockScreen")
    }

    private func mockCard(exam: Int, section: String) -> some View {
        let all = learning.activeQuestions.filter { $0.exam == exam && $0.section == section }
        let result = learning.state.mock["\(exam)-\(section)"]
        let rate = result.map { $0.total > 0 ? Double($0.score) / Double($0.total) : 0 }
        return Button {
            learning.startMock(exam: exam, section: section, premium: true)
        } label: {
            VStack(alignment: .leading, spacing: 9) {
                HStack {
                    ZStack {
                        Circle().stroke(Color.sprintLine, lineWidth: 5)
                        if let rate {
                            Circle()
                                .trim(from: 0, to: rate)
                                .stroke(rate >= 0.6 ? Color.sprintMidori : Color.sprintShu, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                        }
                        Text(rate.map { "\(Int(($0 * 100).rounded()))%" } ?? "—")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color.sprintInk)
                    }
                    .frame(width: 46, height: 46)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.sprintInk3)
                }
                Text(section)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.sprintInk)
                Text("\(all.count)問")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.sprintInk3)
                Text(result.map { "前回 \($0.score)/\($0.total)" } ?? "未受験")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(result == nil ? Color.sprintInk3 : ((rate ?? 0) >= 0.6 ? Color.sprintMidori : Color.sprintShu))
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 148, alignment: .leading)
            .background(Color.sprintCard)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.sprintLine))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("mock_\(exam)_\(section)")
    }
}
