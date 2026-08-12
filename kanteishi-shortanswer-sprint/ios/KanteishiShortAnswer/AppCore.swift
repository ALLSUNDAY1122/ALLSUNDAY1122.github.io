import Foundation
import Combine
import SwiftUI
import UniformTypeIdentifiers

struct QuestionPayload: Codable {
    let schemaVersion: Int
    let contentVersion: String
    let qualification: String
    let sourceCheckedAt: String
    let productionTargetCount: Int
    let questions: [AppQuestion]
}

struct AppQuestion: Codable, Identifiable, Hashable {
    let id: String
    let round: Int
    let edition: Int
    let questionNo: Int
    let subject: String
    let domain: String
    let topic: String
    let question: String
    let choices: [String]
    let correctIndex: Int
    let memoryLine: String
    let shortExplanation: String
    let detailExplanation: String
    let sourceURL: String
    let referenceDate: String
    let originType: String
    let rightsBasis: String
}

enum MainTab: String, CaseIterable, Identifiable {
    case home, mock, history, settings
    var id: String { rawValue }
    var title: String {
        switch self { case .home: "ホーム"; case .mock: "模試"; case .history: "記録"; case .settings: "設定" }
    }
    var systemImage: String {
        switch self { case .home: "house"; case .mock: "doc.text"; case .history: "chart.bar"; case .settings: "gearshape" }
    }
}

enum SessionMode: String, Codable { case practice, mock }
enum FontSizePreference: String, Codable, CaseIterable, Identifiable {
    case normal, large, xlarge
    var id: String { rawValue }
    var title: String { switch self { case .normal: "標準"; case .large: "大"; case .xlarge: "特大" } }
    var scale: CGFloat { switch self { case .normal: 1; case .large: 1.13; case .xlarge: 1.27 } }
}

struct UserSettings: Codable, Equatable {
    var dailyGoal = 8
    var fontSize: FontSizePreference = .normal
    var examDate: Date?
}
struct WeakProgress: Codable, Equatable { var streak: Int; var lastUpdatedAt: Date }
struct AnswerLogEntry: Codable, Identifiable, Equatable {
    let id: UUID
    let questionID: String
    let answeredAt: Date
    let responseIndex: Int?
    let isUnknown: Bool
    let correct: Bool
    let domain: String
    let sessionKey: String
    let edition: Int
}
struct SessionResponse: Codable, Equatable { let selectedIndex: Int?; let isUnknown: Bool; let correct: Bool }
struct SessionState: Codable, Equatable {
    let key: String
    let title: String
    let mode: SessionMode
    let questionIDs: [String]
    var index: Int
    var responses: [String: SessionResponse]
    let startedAt: Date
    var total: Int { questionIDs.count }
}
struct CompletionRecord: Codable, Identifiable, Equatable {
    let id: UUID
    let key: String
    let title: String
    let mode: SessionMode
    let completedAt: Date
    let total: Int
    let correct: Int
}
struct PersistedLearningState: Codable, Equatable {
    var schemaVersion = 1
    var contentVersion: String
    var weak: [String: WeakProgress] = [:]
    var seenIDs: Set<String> = []
    var answerLog: [AnswerLogEntry] = []
    var sessionCompletions: [String: Int] = [:]
    var completionHistory: [CompletionRecord] = []
    var settings = UserSettings()
    var inProgress: SessionState?
    static func fresh(contentVersion: String) -> Self { .init(contentVersion: contentVersion) }
}
struct SessionResult: Identifiable, Equatable {
    let id = UUID()
    let key: String
    let title: String
    let mode: SessionMode
    let questionIDs: [String]
    let responses: [String: SessionResponse]
    var total: Int { questionIDs.count }
    var correct: Int { responses.values.filter(\.correct).count }
    var accuracy: Int { total == 0 ? 0 : Int((Double(correct) / Double(total) * 100).rounded()) }
}
struct BackupEnvelope: Codable {
    let exportedAt: Date
    let appNamespace: String
    let contentVersion: String
    let state: PersistedLearningState
}
struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}

struct QuestionRepository {
    let payload: QuestionPayload
    private let byID: [String: AppQuestion]
    init(payload: QuestionPayload) {
        self.payload = payload
        byID = Dictionary(uniqueKeysWithValues: payload.questions.map { ($0.id, $0) })
    }
    static func load(bundle: Bundle = .main) throws -> Self {
        guard let url = bundle.url(forResource: "questions.prototype", withExtension: "json")
                ?? bundle.url(forResource: "questions.prototype", withExtension: "json", subdirectory: "Resources") else {
            throw RepositoryError.missingResource
        }
        let payload = try JSONDecoder().decode(QuestionPayload.self, from: Data(contentsOf: url))
        try validate(payload)
        return .init(payload: payload)
    }
    static var empty: Self { .init(payload: .init(schemaVersion: 1, contentVersion: "missing", qualification: "不動産鑑定士試験・短答式", sourceCheckedAt: "", productionTargetCount: 240, questions: [])) }
    var questions: [AppQuestion] { payload.questions }
    var editions: [Int] { Array(Set(questions.map(\.edition))).sorted(by: >) }
    var domains: [String] { Array(Set(questions.map(\.domain))).sorted { $0.localizedStandardCompare($1) == .orderedAscending } }
    func question(id: String) -> AppQuestion? { byID[id] }
    func questions(edition: Int) -> [AppQuestion] { questions.filter { $0.edition == edition }.sorted { ($0.subject, $0.questionNo) < ($1.subject, $1.questionNo) } }
    func questions(domain: String) -> [AppQuestion] { questions.filter { $0.domain == domain } }
    private static func validate(_ payload: QuestionPayload) throws {
        guard payload.productionTargetCount == 240 else { throw RepositoryError.invalidProductionTarget }
        guard payload.questions.count == 12 else { throw RepositoryError.invalidPrototypeCount(payload.questions.count) }
        guard Set(payload.questions.map(\.id)).count == payload.questions.count else { throw RepositoryError.duplicateIDs }
        for round in 1...3 {
            for subject in ["不動産に関する行政法規", "不動産の鑑定評価に関する理論"] {
                let count = payload.questions.filter { $0.round == round && $0.subject == subject }.count
                guard count == 2 else { throw RepositoryError.invalidRoundSubject(round, subject, count) }
            }
        }
        for q in payload.questions {
            guard q.choices.count == 4, q.choices.indices.contains(q.correctIndex), !q.question.isEmpty, !q.memoryLine.isEmpty,
                  !q.detailExplanation.isEmpty, URL(string: q.sourceURL) != nil, !q.referenceDate.isEmpty, !q.rightsBasis.isEmpty else {
                throw RepositoryError.invalidQuestion(q.id)
            }
        }
    }
    enum RepositoryError: LocalizedError {
        case missingResource, invalidProductionTarget, invalidPrototypeCount(Int), duplicateIDs, invalidRoundSubject(Int,String,Int), invalidQuestion(String)
        var errorDescription: String? {
            switch self {
            case .missingResource: "試作問題データを読み込めません。"
            case .invalidProductionTarget: "製品版問題枠は240問でなければなりません。"
            case .invalidPrototypeCount(let count): "試作データが\(count)問です。正本は12問です。"
            case .duplicateIDs: "問題IDが重複しています。"
            case .invalidRoundSubject(let round, let subject, let count): "R\(round)・\(subject)が\(count)問です。試作正本は2問です。"
            case .invalidQuestion(let id): "\(id)の必須データが不正です。"
            }
        }
    }
}

@MainActor
final class LearningStore: ObservableObject {
    static let backupNamespace = "kanteishi-shortanswer-sprint"
    @Published var state: PersistedLearningState
    @Published var currentTab: MainTab = .home
    @Published var session: SessionState?
    @Published var result: SessionResult?
    @Published var startupError: String?
    @Published var importMessage: String?
    let repository: QuestionRepository
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let persistenceURL: URL

    init(bundle: Bundle = .main, persistenceURL: URL? = nil) {
        let enc = JSONEncoder(); enc.outputFormatting = [.prettyPrinted, .sortedKeys]; enc.dateEncodingStrategy = .iso8601; encoder = enc
        let dec = JSONDecoder(); dec.dateDecodingStrategy = .iso8601; decoder = dec
        do { repository = try QuestionRepository.load(bundle: bundle); startupError = nil } catch { repository = .empty; startupError = error.localizedDescription }
        let url = persistenceURL ?? FileManager.default.temporaryDirectory.appendingPathComponent("kanteishi-learning-state.json")
        self.persistenceURL = url
        if let data = try? Data(contentsOf: url), let loaded = try? dec.decode(PersistedLearningState.self, from: data) { state = loaded } else { state = .fresh(contentVersion: repository.payload.contentVersion) }
        session = state.inProgress
    }

    var settings: UserSettings { state.settings }
    var fontScale: CGFloat { settings.fontSize.scale }
    var totalAnswered: Int { state.answerLog.count }
    var totalCorrect: Int { state.answerLog.filter(\.correct).count }
    var overallAccuracy: Int { totalAnswered == 0 ? 0 : Int((Double(totalCorrect) / Double(totalAnswered) * 100).rounded()) }
    var seenCount: Int { state.seenIDs.count }
    var weakQuestions: [AppQuestion] { repository.questions.filter { state.weak[$0.id] != nil } }
    var todayAnswered: Int { state.answerLog.filter { Calendar.current.isDateInToday($0.answeredAt) }.count }
    var todayCorrect: Int { state.answerLog.filter { Calendar.current.isDateInToday($0.answeredAt) && $0.correct }.count }
    var todayGoalProgress: Double { settings.dailyGoal == 0 ? 0 : min(1, Double(todayAnswered) / Double(settings.dailyGoal)) }
    var examCountdown: (days: Int, pace: Int)? {
        guard let date = settings.examDate else { return nil }
        let cal = Calendar.current; let today = cal.startOfDay(for: Date()); let exam = cal.startOfDay(for: date)
        guard let days = cal.dateComponents([.day], from: today, to: exam).day else { return nil }
        let remaining = max(0, repository.payload.productionTargetCount - seenCount)
        return (days, days > 0 ? max(1, Int(ceil(Double(remaining) / Double(days)))) : 0)
    }
    func startToday() { startSession(key: "today", questions: Array(repository.questions.shuffled().prefix(settings.dailyGoal)), title: "今日のスプリント", mode: .practice) }
    func startWeak() { startSession(key: "weak", questions: weakQuestions.shuffled(), title: "苦手をつぶす", mode: .practice) }
    func startDomain(_ domain: String) { startSession(key: "domain:\(domain)", questions: Array(repository.questions(domain: domain).shuffled().prefix(settings.dailyGoal)), title: domain, mode: .practice) }
    func startMock(edition: Int) { startSession(key: "exam:\(edition)", questions: repository.questions(edition: edition), title: "令和\(edition - 2018)年 試作模試", mode: .mock) }
    func retryQuestions(_ ids: [String], title: String) { startSession(key: "retry", questions: ids.compactMap(repository.question), title: title, mode: .practice) }
    func resumeSession() { session = state.inProgress; result = nil }
    func exitSessionToHome() { if let session { state.inProgress = session; persist() }; self.session = nil; result = nil; currentTab = .home }
    func currentQuestion() -> AppQuestion? { guard let s = session, s.questionIDs.indices.contains(s.index) else { return nil }; return repository.question(id: s.questionIDs[s.index]) }
    func response(for q: AppQuestion) -> SessionResponse? { session?.responses[q.id] }
    func submitAnswer(_ selected: Int?) {
        guard var s = session, let q = currentQuestion(), s.responses[q.id] == nil else { return }
        let unknown = selected == nil; let correct = selected == q.correctIndex
        s.responses[q.id] = .init(selectedIndex: selected, isUnknown: unknown, correct: correct); session = s
        state.seenIDs.insert(q.id); updateWeak(q.id, correct: correct)
        state.answerLog.append(.init(id: UUID(), questionID: q.id, answeredAt: Date(), responseIndex: selected, isUnknown: unknown, correct: correct, domain: q.domain, sessionKey: s.key, edition: q.edition))
        state.inProgress = s; persist()
    }
    func advanceSession() {
        guard var s = session, s.responses[s.questionIDs[s.index]] != nil else { return }
        if s.index + 1 < s.total { s.index += 1; session = s; state.inProgress = s; persist() }
        else { complete(s) }
    }
    func completionCount(for key: String) -> Int { state.sessionCompletions[key, default: 0] }
    func latestCompletion(for key: String) -> CompletionRecord? { state.completionHistory.first { $0.key == key } }
    func domainStats(_ domain: String) -> (answered: Int, accuracy: Int) { let logs = state.answerLog.filter { $0.domain == domain }; return logs.isEmpty ? (0,0) : (logs.count, Int((Double(logs.filter(\.correct).count)/Double(logs.count)*100).rounded())) }
    func resultDomainStats(_ r: SessionResult) -> [(domain:String,total:Int,correct:Int)] {
        var d:[String:(Int,Int)] = [:]; for id in r.questionIDs { guard let q = repository.question(id:id), let response = r.responses[id] else { continue }; let v=d[q.domain] ?? (0,0); d[q.domain]=(v.0+1,v.1+(response.correct ? 1:0)) }; return d.map{($0.key,$0.value.0,$0.value.1)}.sorted{$0.0<$1.0}
    }
    func missedQuestionIDs(in r: SessionResult) -> [String] { r.questionIDs.filter { !(r.responses[$0]?.correct ?? false) } }
    func heatmap(days:Int=35) -> [(Date,Int)] { let cal=Calendar.current; let today=cal.startOfDay(for:Date()); return (0..<days).reversed().compactMap { o in guard let d=cal.date(byAdding:.day,value:-o,to:today) else{return nil}; return (d,state.answerLog.filter{cal.isDate($0.answeredAt,inSameDayAs:d)}.count) } }
    func setDailyGoal(_ value:Int) { guard [4,8,16].contains(value) else{return}; state.settings.dailyGoal=value; persist() }
    func setFontSize(_ value:FontSizePreference){state.settings.fontSize=value;persist()}
    func setExamDate(_ value:Date?){state.settings.examDate=value;persist()}
    func exportBackup() throws -> Data { try encoder.encode(BackupEnvelope(exportedAt: Date(), appNamespace: Self.backupNamespace, contentVersion: repository.payload.contentVersion, state: state)) }
    func importBackup(_ data:Data) throws { let env=try decoder.decode(BackupEnvelope.self,from:data); guard env.appNamespace==Self.backupNamespace else{throw BackupError.wrongApp}; state=env.state; session=state.inProgress; result=nil; persist(); importMessage="バックアップを読み込みました。" }
    func clearImportMessage(){importMessage=nil}
    private func startSession(key:String, questions:[AppQuestion], title:String, mode:SessionMode){guard !questions.isEmpty else{return}; let s=SessionState(key:key,title:title,mode:mode,questionIDs:questions.map(\.id),index:0,responses:[:],startedAt:Date());session=s;result=nil;state.inProgress=s;persist()}
    private func updateWeak(_ id:String, correct:Bool){ if correct { guard var p=state.weak[id] else{return}; p.streak += 1; p.lastUpdatedAt=Date(); if p.streak>=3{state.weak.removeValue(forKey:id)}else{state.weak[id]=p} } else { state.weak[id]=.init(streak:0,lastUpdatedAt:Date()) } }
    private func complete(_ s:SessionState){let r=SessionResult(key:s.key,title:s.title,mode:s.mode,questionIDs:s.questionIDs,responses:s.responses);state.sessionCompletions[s.key,default:0]+=1;state.completionHistory.insert(.init(id:UUID(),key:s.key,title:s.title,mode:s.mode,completedAt:Date(),total:r.total,correct:r.correct),at:0);state.inProgress=nil;session=nil;result=r;persist()}
    private func persist(){if let data=try? encoder.encode(state){try? data.write(to:persistenceURL,options:.atomic)}}
    enum BackupError:LocalizedError{case wrongApp;var errorDescription:String?{"このバックアップは不動産鑑定士試験・短答式用ではありません。"}}
}
