import SwiftUI
import LearningSprintCore

struct RootView: View {
    @EnvironmentObject var model: KangoshiAppModel
    @EnvironmentObject var purchase: PurchaseController
    @State private var tab = 0
    @State private var showPaywall = false

    var body: some View {
        TabView(selection:$tab) {
            HomeView(tab:$tab, showPaywall:$showPaywall).tabItem { Label("ホーム",systemImage:"house") }.tag(0)
            MockView(showPaywall:$showPaywall).tabItem { Label("模試",systemImage:"doc.text") }.tag(1)
            HistoryView(showPaywall:$showPaywall).tabItem { Label("記録",systemImage:"chart.bar") }.tag(2)
            SettingsView(showPaywall:$showPaywall).tabItem { Label("設定",systemImage:"gearshape") }.tag(3)
        }
        .tint(KSTheme.ai)
        .sheet(isPresented:$showPaywall) { PaywallView().environmentObject(purchase) }
        .fullScreenCover(isPresented:Binding(get:{ model.session != nil },set:{ if !$0 { model.closeSession() } })) {
            QuizFlowView().environmentObject(model).environmentObject(purchase)
        }
    }
}

struct HomeView: View {
    @EnvironmentObject var model: KangoshiAppModel
    @EnvironmentObject var purchase: PurchaseController
    @Binding var tab: Int
    @Binding var showPaywall: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing:16) {
                    PageHeader(eyebrow:"学びスプリント",title:"看護師国家試験",tagline:"今日も1問、力に変える。")
                    todayCard
                    Button { model.startDaily(isPremium:purchase.isPremium) } label: {
                        HStack { VStack(alignment:.leading,spacing:3) { Text("今日のスプリント").font(.headline); Text("\(model.learning.goal)問・短く集中").font(.caption).opacity(.85) }; Spacer(); Image(systemName:"arrow.right") }
                            .foregroundStyle(.white).padding(17).background(KSTheme.ai).clipShape(RoundedRectangle(cornerRadius:16))
                    }.padding(.horizontal,18)

                    actionButton(title:"苦手をつぶす",subtitle:"3回連続正解で卒業",icon:"repeat",count:"\(model.weakQuestions.count)問",premium:true) {
                        if purchase.isPremium { model.startWeak() } else { showPaywall=true }
                    }
                    actionButton(title:"模擬試験",subtitle:"第115・114・113回／各240問",icon:"doc.text.fill",count:"3回",premium:true) {
                        if purchase.isPremium { tab=1 } else { showPaywall=true }
                    }

                    if !purchase.isPremium {
                        VStack(alignment:.leading,spacing:10) {
                            HStack { Text("無料お試し").font(.subheadline.bold()); Spacer(); Text("各8問").font(.caption).foregroundStyle(KSTheme.tertiary) }
                            HStack(spacing:8) {
                                ForEach(["必修","一般","状況設定"],id:\.self) { c in
                                    Button(c) { model.startFreeSample(category:c) }.buttonStyle(.bordered).tint(KSTheme.ai)
                                }
                            }
                        }.padding(.horizontal,18)
                    }

                    VStack(alignment:.leading,spacing:10) {
                        HStack { Text("分野から解く").font(.subheadline.bold()); if !purchase.isPremium { PremiumBadge() }; Spacer() }
                        ForEach(model.majorSubjects,id:\.self) { major in
                            Button {
                                if purchase.isPremium { model.startMajor(major) } else { showPaywall=true }
                            } label: {
                                KSCard(content:HStack(spacing:12) {
                                    Text(String(major.prefix(1))).font(.caption.bold()).frame(width:34,height:34).background(KSTheme.aiSoft).foregroundStyle(KSTheme.ai).clipShape(RoundedRectangle(cornerRadius:10))
                                    VStack(alignment:.leading,spacing:4) { Text(major).font(.subheadline.bold()).foregroundStyle(KSTheme.ink); Text("解いた \(model.seen(in:major))/\(model.questions(in:major))問 ・ 苦手 \(model.weak(in:major))問").font(.caption).foregroundStyle(KSTheme.tertiary) }
                                    Spacer(); Image(systemName:"chevron.right").foregroundStyle(KSTheme.tertiary)
                                })
                            }.buttonStyle(.plain)
                        }
                    }.padding(.horizontal,18)

                    HStack(spacing:8) {
                        stat("\(model.learning.totalAnswers)","のべ回答")
                        stat("\(model.accuracy)%","正答率")
                        stat("\(model.learning.history.count)","学習回数")
                    }.padding(.horizontal,18).padding(.bottom,24)
                }
            }.background(KSTheme.paper.ignoresSafeArea()).toolbar(.hidden,for:.navigationBar)
        }
    }

    private var todayCard: some View {
        KSCard(content:HStack(spacing:18) {
            ZStack {
                Circle().stroke(KSTheme.line,lineWidth:8)
                Circle().trim(from:0,to:min(1,Double(model.todayCount())/Double(max(1,model.learning.goal)))).stroke(KSTheme.shu,style:StrokeStyle(lineWidth:8,lineCap:.round)).rotationEffect(.degrees(-90))
                VStack(spacing:1) { Text("\(model.todayCount())/\(model.learning.goal)").font(.subheadline.bold()); Text("今日").font(.caption2).foregroundStyle(KSTheme.tertiary) }
            }.frame(width:82,height:82)
            VStack(alignment:.leading,spacing:6) { Text("今日の学習").font(.subheadline.bold()); Text(model.todayCount() >= model.learning.goal ? "今日の目標は達成しました。" : "あと\(max(0,model.learning.goal-model.todayCount()))問で今日の目標です。").font(.caption).foregroundStyle(KSTheme.secondary); Text("正解 \(model.todayCorrect())問").font(.caption.bold()).foregroundStyle(KSTheme.shu).padding(.horizontal,8).padding(.vertical,5).background(KSTheme.shuSoft).clipShape(Capsule()) }
        }).padding(.horizontal,18)
    }

    private func actionButton(title:String,subtitle:String,icon:String,count:String,premium:Bool,action:@escaping()->Void) -> some View {
        Button(action:action) { KSCard(content:HStack(spacing:12) { Image(systemName:icon).frame(width:42,height:42).background(KSTheme.aiSoft).foregroundStyle(KSTheme.ai).clipShape(RoundedRectangle(cornerRadius:12)); VStack(alignment:.leading,spacing:3) { HStack { Text(title).font(.headline); if premium { PremiumBadge() } }; Text(subtitle).font(.caption).foregroundStyle(KSTheme.secondary) }; Spacer(); Text(count).font(.caption.bold()).foregroundStyle(KSTheme.tertiary) }) }.buttonStyle(.plain).padding(.horizontal,18)
    }
    private func stat(_ value:String,_ label:String)->some View { VStack(spacing:3){Text(value).font(.title3.bold()).foregroundStyle(KSTheme.ai);Text(label).font(.caption2).foregroundStyle(KSTheme.tertiary)}.frame(maxWidth:.infinity).padding(.vertical,13).background(KSTheme.card).overlay(RoundedRectangle(cornerRadius:12).stroke(KSTheme.line)).clipShape(RoundedRectangle(cornerRadius:12)) }
}

struct MockView: View {
    @EnvironmentObject var model: KangoshiAppModel
    @EnvironmentObject var purchase: PurchaseController
    @Binding var showPaywall: Bool
    var body: some View {
        NavigationStack { ScrollView { VStack(spacing:16) {
            PageHeader(eyebrow:"模擬試験",title:"本番形式",tagline:"第115・114・113回を、必修・一般・状況設定ごとに解けます。")
            if !purchase.isPremium { KSCard(content:VStack(alignment:.leading,spacing:9){HStack{PremiumBadge();Text("本番形式はプレミアム").font(.headline)};Text("3試験回×240問の公式構成と特殊採点ルールを反映します。").font(.caption).foregroundStyle(KSTheme.secondary);Button("プレミアムを見る"){showPaywall=true}.buttonStyle(.borderedProminent).tint(KSTheme.ai)}).padding(.horizontal,18) }
            ForEach([115,114,113],id:\.self) { exam in
                VStack(alignment:.leading,spacing:9) { HStack { Text("第\(exam)回").font(.headline); Spacer(); Text("240問").font(.caption).foregroundStyle(KSTheme.tertiary) }
                    ForEach([("必修",50),("一般",130),("状況設定",60)],id:\.0) { c,n in
                        Button { if purchase.isPremium { model.startMock(exam:exam,category:c) } else { showPaywall=true } } label: {
                            HStack { Text(c).font(.subheadline.bold()); Spacer(); Text("\(n)問").font(.caption).foregroundStyle(KSTheme.tertiary); Image(systemName:purchase.isPremium ? "chevron.right" : "lock.fill").foregroundStyle(KSTheme.ai) }
                                .padding(14).background(KSTheme.card).overlay(RoundedRectangle(cornerRadius:12).stroke(KSTheme.line)).clipShape(RoundedRectangle(cornerRadius:12))
                        }.buttonStyle(.plain)
                    }
                }.padding(.horizontal,18)
            }
        }.padding(.bottom,24) }.background(KSTheme.paper.ignoresSafeArea()).toolbar(.hidden,for:.navigationBar) }
    }
}

struct HistoryView: View {
    @EnvironmentObject var model: KangoshiAppModel
    @EnvironmentObject var purchase: PurchaseController
    @Binding var showPaywall: Bool
    var body: some View {
        NavigationStack { ScrollView { VStack(spacing:16) {
            PageHeader(eyebrow:"学習記録",title:"積み上げ",tagline:"短い反復を、そのまま弱点整理につなげます。")
            HStack(spacing:8) { miniStat("\(model.learning.totalAnswers)","回答"); miniStat("\(model.accuracy)%","正答率"); miniStat("\(model.weakQuestions.count)","苦手") }.padding(.horizontal,18)
            if purchase.isPremium {
                KSCard(content:VStack(alignment:.leading,spacing:10){Text("苦手一覧").font(.headline); if model.weakQuestions.isEmpty { Text("苦手はまだありません。").font(.caption).foregroundStyle(KSTheme.tertiary) } else { ForEach(model.weakQuestions.prefix(8)) { q in HStack { Text(q.question).font(.caption).lineLimit(2); Spacer(); let s=model.learning.weak[q.id]?.streak ?? 0; Text("\(s)/3").font(.caption.bold()).foregroundStyle(KSTheme.shu) } } }}).padding(.horizontal,18)
                KSCard(content:VStack(alignment:.leading,spacing:10){Text("直近のスプリント").font(.headline); ForEach(model.learning.history.prefix(15)) { h in HStack { VStack(alignment:.leading){Text(h.title).font(.caption.bold());Text(h.date.formatted(date:.numeric,time:.shortened)).font(.caption2).foregroundStyle(KSTheme.tertiary)};Spacer();Text("\(h.correct)/\(h.scoredTotal)").font(.subheadline.bold()).foregroundStyle(KSTheme.ai) } }}).padding(.horizontal,18)
            } else {
                KSCard(content:VStack(alignment:.leading,spacing:9){HStack{PremiumBadge();Text("詳細記録").font(.headline)};Text("苦手一覧・履歴・詳細分析はプレミアムで利用できます。").font(.caption).foregroundStyle(KSTheme.secondary);Button("プレミアムを見る"){showPaywall=true}.buttonStyle(.bordered).tint(KSTheme.ai)}).padding(.horizontal,18)
            }
        }.padding(.bottom,24) }.background(KSTheme.paper.ignoresSafeArea()).toolbar(.hidden,for:.navigationBar) }
    }
    private func miniStat(_ v:String,_ l:String)->some View { VStack(spacing:3){Text(v).font(.title3.bold()).foregroundStyle(KSTheme.ai);Text(l).font(.caption2).foregroundStyle(KSTheme.tertiary)}.frame(maxWidth:.infinity).padding(14).background(KSTheme.card).overlay(RoundedRectangle(cornerRadius:12).stroke(KSTheme.line)).clipShape(RoundedRectangle(cornerRadius:12)) }
}

struct SettingsView: View {
    @EnvironmentObject var model: KangoshiAppModel
    @EnvironmentObject var purchase: PurchaseController
    @Binding var showPaywall: Bool
    @State private var showReset=false
    var body: some View {
        NavigationStack { ScrollView { VStack(spacing:14) {
            PageHeader(eyebrow:"設定",title:"学びかた",tagline:"自分に合うペースだけ調整します。")
            settingCard("1日の目標") { Picker("目標",selection:Binding(get:{model.learning.goal},set:{model.setGoal($0)})) { ForEach([4,8,16],id:\.self){Text("\($0)問").tag($0)} }.pickerStyle(.segmented) }
            settingCard("文字サイズ") { Picker("文字",selection:Binding(get:{model.learning.fontScale},set:{model.setFontScale($0)})) { Text("標準").tag("normal");Text("大").tag("large");Text("特大").tag("xlarge") }.pickerStyle(.segmented) }
            settingCard("プレミアム") { VStack(alignment:.leading,spacing:10){HStack{Text(purchase.isPremium ? "利用中" : "無料プラン").font(.subheadline.bold());Spacer();if purchase.isPremium {Image(systemName:"checkmark.seal.fill").foregroundStyle(KSTheme.green)}};Button(purchase.isPremium ? "購入情報を確認" : "プレミアムを見る"){showPaywall=true}.buttonStyle(.bordered).tint(KSTheme.ai);Button("購入を復元"){Task{await purchase.restore()}}.font(.subheadline.bold()).foregroundStyle(KSTheme.ai)} }
            settingCard("この教材について") { Text("看護師国家試験｜学びスプリント。第115・114・113回の720問、11科目分類、状況設定60症例、公式特殊採点を収録しています。").font(.caption).foregroundStyle(KSTheme.secondary) }
            settingCard("学習記録リセット") { Button("すべての学習記録を削除",role:.destructive){showReset=true}.font(.subheadline.bold()) }
        }.padding(.bottom,24) }.background(KSTheme.paper.ignoresSafeArea()).toolbar(.hidden,for:.navigationBar).alert("学習記録を削除しますか？",isPresented:$showReset){Button("削除",role:.destructive){model.resetLearning()};Button("キャンセル",role:.cancel){}} }
    }
    private func settingCard<Content:View>(_ title:String,@ViewBuilder content:()->Content)->some View { KSCard(content:VStack(alignment:.leading,spacing:10){Text(title).font(.headline);content()}).padding(.horizontal,18) }
}
