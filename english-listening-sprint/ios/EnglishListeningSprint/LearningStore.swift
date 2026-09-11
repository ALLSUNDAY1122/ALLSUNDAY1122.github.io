import AVFoundation
import Foundation

struct Lesson: Codable, Identifiable, Hashable {
    struct Segment: Codable, Hashable { let en: String; let ja: String }
    struct Question: Codable, Hashable { let q: String; let choices: [String]; let answer: Int; let explain: String }
    let id: String
    let region: String
    let level: String
    let title: String
    let topic: String
    let en: String
    let ja: String
    let segments: [Segment]
    let questions: [Question]
}

enum LearningMode: String, CaseIterable, Identifiable {
    case translated = "訳あり"
    case quiz = "問題"
    case segments = "文節"
    var id: String { rawValue }
}

@MainActor
final class LearningStore: ObservableObject {
    @Published private(set) var lessons: [Lesson] = []
    @Published var selectedLessonID: String?
    @Published var mode: LearningMode = .translated
    @Published var selectedQuestion = 0
    @Published var selectedAnswer: Int?
    @Published var rate: Float = 1.0
    @Published var isPlaying = false
    @Published var showTranslation = true
    @Published var completedLessonIDs: Set<String> = []
    @Published var answerHistory: [String: Bool] = [:]

    private var player: AVAudioPlayer?

    init() {
        lessons = Self.loadLessons()
        completedLessonIDs = Set(UserDefaults.standard.stringArray(forKey: "completedLessonIDs") ?? [])
    }

    var currentLesson: Lesson? {
        guard let selectedLessonID else { return nil }
        return lessons.first { $0.id == selectedLessonID }
    }

    var question: Lesson.Question? {
        guard let lesson = currentLesson, lesson.questions.indices.contains(selectedQuestion) else { return nil }
        return lesson.questions[selectedQuestion]
    }

    func open(_ lesson: Lesson) {
        stop()
        selectedLessonID = lesson.id
        selectedQuestion = 0
        selectedAnswer = nil
        mode = .translated
    }

    func answer(_ choice: Int) {
        guard let question else { return }
        selectedAnswer = choice
        answerHistory["\(currentLesson?.id ?? "")-\(selectedQuestion)"] = choice == question.answer
    }

    func nextQuestion() {
        guard let lesson = currentLesson else { return }
        if selectedQuestion + 1 < lesson.questions.count {
            selectedQuestion += 1
            selectedAnswer = nil
        } else {
            completedLessonIDs.insert(lesson.id)
            UserDefaults.standard.set(Array(completedLessonIDs), forKey: "completedLessonIDs")
            selectedQuestion = 0
            selectedAnswer = nil
        }
    }

    func togglePlayback() {
        guard let lesson = currentLesson else { return }
        if isPlaying { stop(); return }
        let gender = lesson.id.hasSuffix("1") || lesson.id.hasSuffix("3") || lesson.id.hasSuffix("5") ? "female" : "male"
        let fileName = "\(lesson.id)_\(gender)"
        guard let url = Bundle.main.url(forResource: fileName, withExtension: "mp3") else { return }
        do {
            player = try AVAudioPlayer(contentsOf: url)
            player?.enableRate = true
            player?.rate = rate
            player?.play()
            isPlaying = true
        } catch { isPlaying = false }
    }

    func setRate(_ newRate: Float) {
        rate = newRate
        player?.rate = newRate
    }

    func stop() {
        player?.stop()
        player = nil
        isPlaying = false
    }

    private static func loadLessons() -> [Lesson] {
        ["lessons-part1", "lessons-part2", "lessons-part3"].flatMap { name in
            guard let url = Bundle.main.url(forResource: name, withExtension: "json"),
                  let data = try? Data(contentsOf: url),
                  let decoded = try? JSONDecoder().decode([Lesson].self, from: data) else { return [] }
            return decoded
        }
    }
}
