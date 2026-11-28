import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var store: LearningStore
    private let regions = ["Canada", "Australia", "United Kingdom", "United States", "India"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("ENGLISH LISTENING")
                        .font(.caption.weight(.bold))
                        .tracking(1.5)
                        .foregroundStyle(SprintTheme.accent)

                    Text("聞き分けるほど、英語が現実の音になる。")
                        .font(.title2.weight(.bold))

                    Text("同じ英文を5つの地域の音で聞き比べる、短時間リスニング。")
                        .foregroundStyle(SprintTheme.muted)

                    if let first = store.lessons.first {
                        Button {
                            store.requestAccess(to: first)
                        } label: {
                            VStack(alignment: .leading, spacing: 9) {
                                Text("TODAY'S SPRINT")
                                    .font(.caption2.weight(.bold))
                                    .tracking(1)
                                    .foregroundStyle(SprintTheme.accent)

                                Text(first.title)
                                    .font(.title3.weight(.bold))
                                    .foregroundStyle(.white)

                                Text("\(first.region) ・ \(first.level) ・ 約3分")
                                    .font(.subheadline)
                                    .foregroundStyle(SprintTheme.muted)

                                Label("今日のレッスンを始める", systemImage: "play.fill")
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(SprintTheme.background)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(
                                        SprintTheme.accent,
                                        in: RoundedRectangle(cornerRadius: 14)
                                    )
                            }
                            .padding(20)
                            .background(SprintTheme.panel, in: RoundedRectangle(cornerRadius: 24))
                        }
                        .buttonStyle(.plain)
                    }

                    Text("地域から選ぶ")
                        .font(.headline)
                        .padding(.top, 6)

                    LazyVGrid(
                        columns: [GridItem(.flexible()), GridItem(.flexible())],
                        spacing: 10
                    ) {
                        ForEach(regions, id: \.self) { region in
                            let count = store.lessons.filter { $0.region == region }.count

                            NavigationLink {
                                RegionLessonsView(region: region)
                            } label: {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(region)
                                        .font(.subheadline.weight(.bold))
                                        .foregroundStyle(.white)

                                    Text("\(count) lessons")
                                        .font(.caption)
                                        .foregroundStyle(SprintTheme.muted)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(14)
                                .background(SprintTheme.panel, in: RoundedRectangle(cornerRadius: 16))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(16)
            }
            .background(SprintTheme.background)
            .navigationTitle("Listening Sprint")
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
}

private struct RegionLessonsView: View {
    @EnvironmentObject private var store: LearningStore
    let region: String

    private var lessons: [Lesson] {
        store.lessons.filter { $0.region == region }
    }

    var body: some View {
        List {
            ForEach(lessons) { lesson in
                Button {
                    store.requestAccess(to: lesson)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(lesson.title)
                                .foregroundStyle(.white)

                            Text("\(lesson.region) ・ \(lesson.topic)")
                                .font(.caption)
                                .foregroundStyle(SprintTheme.muted)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 5) {
                            if !store.canAccess(lesson) {
                                Label("PREMIUM", systemImage: "lock.fill")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(SprintTheme.accent)
                            }
                            Image(
                                systemName: store.completedLessonIDs.contains(lesson.id)
                                    ? "checkmark.circle.fill"
                                    : "play.circle.fill"
                            )
                            .foregroundStyle(SprintTheme.accent)
                            Text("\(store.completedLessonCounts[lesson.id, default: 0])回")
                                .font(.caption2)
                                .foregroundStyle(SprintTheme.muted)
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(SprintTheme.background)
        .navigationTitle(region)
    }
}
