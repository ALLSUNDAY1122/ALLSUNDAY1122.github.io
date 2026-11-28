import AVFoundation
import Foundation

struct Lesson: Codable, Identifiable, Hashable {
    struct Segment: Codable, Hashable { let en: String; let ja: String }
    struct Question: Codable, Hashable { let q: String; let choices: [String]; let answer: Int; let explain: String }
    struct Voice: Codable, Hashable, Identifiable {
        let id: String
        let name: String
        let azureVoice: String
        let gender: String?
        let genderKey: String
    }
    struct AudioFile: Codable, Hashable {
        let path: String
        let azureVoice: String
        let ssml: String
    }
    struct Short: Codable, Hashable {
        let en: String
        let ja: String
        let audio: [String: AudioFile]
    }

    let id: String
    let region: String
    let level: String
    let title: String
    let topic: String
    let en: String
    let ja: String
    let segments: [Segment]
    let questions: [Question]
    let voices: [Voice]
    let audio: [String: AudioFile]
    let short: Short

    func audioFile(voiceID: String, shortened: Bool) -> AudioFile? {
        (shortened ? short.audio : audio)[voiceID]
    }
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
    @Published private(set) var completedLessonCounts: [String: Int] = [:]
    @Published var answerHistory: [String: Bool] = [:]
    @Published var selectedVoiceID = ""
    @Published var useShortAudio = false

    private var player: AVAudioPlayer?

    init() {
        lessons = Self.loadLessons()
        completedLessonIDs = Set(UserDefaults.standard.stringArray(forKey: "completedLessonIDs") ?? [])
        completedLessonCounts = UserDefaults.standard.dictionary(forKey: "completedLessonCounts") as? [String: Int] ?? [:]
    }

    var currentLesson: Lesson? {
        guard let selectedLessonID else { return nil }
        return lessons.first { $0.id == selectedLessonID }
    }

    var selectedVoice: Lesson.Voice? {
        guard let lesson = currentLesson else { return nil }
        return lesson.voices.first { $0.id == selectedVoiceID } ?? lesson.voices.first
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
        useShortAudio = false
        selectedVoiceID = lesson.voices.first(where: { $0.genderKey == "female" })?.id ?? lesson.voices.first?.id ?? ""
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
            completedLessonCounts[lesson.id, default: 0] += 1
            UserDefaults.standard.set(Array(completedLessonIDs), forKey: "completedLessonIDs")
            UserDefaults.standard.set(completedLessonCounts, forKey: "completedLessonCounts")
            selectedQuestion = 0
            selectedAnswer = nil
        }
    }

    func togglePlayback() {
        guard let lesson = currentLesson else { return }
        if isPlaying { stop(); return }
        guard let voice = selectedVoice,
              let audio = lesson.audioFile(voiceID: voice.id, shortened: useShortAudio),
              let url = Self.audioURL(for: audio.path) else {
            isPlaying = false
            return
        }
        do {
            player = try AVAudioPlayer(contentsOf: url)
            player?.enableRate = true
            player?.rate = rate
            player?.play()
            isPlaying = true
        } catch {
            isPlaying = false
        }
    }

    private static func audioURL(for path: String) -> URL? {
        let normalized = path.replacingOccurrences(of: "\\", with: "/")
        let components = normalized.split(separator: "/")
        guard let file = components.last else { return nil }
        let fileName = String(file)
        let ext = URL(fileURLWithPath: fileName).pathExtension
        let stem = URL(fileURLWithPath: fileName).deletingPathExtension().lastPathComponent
        let directory = components.dropLast().joined(separator: "/")
        if !directory.isEmpty,
           let nested = Bundle.main.url(forResource: stem, withExtension: ext, subdirectory: directory) {
            return nested
        }
        return Bundle.main.url(forResource: stem, withExtension: ext)
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
                  let decoded = try? JSONDecoder().decode([Lesson].self, from: data) else { return [Lesson]() }
            return decoded
        }
    }
}
