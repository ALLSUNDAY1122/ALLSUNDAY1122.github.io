import SwiftUI

struct LessonView: View {
    @EnvironmentObject private var store: LearningStore
    var body: some View {
        guard let lesson = store.currentLesson else { return AnyView(EmptyView()) }
        return AnyView(NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack { Text(lesson.region.uppercased()).font(.caption.weight(.bold)).tracking(1).foregroundStyle(SprintTheme.accent); Spacer(); Text("\(lesson.level) ・ \(lesson.id.uppercased())").font(.caption).foregroundStyle(SprintTheme.muted) }
                    Text(lesson.title).font(.title2.weight(.bold))
                    Text(lesson.topic).foregroundStyle(SprintTheme.muted)
                    Waveform(isPlaying: store.isPlaying)
                    HStack(spacing: 24) {
                        Button { store.stop() } label: { Image(systemName: "backward.fill") }
                        Button { store.togglePlayback() } label: { Image(systemName: store.isPlaying ? "pause.fill" : "play.fill").font(.title).frame(width: 64, height: 64).background(SprintTheme.accent, in: Circle()).foregroundStyle(SprintTheme.background) }
                        Button { store.stop() } label: { Image(systemName: "forward.fill") }
                    }.frame(maxWidth: .infinity).font(.title3).buttonStyle(.plain)
                    HStack(spacing: 8) { ForEach([0.75, 1.0, 1.25], id: \.self) { speed in Button("\(speed, specifier: speed == 1 ? "%.0f" : "%.2f")x") { store.setRate(Float(speed)) }.buttonStyle(SprintPill(active: store.rate == Float(speed))) } }.frame(maxWidth: .infinity)
                    Picker("モード", selection: $store.mode) { ForEach(LearningMode.allCases) { Text($0.rawValue).tag($0) } }.pickerStyle(.segmented)
                    content(lesson).padding(18).background(SprintTheme.panel, in: RoundedRectangle(cornerRadius: 22))
                }.padding(16)
            }.background(SprintTheme.background).navigationTitle("Listening").toolbar { ToolbarItem(placement: .topBarLeading) { Button { store.stop(); store.selectedLessonID = nil } label: { Image(systemName: "chevron.left") } } }
        })
    }

    @ViewBuilder private func content(_ lesson: Lesson) -> some View {
        switch store.mode {
        case .translated:
            VStack(alignment: .leading, spacing: 12) {
                Text("訳ありリスニング").font(.caption.weight(.bold)).tracking(1).foregroundStyle(SprintTheme.accent)
                Text(lesson.ja).font(.body).lineSpacing(6)
                Divider().overlay(SprintTheme.muted.opacity(0.3))
                Text(lesson.en).font(.subheadline).foregroundStyle(SprintTheme.muted).lineSpacing(4)
            }
        case .quiz:
            QuizView()
        case .segments:
            VStack(alignment: .leading, spacing: 12) {
                Text("文節トレーニング").font(.caption.weight(.bold)).tracking(1).foregroundStyle(SprintTheme.accent)
                ForEach(Array(lesson.segments.enumerated()), id: \.offset) { _, segment in
                    VStack(alignment: .leading, spacing: 6) { Text(segment.en).font(.body.weight(.medium)); Text(segment.ja).font(.subheadline).foregroundStyle(SprintTheme.muted); Button("この文節を再生") { store.togglePlayback() }.font(.caption.weight(.bold)).buttonStyle(.bordered).tint(SprintTheme.panel2) }
                        .padding(13).background(SprintTheme.panel2.opacity(0.65), in: RoundedRectangle(cornerRadius: 15))
                }
            }
        }
    }
}

private struct QuizView: View {
    @EnvironmentObject private var store: LearningStore
    var body: some View {
        guard let question = store.question else { return AnyView(EmptyView()) }
        return AnyView(VStack(alignment: .leading, spacing: 14) {
            Text("LISTENING QUESTION").font(.caption.weight(.bold)).tracking(1).foregroundStyle(SprintTheme.accent)
            Text(question.q).font(.headline).lineSpacing(4)
            ForEach(question.choices.indices, id: \.self) { index in
                Button { store.answer(index) } label: {
                    HStack { Text(question.choices[index]); Spacer(); if store.selectedAnswer == index { Image(systemName: index == question.answer ? "checkmark.circle.fill" : "xmark.circle.fill") } }
                        .frame(maxWidth: .infinity, alignment: .leading).padding(14).background(choiceColor(index, question), in: RoundedRectangle(cornerRadius: 14))
                }.buttonStyle(.plain).disabled(store.selectedAnswer != nil)
            }
            if let answer = store.selectedAnswer {
                Text(answer == question.answer ? "正解！ \(question.explain)" : "もう一度確認しましょう。\(question.explain)").font(.subheadline).lineSpacing(4).padding(13).background(SprintTheme.panel2, in: RoundedRectangle(cornerRadius: 14))
                Button(store.selectedQuestion == (store.currentLesson?.questions.count ?? 1) - 1 ? "完了" : "次の問題") { store.nextQuestion() }.buttonStyle(.borderedProminent).tint(SprintTheme.accent).foregroundStyle(SprintTheme.background).frame(maxWidth: .infinity)
            }
        })
    }
    private func choiceColor(_ index: Int, _ question: Lesson.Question) -> Color {
        guard let selected = store.selectedAnswer else { return SprintTheme.panel2 }
        if index == question.answer { return Color.green.opacity(0.27) }
        return index == selected ? Color.red.opacity(0.24) : SprintTheme.panel2
    }
}

private struct Waveform: View {
    let isPlaying: Bool
    var body: some View { HStack(spacing: 5) { ForEach(0..<18, id: \.self) { i in Capsule().fill(SprintTheme.accent).frame(width: 5, height: isPlaying ? CGFloat(16 + (i * 13) % 38) : 13).animation(.easeInOut(duration: 0.45).repeatForever(autoreverses: true).delay(Double(i) * 0.03), value: isPlaying) } }.frame(maxWidth: .infinity, minHeight: 56) }
}

private struct SprintPill: ButtonStyle {
    let active: Bool
    func makeBody(configuration: Configuration) -> some View { configuration.label.font(.caption.weight(.bold)).padding(.horizontal, 12).padding(.vertical, 9).background(active ? SprintTheme.accent : SprintTheme.panel2, in: RoundedRectangle(cornerRadius: 12)).foregroundStyle(active ? SprintTheme.background : .white).opacity(configuration.isPressed ? 0.75 : 1) }
}
