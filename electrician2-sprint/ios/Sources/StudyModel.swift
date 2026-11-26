import SwiftUI

struct DemoQuestion: Identifiable {
    let id: Int
    let subject: String
    let prompt: String
    let choices: [String]
    let answer: Int
    let memory: String
    let explanation: String
    let diagramID: String?
}
final class StudyModel: ObservableObject {
    @Published var tab = 0
    @Published var goal = 8
    @Published var done = 3
    @Published var session: [DemoQuestion] = []
    @Published var index = 0
    @Published var selected: Int? = nil
    @Published var graded = false
    @Published var weakStreak: [Int:Int] = [:]
    @Published var completed = 0
    @Published var correct = 0
    @Published var showQuestion = false
    let subjects = ["電気に関する基礎理論","配電理論・配線設計","電気機器・材料・工具","電気工事の施工方法","一般用電気工作物の検査","配線図","法令"]
    let demos = [
        DemoQuestion(id:1,subject:"電気に関する基礎理論",prompt:"【サンプル問題】抵抗値と電流の関係を確認しましょう。",choices:["オームの法則","フレミングの左手の法則","レンツの法則","クーロンの法則"],answer:0,memory:"ここだけ覚える：電圧 V＝電流 I × 抵抗 R",explanation:"この設問はUI確認用の架空サンプルです。公式過去問ではありません。",diagramID:nil),
        DemoQuestion(id:2,subject:"配線図",prompt:"【サンプル問題】共通配線図の表示領域（ダミー）を確認しましょう。",choices:["イ","ロ","ハ","ニ"],answer:1,memory:"ここだけ覚える：図面の記号と接続関係を対応させる",explanation:"配線図は未搭載です。ここに権利確認済みの共通図版が表示されます。",diagramID:"DEMO-COMMON-01")
    ]
    var current: DemoQuestion? { session.indices.contains(index) ? session[index] : nil }
    func start(_ count:Int = 8) { session = Array((0..<count).map { i in demos[i % demos.count] }); index=0; selected=nil; graded=false; showQuestion=true }
    func answer(_ value:Int) { guard !graded else{return}; selected=value; graded=true; completed += 1; if current?.answer == value { correct += 1; if let id=current?.id { weakStreak[id,default:0] += 1 } } else if let id=current?.id { weakStreak[id]=0 } }
    func next() { if index+1 < session.count { index += 1; selected=nil; graded=false } else { showQuestion=false; session=[] } }
}
