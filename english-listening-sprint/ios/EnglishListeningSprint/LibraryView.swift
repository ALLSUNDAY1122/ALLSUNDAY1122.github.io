import SwiftUI

struct LibraryView: View {
    @EnvironmentObject private var store: LearningStore
    @State private var region = "All"

    private var filtered: [Lesson] {
        region == "All"
            ? store.lessons
            : store.lessons.filter { $0.region == region }
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
                        store.open(lesson)
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
            .navigationTitle("\(store.lessons.count) Lessons")
        }
    }
}
