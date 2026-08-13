import SwiftUI
import UniformTypeIdentifiers

struct HistoryView: View {
    @EnvironmentObject private var store: LearningStore
    private let heatColumns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
    var body: some View {
        ZStack(alignment: .top) {
            AppTheme.paper.ignoresSafeArea(); PaperGridBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    PageHeader(title: "記録", subtitle: "反復量と弱点の変化を、短く確認します。")
                    HStack(spacing: 16) {
                        ProgressRing(progress: Double(store.overallAccuracy) / 100, value: "\(store.overallAccuracy)%", caption: "正答率", size: 104)
                        VStack(spacing: 10) { historyStat("\(store.totalAnswered)", "回答"); historyStat("\(store.seenCount)", "既習"); historyStat("\(store.weakQuestions.count)", "苦手") }
                    }.padding(16).appCard()
                    Text("分野別").appSerif(19, weight: .bold).foregroundStyle(AppTheme.ink)
                    VStack(spacing: 13) {
                        ForEach(store.repository.domains, id: \.self) { domain in
                            let stat = store.domainStats(domain)
                            VStack(spacing: 6) {
                                HStack { Text(domain).appSans(13, weight: .bold).foregroundStyle(AppTheme.ink); Spacer(); Text(stat.answered == 0 ? "未回答" : "\(stat.accuracy)%").appSans(11, weight: .bold).foregroundStyle(AppTheme.ink3) }
                                GeometryReader { proxy in ZStack(alignment: .leading) { Capsule().fill(AppTheme.aiSoft); Capsule().fill(AppTheme.ai).frame(width: proxy.size.width * CGFloat(stat.accuracy) / 100) } }.frame(height: 8)
                            }
                        }
                    }.padding(16).appCard()
                    Text("5週間").appSerif(19, weight: .bold).foregroundStyle(AppTheme.ink)
                    LazyVGrid(columns: heatColumns, spacing: 4) { ForEach(Array(store.heatmap().enumerated()), id: \.offset) { _, item in RoundedRectangle(cornerRadius: 4, style: .continuous).fill(heatColor(item.1)).aspectRatio(1, contentMode: .fit).accessibilityLabel("\(item.0.formatted(date: .abbreviated, time: .omitted))、\(item.1)問") } }.padding(14).appCard()
                    HStack { Text("苦手一覧").appSerif(19, weight: .bold).foregroundStyle(AppTheme.ink); Spacer(); Text("3連続正解で解除").appSans(10, weight: .bold).foregroundStyle(AppTheme.ink3) }
                    if store.weakQuestions.isEmpty {
                        Text("現在の苦手はありません。").appSans(13).foregroundStyle(AppTheme.ink2).frame(maxWidth: .infinity, minHeight: 64, alignment: .leading).padding(.horizontal, 16).appCard()
                    } else {
                        ForEach(store.weakQuestions) { q in
                            Button { store.retryQuestions([q.id], title: q.topic) } label: {
                                HStack { VStack(alignment: .leading, spacing: 4) { Text(q.topic).appSans(14, weight: .bold).foregroundStyle(AppTheme.ink); Text(q.domain).appSans(10).foregroundStyle(AppTheme.ink3) }; Spacer(); Text("連続 \(store.state.weak[q.id]?.streak ?? 0)/3").appSans(11, weight: .bold).foregroundStyle(AppTheme.shu); Image(systemName: "chevron.right").foregroundStyle(AppTheme.ink3) }.padding(14).frame(minHeight: 54)
                            }.buttonStyle(.plain).appCard()
                        }
                    }
                    Spacer(minLength: 20)
                }.padding(.horizontal, 18).frame(maxWidth: 520).frame(maxWidth: .infinity)
            }
        }.accessibilityIdentifier("history.screen")
    }
    private func historyStat(_ value:String,_ label:String)->some View{HStack{Text(value).appSerif(19,weight:.bold).foregroundStyle(AppTheme.ink);Spacer();Text(label).appSans(11,weight:.bold).foregroundStyle(AppTheme.ink3)}}
    private func heatColor(_ count:Int)->Color{if count>=16{return AppTheme.midori};if count>=8{return AppTheme.midori.opacity(0.75)};if count>=4{return AppTheme.midori.opacity(0.5)};if count>=1{return AppTheme.midori.opacity(0.25)};return AppTheme.line}
}

struct SettingsView: View {
    @EnvironmentObject private var store: LearningStore
    @EnvironmentObject private var purchases: PremiumPurchaseStore
    @State private var exportDocument: BackupDocument?
    @State private var showExporter=false
    @State private var showImporter=false
    @State private var importError:String?
    var body: some View {
        ZStack(alignment:.top){
            AppTheme.paper.ignoresSafeArea();PaperGridBackground()
            ScrollView{
                VStack(alignment:.leading,spacing:18){
                    PageHeader(title:"設定",subtitle:"学習量・文字・試験日・バックアップを管理します。")
                    settingsSection("1日の問題数") { Picker("1日の問題数",selection:Binding(get:{store.settings.dailyGoal},set:{store.setDailyGoal($0)})){ForEach([4,8,16],id:\.self){Text("\($0)問").tag($0)}}.pickerStyle(.segmented).accessibilityIdentifier("settings.dailyGoal") }
                    settingsSection("文字サイズ") { Picker("文字サイズ",selection:Binding(get:{store.settings.fontSize},set:{store.setFontSize($0)})){ForEach(FontSizePreference.allCases){Text($0.title).tag($0)}}.pickerStyle(.segmented) }
                    settingsSection("試験日") {
                        Toggle("試験日を設定",isOn:Binding(get:{store.settings.examDate != nil},set:{enabled in store.setExamDate(enabled ? (Calendar.current.date(byAdding:.month,value:3,to:Date()) ?? Date()) : nil)})).tint(AppTheme.ai)
                        if let date=store.settings.examDate{DatePicker("試験日",selection:Binding(get:{date},set:{store.setExamDate($0)}),displayedComponents:.date).datePickerStyle(.compact)}
                    }
                    settingsSection("JSONバックアップ") {
                        VStack(spacing:10){
                            Button{do{exportDocument=BackupDocument(data:try store.exportBackup());showExporter=true}catch{importError=error.localizedDescription}}label:{settingsAction("square.and.arrow.up","JSONを書き出す")}.buttonStyle(.plain)
                            Button{showImporter=true}label:{settingsAction("square.and.arrow.down","JSONを読み込む")}.buttonStyle(.plain)
                        }
                    }
                    if purchases.isConfigured { settingsSection("プレミアム") { VStack(alignment:.leading,spacing:10){ if purchases.isPremium { Label("購入済み",systemImage:"checkmark.seal.fill").foregroundStyle(AppTheme.midori) } else if let price=purchases.displayPrice { HStack{Text("買い切り");Spacer();Text(price).foregroundStyle(AppTheme.ai)}.appSans(13,weight:.bold); Button{Task{await purchases.purchase()}}label:{settingsAction("cart","プレミアムを購入")}.buttonStyle(.plain) }; Button{Task{await purchases.restorePurchases()}}label:{settingsAction("arrow.clockwise","購入を復元")}.buttonStyle(.plain); if let message=purchases.message{Text(message).appSans(11).foregroundStyle(AppTheme.ink2)} } } }
                    settingsSection("このアプリ") {
                        VStack(alignment:.leading,spacing:10){ infoRow("コンテンツ",store.repository.payload.contentVersion);infoRow("監査基準日",store.repository.payload.sourceCheckedAt);infoRow("収録問題","240問（令和8・7・6年）");infoRow("構成","各年度 行政法規40＋鑑定理論40");infoRow("課金",purchases.isConfigured ? "StoreKit 2" : "Product ID 未設定（Release Gate）");infoRow("Bundle ID","jp.allsunday1122.kanteishishortanswer") }
                    }
                    Text("本アプリは国土交通省・土地鑑定委員会の公式アプリではありません。収録問題は国土交通省が公表した令和8・7・6年の不動産鑑定士試験短答式試験問題を、公共データ利用規約（PDL1.0）に基づきアプリ表示用に構造化して収録しています。").appSans(11).foregroundStyle(AppTheme.ink3).padding(.bottom,18)
                }.padding(.horizontal,18).frame(maxWidth:520).frame(maxWidth:.infinity)
            }
        }
        .fileExporter(isPresented:$showExporter,document:exportDocument,contentType:.json,defaultFilename:"kanteishi-shortanswer-backup"){if case .failure(let error)=$0{importError=error.localizedDescription}}
        .fileImporter(isPresented:$showImporter,allowedContentTypes:[.json]){result in do{let url=try result.get();let scoped=url.startAccessingSecurityScopedResource();defer{if scoped{url.stopAccessingSecurityScopedResource()}};try store.importBackup(Data(contentsOf:url))}catch{importError=error.localizedDescription}}
        .alert("バックアップ",isPresented:Binding(get:{importError != nil || store.importMessage != nil},set:{if !$0{importError=nil;store.clearImportMessage()}})){Button("OK",role:.cancel){importError=nil;store.clearImportMessage()}}message:{Text(importError ?? store.importMessage ?? "")}
        .accessibilityIdentifier("settings.screen")
    }
    @ViewBuilder private func settingsSection<Content:View>(_ title:String,@ViewBuilder content:()->Content)->some View{VStack(alignment:.leading,spacing:10){Text(title).appSerif(18,weight:.bold).foregroundStyle(AppTheme.ink);content()}.padding(16).appCard()}
    private func settingsAction(_ image:String,_ title:String)->some View{HStack{Image(systemName:image).foregroundStyle(AppTheme.ai).frame(width:24);Text(title).appSans(14,weight:.bold).foregroundStyle(AppTheme.ink);Spacer();Image(systemName:"chevron.right").foregroundStyle(AppTheme.ink3)}.frame(minHeight:44).contentShape(Rectangle())}
    private func infoRow(_ label:String,_ value:String)->some View{HStack(alignment:.top){Text(label).appSans(11,weight:.bold).foregroundStyle(AppTheme.ink3).frame(width:90,alignment:.leading);Text(value).appSans(12).foregroundStyle(AppTheme.ink).frame(maxWidth:.infinity,alignment:.leading)}}
}
