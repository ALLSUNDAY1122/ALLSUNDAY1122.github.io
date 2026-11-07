import Foundation
import SwiftUI
import LearningSprintCore

struct SessionResult: Identifiable, Equatable {
    let id = UUID()
    let kind: SessionKind
    let correct: Int
    let total: Int
    var rate: Int { total == 0 ? 0 : Int((Double(correct) / Double(total) * 100).rounded()) }
}

@MainActor
final class KanriLearningStore: ObservableObject {
    @Published private(set) var questions: [LearningQuestion] = []
    @Published private(set) var state: LearningState
    @Published var selectedRound = 1
    @Published var activeSession: LearningSessionSnapshot?
    @Published var currentEvaluation: AnswerEvaluation?
    @Published var selectedAnswerIndex: Int?
    @Published var result: SessionResult?
    @Published var errorMessage: String?
    @Published var showPaywall = false
    @Published var importMessage: String?
    let purchase: PurchaseController
    private let stateStore: LearningStateStore
    private var repository: QuestionRepository?

    init(purchase: PurchaseController, bundle: Bundle = .main, stateDirectory: URL? = nil) {
        self.purchase = purchase
        self.stateStore = LearningStateStore(bundleID: KanriAppConfig.bundleID, contentVersion: KanriAppConfig.contentVersion, directoryURL: stateDirectory)
        do { let repository=try QuestionRepository.load(bundle:bundle); self.repository=repository; self.questions=repository.questions; self.state=try stateStore.load() }
        catch { self.state=LearningState(contentVersion:KanriAppConfig.contentVersion); self.errorMessage=error.localizedDescription }
        selectedRound=1
    }
    var isPremium:Bool{purchase.isPremium||KanriAppConfig.uiTestPremium}
    var shuffleQuestions:Bool{state.shuffleQuestions ?? true}
    var shuffleChoices:Bool{state.shuffleChoices ?? false}
    var currentQuestion:LearningQuestion?{ guard let s=activeSession,s.currentIndex>=0,s.currentIndex<s.questionIDs.count else{return nil}; return repository?.question(id:s.questionIDs[s.currentIndex]) }
    var sessionProgressText:String{ guard let s=activeSession else{return ""}; return "\(s.currentIndex+1) / \(s.questionIDs.count)" }
    var todayAnswered:Int{LearningEngine.todayAnsweredCount(state:state)}
    var uniqueAnsweredCount:Int{Set(state.attempts.map(\.questionID)).count}
    var accuracy:Int{ guard !state.attempts.isEmpty else{return 0}; return Int((Double(state.attempts.filter(\.isCorrect).count)/Double(state.attempts.count)*100).rounded()) }
    var weakCount:Int{state.weakQuestions.count}
    var dailyProgress:Double{min(1,Double(todayAnswered)/Double(max(1,state.dailyTarget)))}
    var dailyLabel:String{"\(min(todayAnswered,state.dailyTarget)) / \(state.dailyTarget)"}
    var heatmap:[Date:Int]{LearningEngine.heatmap35Days(state:state)}
    var requiredDailyPace:Int?{LearningEngine.requiredDailyPace(totalQuestionCount:600,uniqueAnsweredCount:uniqueAnsweredCount,examDate:state.examDate)}
    func setDailyTarget(_ v:Int){state.dailyTarget=LearningState.validTarget(v) ? v:8;save()}
    func setTextSizeStep(_ v:Int){state.textSizeStep=min(2,max(0,v));save()}
    func setExamDate(_ d:Date?){state.examDate=d;save()}
    func setShuffleQuestions(_ e:Bool){state.shuffleQuestions=e;save()}
    func setShuffleChoices(_ e:Bool){state.shuffleChoices=e;save()}
    func selectRound(_ r:Int){guard(1...3).contains(r)else{return};if !isPremium && r != 1{showPaywall=true;return};selectedRound=r}
    func startToday(){let r=isPremium ? selectedRound:1;startSession(selectPractice(from:accessibleQuestions(round:r)),kind:.sprint)}
    func startSubject(_ subject:String,round:Int?=nil){let r=round ?? selectedRound;if !isPremium&&r != 1{showPaywall=true;return};let pool=accessibleQuestions(round:r).filter{$0.subject==subject};guard !pool.isEmpty else{errorMessage="この分野の問題を読み込めませんでした。";return};startSession(selectPractice(from:pool),kind:.subject("第\(r)回|\(subject)"))}
    func startWeak(){let source=isPremium ? questions:questions.filter{!$0.premium};let selected=LearningEngine.selectWeak(from:source,state:state,target:state.dailyTarget,isPremium:isPremium);guard !selected.isEmpty else{errorMessage="現在、復習する苦手問題はありません。";return};startSession(selected,kind:.weak)}
    func startMock(_ r:Int){guard isPremium else{showPaywall=true;return};guard let repository else{errorMessage="問題データを読み込めません。";return};let set=repository.round(r);guard set.count==200 else{errorMessage="第\(r)回の模試データが200問ではありません。";return};startSession(set,kind:.mock("第\(r)回"))}
    func resume(){guard var s=state.resumeSession else{return};if s.questionIDs.contains(where:{repository?.question(id:$0)?.premium==true}) && !isPremium{showPaywall=true;return};while s.currentIndex<s.questionIDs.count,s.answers[s.questionIDs[s.currentIndex]] != nil{s.currentIndex+=1};if s.currentIndex>=s.questionIDs.count{complete(s);return};activeSession=s;state.resumeSession=s;currentEvaluation=nil;selectedAnswerIndex=nil;save()}
    func answer(index:Int?){guard var s=activeSession,let q=currentQuestion,s.answers[q.id]==nil else{return};let payload=index.map{AnswerPayload(selectedIndices:[$0])} ?? .unknown;do{let e=try LearningEngine.evaluate(q,answer:payload);s.answers[q.id]=payload;LearningEngine.record(question:q,evaluation:e,state:&state);activeSession=s;state.resumeSession=s;selectedAnswerIndex=index;currentEvaluation=e;save()}catch{errorMessage="採点できませんでした。問題データを確認してください。"}}
    func advance(){guard var s=activeSession,let q=currentQuestion,s.answers[q.id] != nil else{return};if s.currentIndex>=s.questionIDs.count-1{complete(s);return};s.currentIndex+=1;activeSession=s;state.resumeSession=s;currentEvaluation=nil;selectedAnswerIndex=nil;save()}
    func leaveSession(){activeSession=nil;currentEvaluation=nil;selectedAnswerIndex=nil;save()}
    func dismissResult(){result=nil}
    func answeredCount(round:Int)->Int{guard let repository else{return 0};let ids=Set(repository.round(round).map(\.id));return Set(state.attempts.map(\.questionID).filter(ids.contains)).count}
    func answeredCount(round:Int,subject:String)->Int{guard let repository else{return 0};let ids=Set(repository.round(round,subject:subject).map(\.id));return Set(state.attempts.map(\.questionID).filter(ids.contains)).count}
    func questionCount(round:Int,subject:String)->Int{repository?.round(round,subject:subject).count ?? 0}
    func completionCount(round:Int,subject:String)->Int{state.completionCount(for:.subject("第\(round)回|\(subject)"))}
    func mockCompletionCount(round:Int)->Int{state.completionCount(for:.mock("第\(round)回"))}
    func subjectAccuracy(_ subject:String)->Int?{let a=state.attempts.filter{$0.subject==subject};guard !a.isEmpty else{return nil};return Int((Double(a.filter(\.isCorrect).count)/Double(a.count)*100).rounded())}
    func exportBackup() throws->Data{try stateStore.exportBackup(state)}
    func importBackup(_ data:Data){do{state=try stateStore.importBackup(data,allowContentVersionMigration:false);activeSession=nil;result=nil;importMessage="JSONバックアップを復元しました。"}catch{importMessage=error.localizedDescription}}
    func resetLearningData(){do{try stateStore.reset();state=LearningState(contentVersion:KanriAppConfig.contentVersion);activeSession=nil;result=nil;importMessage="学習データをリセットしました。"}catch{importMessage=error.localizedDescription}}
    private func accessibleQuestions(round:Int)->[LearningQuestion]{guard let repository else{return[]};let set=repository.round(round);return isPremium ? set:set.filter{!$0.premium}}
    private func selectPractice(from pool:[LearningQuestion])->[LearningQuestion]{let count=min(state.dailyTarget,pool.count);if shuffleQuestions{return LearningEngine.selectSprint(from:pool,target:state.dailyTarget,isPremium:isPremium)};let unseen=pool.filter{q in !state.attempts.contains(where:{$0.questionID==q.id})};let seen=pool.filter{q in state.attempts.contains(where:{$0.questionID==q.id})};return Array((unseen+seen).prefix(count))}
    private func startSession(_ selected:[LearningQuestion],kind:SessionKind){guard !selected.isEmpty else{errorMessage="出題できる問題がありません。";return};let s=LearningSessionSnapshot(kind:kind,questionIDs:selected.map(\.id));activeSession=s;state.resumeSession=s;currentEvaluation=nil;selectedAnswerIndex=nil;result=nil;save()}
    private func complete(_ session:LearningSessionSnapshot){var correct=0;for id in session.questionIDs{guard let q=repository?.question(id:id),let answer=session.answers[id],let e=try? LearningEngine.evaluate(q,answer:answer) else{continue};if e.isCorrect{correct+=1}};state.recordCompletion(for:session.kind);state.resumeSession=nil;activeSession=nil;currentEvaluation=nil;selectedAnswerIndex=nil;result=SessionResult(kind:session.kind,correct:correct,total:session.questionIDs.count);save()}
    private func save(){do{try stateStore.save(state)}catch{errorMessage="学習状態を保存できませんでした。"}}
}
