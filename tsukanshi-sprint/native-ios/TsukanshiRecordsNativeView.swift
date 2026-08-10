import SwiftUI
import LearningSprintCore

struct TsukanshiRecordsNativeView: View {
    @ObservedObject var model: TsukanshiAppModel

    var body: some View {
        NavigationStack {
            ZStack {
                LearningSprintPaperBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        Text("記録")
                            .font(LearningSprintTheme.serif(32, weight: .bold))
                        overview
                        subjectBars
                        heatmap
                        weakList
                    }
                    .frame(maxWidth: 520, alignment: .leading)
                    .padding(18)
                    .padding(.bottom, 16)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var overview: some View {
        HStack(spacing: 12) {
            accuracyDonut
            VStack(alignment: .leading, spacing: 6) {
                Text("累計 \(model.state.attempts.count)回答")
                    .font(LearningSprintTheme.sans(14, weight: .bold))
                Text("苦手 \(model.weakCount)問")
                    .font(LearningSprintTheme.sans(13))
                Text("既出 \(model.uniqueAnsweredCount) / 480")
                    .font(LearningSprintTheme.sans(13))
            }
        }
        .padding(16)
        .background(LearningSprintTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var subjectBars: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("科目別正答率")
                .font(LearningSprintTheme.sans(15, weight: .bold))
            ForEach(TsukanshiNativeConfig.subjects, id: \.self) { subject in
                let value = model.subjectAccuracy[subject] ?? 0
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text(subject).font(LearningSprintTheme.sans(13, weight: .bold))
                        Spacer()
                        Text("\(Int((value * 100).rounded()))%")
                            .font(LearningSprintTheme.sans(12, weight: .bold))
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(LearningSprintTheme.line)
                            Capsule().fill(LearningSprintTheme.indigo).frame(width: geo.size.width * value)
                        }
                    }
                    .frame(height: 8)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(subject) 正答率 \(Int((value * 100).rounded()))パーセント")
            }
        }
        .padding(16)
        .background(LearningSprintTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var heatmap: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("直近5週間")
                .font(LearningSprintTheme.sans(15, weight: .bold))
            LearningSprintHeatmap(values: model.heatmap)
        }
        .padding(16)
        .background(LearningSprintTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var weakList: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("苦手リスト")
                .font(LearningSprintTheme.sans(15, weight: .bold))
            if model.state.weakQuestions.isEmpty {
                Text("現在、苦手登録はありません。")
                    .font(LearningSprintTheme.sans(13))
                    .foregroundStyle(LearningSprintTheme.ink2)
            } else {
                ForEach(model.state.weakQuestions.keys.sorted(), id: \.self) { id in
                    let question = model.content?.questions.first(where: { $0.id == id })
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(question?.topic ?? id)
                                .font(LearningSprintTheme.sans(13, weight: .bold))
                            Text("連続正解 \(model.state.weakQuestions[id]?.consecutiveCorrect ?? 0) / 3")
                                .font(LearningSprintTheme.sans(11))
                                .foregroundStyle(LearningSprintTheme.ink3)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 4)
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .padding(16)
        .background(LearningSprintTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var accuracyDonut: some View {
        let total = model.state.attempts.count
        let correct = model.state.attempts.filter(\.isCorrect).count
        let value = total == 0 ? 0 : Double(correct) / Double(total)
        return ZStack {
            Circle().stroke(LearningSprintTheme.line, lineWidth: 10)
            Circle()
                .trim(from: 0, to: value)
                .stroke(LearningSprintTheme.green, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(Int((value * 100).rounded()))%")
                .font(LearningSprintTheme.serif(20, weight: .bold))
        }
        .frame(width: 92, height: 92)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("累計正答率")
        .accessibilityValue("\(Int((value * 100).rounded()))パーセント")
    }
}
