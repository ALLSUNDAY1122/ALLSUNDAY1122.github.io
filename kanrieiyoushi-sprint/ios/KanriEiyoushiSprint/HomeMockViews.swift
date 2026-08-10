import SwiftUI
import LearningSprintCore

struct RootView: View {
    @EnvironmentObject private var store: KanriLearningStore
    @State private var tab: MainTab = .home
    var body: some View {
        ZStack {
            TabView(selection:$tab) {
                HomeView(tab:$tab).tag(MainTab.home).tabItem{Label("ホーム",systemImage:"house")}
                MockListView().tag(MainTab.mock).tabItem{Label("模試",systemImage:"doc.text")}
                HistoryView().tag(MainTab.history).tabItem{Label("記録",systemImage:"chart.bar")}
                SettingsView().tag(MainTab.settings).tabItem{Label("設定",systemImage:"gearshape")}
            }.tint(LearningSprintTheme.indigo)
            if store.activeSession != nil { QuizView().zIndex(10) }
            else if store.result != nil { ResultView().zIndex(10) }
        }
        .sheet(isPresented:$store.showPaywall){PaywallView()}
        .alert("確認",isPresented:Binding(get:{store.errorMessage != nil},set:{if !$0{store.errorMessage=nil}})){Button("OK",role:.cancel){store.errorMessage=nil}} message:{Text(store.errorMessage ?? "")}
        .accessibilityIdentifier("rootView")
    }
}

struct HomeView: View {
    @EnvironmentObject private var store: KanriLearningStore
    @EnvironmentObject private var purchase: PurchaseController
    @Binding var tab: MainTab
    var body: some View {
        ZStack {
            LearningSprintPaperBackground()
            ScrollView {
                VStack(alignment:.leading,spacing:18) {
                    header; todayCard
                    if store.state.resumeSession != nil {
                        Button(action:store.resume){HStack{Text("続きから再開").fontWeight(.bold);Spacer();Image(systemName:"arrow.right")}.frame(minHeight:44).padding(.horizontal,16)}.buttonStyle(.bordered).tint(LearningSprintTheme.indigo).accessibilityIdentifier("resumeButton")
                    }
                    Button(action:store.startToday){HStack{VStack(alignment:.leading,spacing:3){Text("今日のスプリント").font(.caption);Text("\(store.state.dailyTarget)問で始める").font(.headline)};Spacer();Image(systemName:"arrow.right")}.frame(minHeight:54).padding(.horizontal,18)}.buttonStyle(.borderedProminent).tint(LearningSprintTheme.indigo).accessibilityIdentifier("todaySprintButton")
                    HStack(spacing:12){actionCard(title:"苦手をつぶす",subtitle:"3連続正解で解除",badge:"\(store.weakCount)",icon:"exclamationmark.circle"){store.startWeak()};actionCard(title:"模擬試験",subtitle:"3回 × 200問",badge:purchase.isPremium||KanriAppConfig.uiTestPremium ? "":"鍵",icon:"doc.text"){tab = .mock}}
                    VStack(alignment:.leading,spacing:12){HStack{Text("分野から解く").font(LearningSprintTheme.serif(22,weight:.bold));Spacer();Text("第\(store.selectedRound)回")};roundPicker;ForEach(KanriAppConfig.subjects,id:\.self){subject in subjectCard(subject)}}
                    VStack(alignment:.leading,spacing:10){Text("これまで").font(LearningSprintTheme.serif(22,weight:.bold));HStack{metric("解答","\(store.state.attempts.count)");metric("正答率",store.state.attempts.isEmpty ? "—":"\(store.accuracy)%");metric("苦手","\(store.weakCount)")}.padding(16).background(LearningSprintTheme.card).clipShape(RoundedRectangle(cornerRadius:18))}
                }.padding(.horizontal,20).padding(.top,24).padding(.bottom,32)
            }
        }.accessibilityIdentifier("homeView")
    }
    private var header:some View{VStack(alignment:.leading,spacing:8){Label("学びスプリント",systemImage:"graduationcap.circle").font(.headline).foregroundStyle(LearningSprintTheme.indigo);Text("管理栄養士").font(LearningSprintTheme.serif(38,weight:.bold)).foregroundStyle(LearningSprintTheme.ink);Text("今日も1問、力に変える。").font(.headline).foregroundStyle(LearningSprintTheme.ink2);if let pace=store.requiredDailyPace{Text("試験日まで：600問完走には1日約\(pace)問").font(.caption).foregroundStyle(LearningSprintTheme.ink2)}}}
    private var todayCard:some View{HStack(spacing:20){LearningSprintProgressRing(progress:store.dailyProgress,label:store.dailyLabel);VStack(alignment:.leading,spacing:6){Text("今日の学習").font(.caption).foregroundStyle(LearningSprintTheme.ink3);Text("少しずつ、確実に。").font(LearningSprintTheme.serif(20,weight:.semibold));Text(store.todayAnswered>=store.state.dailyTarget ? "今日の目標を達成しました":"あと\(max(0,store.state.dailyTarget-store.todayAnswered))問で今日の目標").font(.subheadline).foregroundStyle(LearningSprintTheme.ink2)};Spacer()}.padding(18).background(LearningSprintTheme.card).clipShape(RoundedRectangle(cornerRadius:20)).shadow(color:.black.opacity(0.05),radius:8,y:4)}
    private var roundPicker:some View{HStack(spacing:8){ForEach(1...3,id:\.self){round in Button("第\(round)回"){store.selectRound(round)}.font(.subheadline.weight(.bold)).frame(maxWidth:.infinity,minHeight:44).background(store.selectedRound==round ? LearningSprintTheme.indigoSoft:LearningSprintTheme.card).foregroundStyle(store.selectedRound==round ? LearningSprintTheme.indigo:LearningSprintTheme.ink2).clipShape(RoundedRectangle(cornerRadius:12)).overlay(alignment:.topTrailing){if !store.isPremium&&round != 1{Image(systemName:"lock.fill").font(.caption2).padding(6).foregroundStyle(LearningSprintTheme.ink3)}}.accessibilityIdentifier("round\(round)Button")}}}
    private func subjectCard(_ subject:String)->some View{let total=store.questionCount(round:store.selectedRound,subject:subject),answered=store.answeredCount(round:store.selectedRound,subject:subject),completion=store.completionCount(round:store.selectedRound,subject:subject);return Button{store.startSubject(subject)}label:{HStack(spacing:14){ZStack{Circle().stroke(LearningSprintTheme.line,lineWidth:5);Circle().trim(from:0,to:total==0 ? 0:Double(answered)/Double(total)).stroke(LearningSprintTheme.indigo,style:StrokeStyle(lineWidth:5,lineCap:.round)).rotationEffect(.degrees(-90));Text(total==0 ? "0%":"\(Int((Double(answered)/Double(total)*100).rounded()))%").font(.caption2.bold())}.frame(width:48,height:48);VStack(alignment:.leading,spacing:4){Text(subject).font(.headline).foregroundStyle(LearningSprintTheme.ink);Text("\(total)問・解答済 \(answered)問・完答 \(completion)回").font(.caption).foregroundStyle(LearningSprintTheme.ink2)};Spacer();Image(systemName:"chevron.right").foregroundStyle(LearningSprintTheme.ink3)}.padding(14).background(LearningSprintTheme.card).clipShape(RoundedRectangle(cornerRadius:16))}.buttonStyle(.plain).frame(minHeight:44).accessibilityIdentifier("subject-\(subject)")}
    private func actionCard(title:String,subtitle:String,badge:String,icon:String,action:@escaping()->Void)->some View{Button(action:action){VStack(alignment:.leading,spacing:8){Image(systemName:icon).font(.title2).foregroundStyle(LearningSprintTheme.indigo);Text(title).font(.headline).foregroundStyle(LearningSprintTheme.ink);Text(subtitle).font(.caption).foregroundStyle(LearningSprintTheme.ink2);if !badge.isEmpty{Text(badge).font(.caption.bold()).foregroundStyle(LearningSprintTheme.vermilion)}}.frame(maxWidth:.infinity,minHeight:112,alignment:.leading).padding(14).background(LearningSprintTheme.card).clipShape(RoundedRectangle(cornerRadius:16))}.buttonStyle(.plain)}
    private func metric(_ title:String,_ value:String)->some View{VStack(spacing:4){Text(title).font(.caption).foregroundStyle(LearningSprintTheme.ink3);Text(value).font(.title3.bold()).foregroundStyle(LearningSprintTheme.indigo)}.frame(maxWidth:.infinity)}
}

struct MockListView:View{
    @EnvironmentObject private var store:KanriLearningStore
    var body:some View{ZStack{LearningSprintPaperBackground();ScrollView{VStack(alignment:.leading,spacing:16){Text("模擬試験").font(LearningSprintTheme.serif(36,weight:.bold));Text("3回分、各200問。本番の流れを整える。").foregroundStyle(LearningSprintTheme.ink2);ForEach(1...3,id:\.self){r in VStack(alignment:.leading,spacing:12){HStack{Text("第\(r)回").font(.title3.bold());Spacer();Text("\(store.answeredCount(round:r)) / 200問").foregroundStyle(LearningSprintTheme.ink3)};ProgressView(value:Double(store.answeredCount(round:r)),total:200).tint(LearningSprintTheme.indigo);Text("模試完答 \(store.mockCompletionCount(round:r))回").font(.caption).foregroundStyle(LearningSprintTheme.ink2);Button(store.isPremium ? "200問を開始":"プレミアムで解放"){store.startMock(r)}.buttonStyle(.borderedProminent).tint(LearningSprintTheme.indigo).frame(minHeight:44).accessibilityIdentifier("mockRound\(r)Button")}.padding(18).background(LearningSprintTheme.card).clipShape(RoundedRectangle(cornerRadius:18))};Text("模試中は正誤を表示せず、200問終了時にまとめて採点します。").font(.footnote).foregroundStyle(LearningSprintTheme.ink2)}.padding(20).padding(.bottom,28)}}.accessibilityIdentifier("mockView")}
}
