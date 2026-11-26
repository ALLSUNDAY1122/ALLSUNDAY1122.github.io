import SwiftUI
import Foundation

struct DemoQuestion: Identifiable, Codable {
    let id: Int
    let subject: String
    let prompt: String
    let choices: [String]
    let answer: Int
    let memory: String
    let explanation: String
    let diagramID: String?
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
    @Published var showQuestion = false
    let subjects = ["電気に関する基礎理論","配電理論・配線設計","電気機器・材料・工具","電気工事の施工方法","一般用電気工作物の検査","配線図","法令"]
    let demos = [
        DemoQuestion(id:1,subject:"電気に関する基礎理論",prompt:"【サンプル問題】抵抗値と電流の関係を確認しましょう。",choices:["オームの法則","フレミングの左手の法則","レンツの法則","クーロンの法則"],answer:0,memory:"電圧・電流・抵抗の関係を整理する",explanation:"この設問はUI確認用の架空サンプルです。公式過去問ではありません。",diagramID:nil),
        DemoQuestion(id:2,subject:"配線図",prompt:"【サンプル問題】共通配線図の表示領域（ダミー）を確認しましょう。",choices:["イ","ロ","ハ","ニ"],answer:1,memory:"図面の記号と接続関係を対応させる",explanation:"配線図は未搭載です。",diagramID:"DEMO-COMMON-01")
    ]
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
    init(defaults: UserDefaults = .standard) { self.defaults = defaults; restore() }
    func start(_ count:Int = 8, weakOnly:Bool = false) {
        let source = weakOnly ? weakQuestions : demos
        guard !source.isEmpty else { session = []; showQuestion = false; return }
        session = (0..<count).map { source[$0 % source.count] }
        index=0; selected=nil; graded=false; showQuestion=true
    }
    func answer(_ value:Int) {
        guard !graded, let q=current else{return}
        selected=value; graded=true; completed += 1; done += 1; answeredIDs.append(q.id)
        studyDays.insert(Self.dayKey(Date()))
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
        let snapshot = LearningSnapshot(goal:goal,done:done,completed:completed,correct:correct,weakStreak:weakStreak,weakIDs:weakIDs,graduatedIDs:graduatedIDs,fontScale:fontScale,answeredIDs:answeredIDs,studyDays:studyDays)
        return try JSONEncoder.pretty.encode(snapshot)
    }
    func restoreBackup(_ data:Data) throws {
        let saved = try JSONDecoder().decode(LearningSnapshot.self,from:data)
        guard saved.version == 1, [4,8,16].contains(saved.goal), (0...2).contains(saved.fontScale) else {
            throw NSError(domain:"LearningBackup",code:1,userInfo:[NSLocalizedDescriptionKey:"この学習データ形式には対応していません。"])
        }
        goal=saved.goal; done=saved.done; completed=saved.completed; correct=saved.correct
        weakStreak=saved.weakStreak; weakIDs=saved.weakIDs; graduatedIDs=saved.graduatedIDs
        fontScale=saved.fontScale; answeredIDs=saved.answeredIDs; studyDays=saved.studyDays
    }
    private func restore() {
        guard let data=defaults.data(forKey:storageKey),
              let saved=try? JSONDecoder().decode(LearningSnapshot.self,from:data) else { return }
        goal=saved.goal; done=saved.done; completed=saved.completed; correct=saved.correct
        weakStreak=saved.weakStreak; weakIDs=saved.weakIDs; graduatedIDs=saved.graduatedIDs
        fontScale=saved.fontScale; answeredIDs=saved.answeredIDs; studyDays=saved.studyDays
    }
    private func persist() {
        let snapshot=LearningSnapshot(goal:goal,done:done,completed:completed,correct:correct,weakStreak:weakStreak,weakIDs:weakIDs,graduatedIDs:graduatedIDs,fontScale:fontScale,answeredIDs:answeredIDs,studyDays:studyDays)
        if let data=try? JSONEncoder.pretty.encode(snapshot) { defaults.set(data,forKey:storageKey) }
    }
    private static func dayKey(_ date:Date)->String {
        let f=DateFormatter(); f.calendar=Calendar(identifier:.gregorian); f.locale=Locale(identifier:"en_US_POSIX"); f.timeZone=TimeZone.current; f.dateFormat="yyyy-MM-dd"; return f.string(from:date)
    }
}
private extension JSONEncoder {
    static var pretty: JSONEncoder { let e=JSONEncoder(); e.outputFormatting=[.prettyPrinted,.sortedKeys]; return e }
}
