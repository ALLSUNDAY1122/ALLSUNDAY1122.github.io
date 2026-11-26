import SwiftUI

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
private struct LearningSnapshot: Codable {
    var goal = 8
    var done = 0
    var completed = 0
    var correct = 0
    var weakStreak: [Int:Int] = [:]
    var weakIDs: Set<Int> = []
    var graduatedIDs: Set<Int> = []
    var fontScale = 1
    var answeredIDs: [Int] = []
}
final class StudyModel: ObservableObject {
    private let storageKey = "electrician2.learning.snapshot.v1"
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
    @Published var fontScale = 1 { didSet { persist() } }
    @Published var answeredIDs: [Int] = [] { didSet { persist() } }
    @Published var showQuestion = false
    let subjects = ["電気に関する基礎理論","配電理論・配線設計","電気機器・材料・工具","電気工事の施工方法","一般用電気工作物の検査","配線図","法令"]
    let demos = [
        DemoQuestion(id:1,subject:"電気に関する基礎理論",prompt:"【サンプル問題】抵抗値と電流の関係を確認しましょう。",choices:["オームの法則","フレミングの左手の法則","レンツの法則","クーロンの法則"],answer:0,memory:"ここだけ覚える：電圧 V＝電流 I × 抵抗 R",explanation:"この設問はUI確認用の架空サンプルです。公式過去問ではありません。",diagramID:nil),
        DemoQuestion(id:2,subject:"配線図",prompt:"【サンプル問題】共通配線図の表示領域（ダミー）を確認しましょう。",choices:["イ","ロ","ハ","ニ"],answer:1,memory:"ここだけ覚える：図面の記号と接続関係を対応させる",explanation:"配線図は未搭載です。ここに権利確認済みの共通図版が表示されます。",diagramID:"DEMO-COMMON-01")
    ]
    var current: DemoQuestion? { session.indices.contains(index) ? session[index] : nil }
    var weakQuestions: [DemoQuestion] { demos.filter { weakIDs.contains($0.id) && !graduatedIDs.contains($0.id) } }
    var graduatedQuestions: [DemoQuestion] { demos.filter { graduatedIDs.contains($0.id) } }
    init() { restore() }
    func start(_ count:Int = 8, weakOnly:Bool = false) {
        let source = weakOnly ? weakQuestions : demos
        let safe = source.isEmpty ? demos : source
        session = (0..<count).map { safe[$0 % safe.count] }
        index=0; selected=nil; graded=false; showQuestion=true
    }
    func answer(_ value:Int) {
        guard !graded, let q=current else{return}
        selected=value; graded=true; completed += 1; done += 1; answeredIDs.append(q.id)
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
    private func restore() {
        guard let data=UserDefaults.standard.data(forKey:storageKey),
              let saved=try? JSONDecoder().decode(LearningSnapshot.self,from:data) else { return }
        goal=saved.goal; done=saved.done; completed=saved.completed; correct=saved.correct
        weakStreak=saved.weakStreak; weakIDs=saved.weakIDs; graduatedIDs=saved.graduatedIDs
        fontScale=saved.fontScale; answeredIDs=saved.answeredIDs
    }
    private func persist() {
        let snapshot=LearningSnapshot(goal:goal,done:done,completed:completed,correct:correct,weakStreak:weakStreak,weakIDs:weakIDs,graduatedIDs:graduatedIDs,fontScale:fontScale,answeredIDs:answeredIDs)
        if let data=try? JSONEncoder().encode(snapshot) { UserDefaults.standard.set(data,forKey:storageKey) }
    }
}
