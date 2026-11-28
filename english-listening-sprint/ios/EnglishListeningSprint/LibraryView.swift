import SwiftUI

struct LibraryView: View {
    @EnvironmentObject private var store: LearningStore
    @State private var region = "All"

    private var filtered: [Lesson] {
        region == "All"
            ? store.lessons
            : store.lessons.filter { $0.region == region }
    }

    private var themeCount: Int {
        Set(store.lessons.map { $0.id.filter(\.isNumber) }).count
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("地域", selection: $region) {
                        Text("All").tag("All")
                        ForEach(
                            ["Canada", "Australia", "United Kingdom", "United States", "India"],
                            id: \.self
                        ) { regionName in
                            Text(regionName).tag(regionName)
                        }
                    }
                    .pickerStyle(.menu)
                }

                ForEach(filtered) { lesson in
                    Button {
                        store.requestAccess(to: lesson)
                    } label: {
                        HStack {
                            VStack(alignment: .leading) {
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
            .navigationTitle("\(themeCount) Lessons")
        }
    }
}
