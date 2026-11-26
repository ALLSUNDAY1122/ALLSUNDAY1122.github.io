import SwiftUI

enum ETheme {
    static let paper = Color(red:0.97,green:0.95,blue:0.91)
    static let card = Color.white
    static let ink = Color(red:0.12,green:0.16,blue:0.22)
    static let blue = Color(red:0.18,green:0.30,blue:0.45)
    static let red = Color(red:0.82,green:0.27,blue:0.18)
    static let line = Color(red:0.89,green:0.86,blue:0.80)
}
struct RootView: View {
    @EnvironmentObject var model: StudyModel
    var body: some View {
        TabView(selection:$model.tab) {
            HomeView().tabItem { Label("ホーム",systemImage:"house.fill") }.tag(0)
            MockView().tabItem { Label("模試",systemImage:"doc.text") }.tag(1)
            RecordView().tabItem { Label("記録",systemImage:"chart.bar") }.tag(2)
            SettingsView().tabItem { Label("設定",systemImage:"gearshape") }.tag(3)
        }.tint(ETheme.blue).fullScreenCover(isPresented:$model.showQuestion) { QuizView().environmentObject(model) }
    }
}
struct PageTitle: View {
    let title:String; let subtitle:String
    var body: some View { VStack(alignment:.leading,spacing:5) { Text("学びスプリント").font(.caption.bold()).tracking(2).foregroundStyle(.secondary); Text(title).font(.system(size:27,weight:.bold,design:.serif)); Text(subtitle).font(.subheadline).foregroundStyle(.secondary) }.frame(maxWidth:.infinity,alignment:.leading).padding(.horizontal,18).padding(.top,20) }
}
struct Panel<Content:View>: View {
    @ViewBuilder var content:Content
    var body: some View { content.padding(16).frame(maxWidth:.infinity,alignment:.leading).background(ETheme.card).clipShape(RoundedRectangle(cornerRadius:18)).overlay(RoundedRectangle(cornerRadius:18).stroke(ETheme.line)) }
}
struct HomeView: View {
    @EnvironmentObject var model:StudyModel
    var body: some View {
        NavigationStack { ScrollView { VStack(spacing:16) {
            PageTitle(title:"第二種電気工事士",subtitle:"今日も8問、着実に。")
            Panel { HStack(spacing:18) { ZStack { Circle().stroke(ETheme.line,lineWidth:9); Circle().trim(from:0,to:CGFloat(model.done)/CGFloat(model.goal)).stroke(ETheme.red,style:StrokeStyle(lineWidth:9,lineCap:.round)).rotationEffect(.degrees(-90)); VStack { Text("\(model.done)/\(model.goal)").font(.headline); Text("今日の目標").font(.caption2).foregroundStyle(.secondary) }.frame(width:88,height:88) }; VStack(alignment:.leading,spacing:5) { Text("今日の学習").font(.headline); Text("目標まであと \(max(0,model.goal-model.done)) 問").font(.subheadline).foregroundStyle(.secondary); Text("学習を継続しましょう").font(.caption).foregroundStyle(.secondary) } } }
            Button { model.start(8) } label: { HStack { VStack(alignment:.leading) { Text("8問スプリント").font(.headline); Text("短く集中して理解を積み上げる").font(.caption).opacity(0.85) }; Spacer(); Image(systemName:"arrow.right") }.foregroundStyle(.white).padding(18).background(ETheme.blue).clipShape(RoundedRectangle(cornerRadius:16)) }.buttonStyle(.plain)
            Button { model.start(8) } label: { Panel { HStack { Image(systemName:"repeat").font(.title2).foregroundStyle(ETheme.red); VStack(alignment:.leading) { Text("苦手をつぶす").font(.headline); Text("3回連続正解で卒業").font(.caption).foregroundStyle(.secondary) }; Spacer(); Text("\(model.weakStreak.filter{$0.value < 3}.count)問").font(.caption.bold()) } } }.buttonStyle(.plain)
            Button { model.tab=1 } label: { Panel { Label("模擬試験",systemImage:"doc.text").font(.headline); Text("年度別・50問の模試").font(.caption).foregroundStyle(.secondary).padding(.top,4) } }.buttonStyle(.plain)
            VStack(alignment:.leading,spacing:10) { Text("分野から解く").font(.headline); ForEach(model.subjects,id:\.self) { s in Button { model.start(8) } label: { HStack { Text(s).foregroundStyle(ETheme.ink); Spacer(); Image(systemName:"chevron.right").foregroundStyle(.secondary) }.padding(14).background(.white).clipShape(RoundedRectangle(cornerRadius:12)) }.buttonStyle(.plain) } }
        }.padding(.horizontal,16).padding(.bottom,24) }.background(ETheme.paper.ignoresSafeArea()) }
    }
}
struct MockView: View {
    @EnvironmentObject var model:StudyModel
    var body: some View { NavigationStack { ScrollView { VStack(spacing:14) { PageTitle(title:"模擬試験",subtitle:"年度・試験回を選択") ; ForEach(["2026年度 上期（ダミー）","2026年度 下期（ダミー）","2025年度 上期（ダミー）","2025年度 下期（ダミー）"],id:\.self) { name in Button { model.start(8) } label: { Panel { HStack { VStack(alignment:.leading) { Text(name).font(.headline); Text("50問・120分（表示仕様の仮値）").font(.caption).foregroundStyle(.secondary) }; Spacer(); Image(systemName:"play.circle.fill").font(.title2) } } }.buttonStyle(.plain) } }.padding() }.background(ETheme.paper.ignoresSafeArea()) }.navigationTitle("模試") }
}
struct RecordView: View {
    @EnvironmentObject var model:StudyModel
    var body: some View { NavigationStack { ScrollView { VStack(spacing:14) { PageTitle(title:"学習記録",subtitle:"積み上げを確認") ; Panel { HStack { metric("解答数","\(model.completed)"); Spacer(); metric("正解数","\(model.correct)"); Spacer(); metric("正答率",model.completed == 0 ? "—" : "\(Int(Double(model.correct)/Double(model.completed)*100))%") } }; Panel { Text("分野別進捗").font(.headline); ForEach(model.subjects,id:\.self) { Text($0).font(.subheadline).padding(.vertical,5) } } }.padding() }.background(ETheme.paper.ignoresSafeArea()) }.navigationTitle("記録") }
    func metric(_ title:String,_ value:String)->some View { VStack { Text(value).font(.title2.bold()); Text(title).font(.caption).foregroundStyle(.secondary) } }
}
struct SettingsView: View {
    @EnvironmentObject var model:StudyModel
    var body: some View { NavigationStack { Form { Section("1日の目標") { Picker("問題数",selection:$model.goal) { Text("4問").tag(4); Text("8問").tag(8); Text("16問").tag(16) }.pickerStyle(.segmented) }; Section("教材情報") { Text("現在はUI確認用のダミー問題のみです。公式問題・図版は未収録です。"); Text("Q0：利用条件の照会回答待ち") }; Section("表示") { Text("文字サイズ設定は次工程で実装") } }.navigationTitle("設定") } }
}
