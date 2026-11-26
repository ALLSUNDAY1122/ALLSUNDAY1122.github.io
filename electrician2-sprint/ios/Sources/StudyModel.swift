import SwiftUI
import Foundation

struct DemoQuestion: Identifiable, Codable {
    let id: Int
    let officialID: String
    let exam: String
    let examDate: String
    let questionNumber: Int
    let sourceURL: String
    let auditStatus: String
    let subject: String
    let prompt: String
    let choices: [String]
    let answer: Int
    let memory: String
    let explanation: String
    let diagramID: String?
}
struct ExamSet: Identifiable {
    let id: String
    let title: String
    let questionCount: Int
}
struct LearningSnapshot: Codable {
    var version = 1
    var goal = 8
    var done = 0
    var completed = 0
    var correct = 0
    var weakStreak: [Int:Int] = [:]
    var weakIDs: Set<Int> = []
    var graduatedIDs: Set<Int> = []
    var fontScale = 0
    var answeredIDs: [Int] = []
    var studyDays: Set<String> = []
    var lastStudyDate: String? = nil
}
final class StudyModel: ObservableObject {
    private let storageKey = "electrician2.learning.snapshot.v1"
    private let defaults: UserDefaults
    @Published var tab = 0
    @Published var goal = 8 { didSet { persist() } }
    @Published var done = 0 { didSet { persist() } }
    @Published var session: [DemoQuestion] = []
    @Published var index = 0
    @Published var selected: Int? = nil
    @Published var graded = false
    @Published var weakStreak: [Int:Int] = [:] { didSet { persist() } }
    @Published var weakIDs: Set<Int> = [] { didSet { persist() } }
    @Published var graduatedIDs: Set<Int> = [] { didSet { persist() } }
    @Published var completed = 0 { didSet { persist() } }
    @Published var correct = 0 { didSet { persist() } }
    @Published var fontScale = 0 { didSet { persist() } }
    @Published var answeredIDs: [Int] = [] { didSet { persist() } }
    @Published var studyDays: Set<String> = [] { didSet { persist() } }
    @Published var lastStudyDate: String? = nil { didSet { persist() } }
    @Published var showQuestion = false
    let demos: [DemoQuestion]
    let examSets: [ExamSet]
    let subjects: [String]
    let bankLoadError: String?

    var current: DemoQuestion? { session.indices.contains(index) ? session[index] : nil }
    var weakQuestions: [DemoQuestion] { demos.filter { weakIDs.contains($0.id) && !graduatedIDs.contains($0.id) } }
    var graduatedQuestions: [DemoQuestion] { demos.filter { graduatedIDs.contains($0.id) } }
    var accuracy: Int { completed == 0 ? 0 : Int(Double(correct)/Double(completed)*100) }
    var streakDays: Int {
        let cal = Calendar(identifier: .gregorian)
        var date = Date()
        if !studyDays.contains(Self.dayKey(date)) { date = cal.date(byAdding:.day,value:-1,to:date) ?? date }
        var count = 0
        while studyDays.contains(Self.dayKey(date)) && count < 366 {
            count += 1
            guard let next = cal.date(byAdding:.day,value:-1,to:date) else { break }
            date = next
        }
        return count
    }
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let bank = try? QuestionBankLoader.load() {
            self.demos = bank.questions.enumerated().map { index, q in
                let labels = ["イ", "ロ", "ハ", "ニ"]
                let answerIndex = labels.firstIndex(of: q.answerOfficial) ?? 0
                let refs = q.source.figureRefs ?? []
                let figure = q.source.figure
                let diagram = refs.first ?? (figure?.hasPrefix("E2-") == true ? figure : nil)
                return DemoQuestion(
                    id: index + 1, officialID: q.id, exam: q.exam, examDate: q.examDate,
                    questionNumber: q.questionNumber, sourceURL: q.source.url,
                    auditStatus: q.auditStatus ?? q.audit.releaseStatus, subject: q.section,
                    prompt: q.question, choices: q.choices.map(\.text), answer: answerIndex,
                    memory: q.hereToRemember ?? "要点解説は準備中です。",
                    explanation: q.explanation ?? "解説は準備中です。", diagramID: diagram
                )
            }
            self.examSets = Dictionary(grouping: self.demos, by: { String($0.officialID.dropLast(4)) })
                .map { key, questions in ExamSet(id: key, title: questions.first?.exam ?? key, questionCount: questions.count) }
                .sorted { $0.id < $1.id }
            self.subjects = Array(Set(self.demos.map(\.subject))).sorted()
            self.bankLoadError = nil
        } else {
            self.demos = []
            self.examSets = []
            self.subjects = []
            self.bankLoadError = "QUESTION_BANK.jsonを読み込めません。"
        }
        restore()
    }
    func start(_ count:Int = 8, weakOnly:Bool = false, subject:String? = nil) {
        var source = weakOnly ? weakQuestions : demos
        if let subject { source = source.filter { $0.subject == subject } }
        guard !source.isEmpty else { session = []; showQuestion = false; return }
        session = (0..<count).map { source[$0 % source.count] }
        index=0; selected=nil; graded=false; showQuestion=true
    }
    func start(examPrefix:String) {
        let source = demos.filter { $0.officialID.hasPrefix(examPrefix + "-") }
        guard !source.isEmpty else { session=[]; showQuestion=false; return }
        session=source; index=0; selected=nil; graded=false; showQuestion=true
    }
    func answer(_ value:Int) {
        guard !graded, let q=current else{return}
        selected=value; graded=true; completed += 1; answeredIDs.append(q.id)
        let today = Self.dayKey(Date())
        if lastStudyDate != today { done = 0; lastStudyDate = today }
        done += 1
        studyDays.insert(today)
        if q.answer == value {
            correct += 1
            if weakIDs.contains(q.id) && !graduatedIDs.contains(q.id) {
                let streak = (weakStreak[q.id] ?? 0) + 1
                weakStreak[q.id] = streak
                if streak >= 3 { graduatedIDs.insert(q.id); weakIDs.remove(q.id) }
            }
        } else {
            weakIDs.insert(q.id)
            weakStreak[q.id] = 0
            graduatedIDs.remove(q.id)
        }
    }
    func next() {
        if index+1 < session.count { index += 1; selected=nil; graded=false }
        else { showQuestion=false; session=[] }
    }
    func backupData() throws -> Data {
        let snapshot = LearningSnapshot(goal:goal,done:done,completed:completed,correct:correct,weakStreak:weakStreak,weakIDs:weakIDs,graduatedIDs:graduatedIDs,fontScale:fontScale,answeredIDs:answeredIDs,studyDays:studyDays,lastStudyDate:lastStudyDate)
        return try JSONEncoder.pretty.encode(snapshot)
    }
    func restoreBackup(_ data:Data) throws {
        let saved = try JSONDecoder().decode(LearningSnapshot.self,from:data)
        guard saved.version == 1, [4,8,16].contains(saved.goal), (0...2).contains(saved.fontScale) else {
            throw NSError(domain:"LearningBackup",code:1,userInfo:[NSLocalizedDescriptionKey:"この学習データ形式には対応していません。"])
        }
        goal=saved.goal; done=saved.done; completed=saved.completed; correct=saved.correct
        weakStreak=saved.weakStreak; weakIDs=saved.weakIDs; graduatedIDs=saved.graduatedIDs
        fontScale=saved.fontScale; answeredIDs=saved.answeredIDs; studyDays=saved.studyDays; lastStudyDate=saved.lastStudyDate
    }
    private func restore() {
        guard let data=defaults.data(forKey:storageKey),
              let saved=try? JSONDecoder().decode(LearningSnapshot.self,from:data) else { return }
        goal=saved.goal; done=saved.done; completed=saved.completed; correct=saved.correct
        weakStreak=saved.weakStreak; weakIDs=saved.weakIDs; graduatedIDs=saved.graduatedIDs
        fontScale=saved.fontScale; answeredIDs=saved.answeredIDs; studyDays=saved.studyDays; lastStudyDate=saved.lastStudyDate
    }
    private func persist() {
        let snapshot=LearningSnapshot(goal:goal,done:done,completed:completed,correct:correct,weakStreak:weakStreak,weakIDs:weakIDs,graduatedIDs:graduatedIDs,fontScale:fontScale,answeredIDs:answeredIDs,studyDays:studyDays,lastStudyDate:lastStudyDate)
        if let data=try? JSONEncoder.pretty.encode(snapshot) { defaults.set(data,forKey:storageKey) }
    }
    private static func dayKey(_ date:Date)->String {
        let f=DateFormatter(); f.calendar=Calendar(identifier:.gregorian); f.locale=Locale(identifier:"en_US_POSIX"); f.timeZone=TimeZone.current; f.dateFormat="yyyy-MM-dd"; return f.string(from:date)
    }
}
private extension JSONEncoder {
    static var pretty: JSONEncoder { let e=JSONEncoder(); e.outputFormatting=[.prettyPrinted,.sortedKeys]; return e }
}
