import SwiftUI
import UniformTypeIdentifiers

enum ETheme {
    static let paper=Color(hex:0xF7F3EA), paperLine=Color(hex:0xE3DCCD), card=Color(hex:0xFFFDF9)
    static let ink=Color(hex:0x1C2331), ink2=Color(hex:0x4A5468), muted=Color(hex:0x8B8577)
    static let blue=Color(hex:0x2F4A6D), blueSoft=Color(hex:0xEAEFF6), red=Color(hex:0xD8452C)
    static let redSoft=Color(hex:0xFDEEEA), green=Color(hex:0x2F7D5C), greenSoft=Color(hex:0xEAF6F0)
    static let gold=Color(hex:0xB5872B), line=Color(hex:0xECE4D6)
}
extension Color {
    init(hex:Int) { self.init(.sRGB,red:Double((hex>>16)&255)/255,green:Double((hex>>8)&255)/255,blue:Double(hex&255)/255,opacity:1) }
}
struct PaperGrid: View {
    var body: some View {
        GeometryReader { geo in
            Path { p in
                stride(from:0.0,through:geo.size.width,by:28).forEach { x in
                    p.move(to:CGPoint(x:x,y:0)); p.addLine(to:CGPoint(x:x,y:geo.size.height))
                }
                stride(from:0.0,through:geo.size.height,by:28).forEach { y in
                    p.move(to:CGPoint(x:0,y:y)); p.addLine(to:CGPoint(x:geo.size.width,y:y))
                }
            }.stroke(ETheme.paperLine.opacity(0.55),lineWidth:0.55)
                .mask(LinearGradient(colors:[.black,.black.opacity(0)],startPoint:.top,endPoint:.bottom))
        }.frame(maxWidth:.infinity,maxHeight:.infinity).allowsHitTesting(false)
    }
}
struct RootView: View {
    @EnvironmentObject var model:StudyModel
    var body: some View {
        TabView(selection:$model.tab) {
            HomeView().tabItem { Label("ホーム",systemImage:"house.fill") }.tag(0)
            MockView().tabItem { Label("模試",systemImage:"doc.text") }.tag(1)
            RecordView().tabItem { Label("記録",systemImage:"chart.bar") }.tag(2)
            SettingsView().tabItem { Label("設定",systemImage:"gearshape") }.tag(3)
        }.tint(ETheme.blue).toolbarBackground(ETheme.card,for:.tabBar).toolbarBackground(.visible,for:.tabBar)
        .fullScreenCover(isPresented:$model.showQuestion) { QuizView().environmentObject(model) }
        .preferredColorScheme(.light)
    }
}
struct PageTitle: View {
    let title:String; let subtitle:String
    var body: some View { VStack(alignment:.leading,spacing:6) {
        HStack(spacing:8) { RoundedRectangle(cornerRadius:1).fill(ETheme.red).frame(width:16,height:2); Text("学びスプリント").font(.system(size:11,weight:.heavy,design:.rounded)).tracking(2.2).foregroundStyle(ETheme.muted) }
        Text(title).font(.system(size:29,weight:.bold,design:.serif)).foregroundStyle(ETheme.ink)
        Text(subtitle).font(.system(size:13)).foregroundStyle(ETheme.ink2)
    }.frame(maxWidth:.infinity,alignment:.leading).padding(.horizontal,18).padding(.top,22) }
}
struct Panel<Content:View>: View {
    @ViewBuilder var content:Content
    var body: some View { content.padding(16).frame(maxWidth:.infinity,alignment:.leading).background(ETheme.card).clipShape(RoundedRectangle(cornerRadius:16)).overlay(RoundedRectangle(cornerRadius:16).stroke(ETheme.line)).shadow(color:.black.opacity(0.035),radius:8,y:3) }
}
struct ProgressRing: View {
    let value:Double; let label:String
    var body: some View {
        ZStack {
            Circle().stroke(Color(hex:0xEFE8DA),lineWidth:8)
            Circle().trim(from:0,to:min(1,max(0,value))).stroke(ETheme.red,style:StrokeStyle(lineWidth:8,lineCap:.round)).rotationEffect(.degrees(-90))
            VStack(spacing:1) { Text(label).font(.system(size:16,weight:.bold,design:.rounded)).foregroundStyle(ETheme.ink); Text("今日").font(.system(size:9,weight:.bold)).foregroundStyle(ETheme.muted) }
        }.frame(width:82,height:82).accessibilityElement(children:.ignore).accessibilityLabel("今日の進捗 \(label)")
    }
}
struct HomeView: View {
    @EnvironmentObject var model:StudyModel
    private var today:Int { min(model.done,model.goal) }
    var body: some View {
        NavigationStack { ZStack(alignment:.top) { ETheme.paper.ignoresSafeArea(); PaperGrid().ignoresSafeArea()
            ScrollView { VStack(spacing:16) {
                PageTitle(title:"第二種電気工事士",subtitle:"今日も1問、力に変える。")
                Panel { HStack(spacing:16) {
                    ProgressRing(value:Double(today)/Double(max(1,model.goal)),label:"\(today)/\(model.goal)")
                    VStack(alignment:.leading,spacing:5) {
                        Text("今日の学習").font(.system(size:16,weight:.bold))
                        Text(today >= model.goal ? "今日の目標は達成しました。" : "あと\(model.goal-today)問で今日の目標に届きます。").font(.system(size:12)).foregroundStyle(ETheme.ink2)
                        Text("累計 \(model.completed)問　・　連続 \(model.streakDays)日").font(.system(size:11,weight:.semibold)).foregroundStyle(ETheme.muted)
                    }
                } }
                Button { model.start(model.goal) } label: { HStack { VStack(alignment:.leading,spacing:4) { Text("今日のスプリント").font(.system(size:16,weight:.heavy)); Text("\(model.goal)問・短く集中して理解を積み上げる").font(.system(size:11)) }; Spacer(); Image(systemName:"arrow.right").font(.title3.bold()) }.foregroundStyle(.white).padding(18).background(LinearGradient(colors:[Color(hex:0x35527A),Color(hex:0x233A58)],startPoint:.topLeading,endPoint:.bottomTrailing)).clipShape(RoundedRectangle(cornerRadius:16)).shadow(color:ETheme.blue.opacity(0.18),radius:10,y:5) }.buttonStyle(.plain)
                Button { model.start(8,weakOnly:true) } label: { Panel { HStack(spacing:12) { Image(systemName:"repeat").font(.title2).foregroundStyle(ETheme.red).frame(width:42,height:42).background(ETheme.redSoft).clipShape(RoundedRectangle(cornerRadius:12)); VStack(alignment:.leading,spacing:3) { Text("苦手をつぶす").font(.system(size:15,weight:.bold)); Text("3回連続正解で卒業").font(.system(size:11)).foregroundStyle(ETheme.muted) }; Spacer(); Text("\(model.weakQuestions.count)問").font(.system(size:12,weight:.bold)).foregroundStyle(ETheme.red).padding(.horizontal,10).padding(.vertical,6).background(ETheme.redSoft).clipShape(Capsule()) } } }.buttonStyle(.plain)
                Button { model.tab=1 } label: { Panel { Label("模擬試験",systemImage:"doc.text").font(.system(size:15,weight:.bold)); Text("年度別・公式問題50問単位").font(.system(size:11)).foregroundStyle(ETheme.muted).padding(.top,4) } }.buttonStyle(.plain)
                VStack(alignment:.leading,spacing:10) { Text("分野から解く").font(.system(size:17,weight:.bold,design:.serif)); ForEach(model.subjects,id:\.self) { s in Button { model.start(8, subject:s) } label: { HStack { Text(s).font(.system(size:13,weight:.semibold)).foregroundStyle(ETheme.ink); Spacer(); Image(systemName:"chevron.right").foregroundStyle(ETheme.muted) }.padding(14).background(ETheme.card).clipShape(RoundedRectangle(cornerRadius:12)).overlay(RoundedRectangle(cornerRadius:12).stroke(ETheme.line)) }.buttonStyle(.plain) } }
                Panel { HStack { smallStat("のべ回答","\(model.completed)"); Spacer(); smallStat("正答率",model.completed == 0 ? "—" : "\(model.accuracy)%"); Spacer(); smallStat("学習日数","\(model.studyDays.count)日") } }
            }.padding(.horizontal,16).padding(.bottom,22).frame(maxWidth:520).frame(maxWidth:.infinity) }
        }.navigationBarHidden(true) }
    }
    func smallStat(_ title:String,_ value:String)->some View { VStack(alignment:.leading,spacing:3) { Text(value).font(.system(size:19,weight:.heavy,design:.rounded)).foregroundStyle(ETheme.blue); Text(title).font(.system(size:10,weight:.medium)).foregroundStyle(ETheme.muted) } }
}
struct MockView: View {
    @EnvironmentObject var model:StudyModel
    var body: some View { NavigationStack { ZStack { ETheme.paper.ignoresSafeArea(); ScrollView { VStack(spacing:14) {
        PageTitle(title:"本番形式",subtitle:"試験回ごとに、科目別のセットを準備します。")
        ForEach(model.examSets) { examSet in
            Panel { VStack(alignment:.leading,spacing:10) {
                Text(examSet.title).font(.system(size:17,weight:.bold,design:.serif))
                Text("\(examSet.questionCount)問・転記済み／独立監査未完了").font(.system(size:11)).foregroundStyle(ETheme.muted)
                Button { model.start(examPrefix:examSet.id) } label: { Label("この試験回を解く",systemImage:"play.circle").font(.system(size:12,weight:.bold)).foregroundStyle(ETheme.blue) }
            } }
        }
    }.padding(.horizontal,16).padding(.bottom,24).frame(maxWidth:520).frame(maxWidth:.infinity) } } }.navigationBarHidden(true) }
}
struct RecordView: View {
    @EnvironmentObject var model:StudyModel
    var body: some View { NavigationStack { ZStack { ETheme.paper.ignoresSafeArea(); ScrollView { VStack(spacing:14) {
        PageTitle(title:"積み上げ",subtitle:"短い反復が、そのまま形になります。")
        Panel { HStack { metric("のべ回答","\(model.completed)"); Spacer(); metric("正解数","\(model.correct)"); Spacer(); metric("連続日数","\(model.streakDays)") } }
        Panel { HStack(spacing:16) { ZStack { Circle().stroke(Color(hex:0xEFE8DA),lineWidth:10); Circle().trim(from:0,to:Double(model.accuracy)/100).stroke(ETheme.blue,style:StrokeStyle(lineWidth:10,lineCap:.round)).rotationEffect(.degrees(-90)); Text(model.completed == 0 ? "—" : "\(model.accuracy)%").font(.system(size:17,weight:.bold,design:.rounded)) }.frame(width:96,height:96); VStack(alignment:.leading,spacing:4) { Text("全体の正答率").font(.system(size:14,weight:.bold)); Text("正解 \(model.correct) / 回答 \(model.completed)").font(.system(size:11)).foregroundStyle(ETheme.muted) } } }
        Panel { VStack(alignment:.leading,spacing:10) { Text("直近35日の学習").font(.system(size:16,weight:.bold,design:.serif)); Heatmap(days:model.studyDays) } }
        Panel { VStack(alignment:.leading,spacing:9) { Text("苦手問題").font(.system(size:16,weight:.bold)); if model.weakQuestions.isEmpty { Text("現在、苦手問題はありません").font(.system(size:12)).foregroundStyle(ETheme.muted) }; ForEach(model.weakQuestions) { q in HStack { Text(q.prompt).font(.system(size:11)).lineLimit(2); Spacer(); Text("\(model.weakStreak[q.id] ?? 0)/3").font(.system(size:11,weight:.bold)).foregroundStyle(ETheme.red) } } } }
        Panel { VStack(alignment:.leading,spacing:9) { Text("卒業した問題").font(.system(size:16,weight:.bold)); if model.graduatedQuestions.isEmpty { Text("卒業した問題はまだありません").font(.system(size:12)).foregroundStyle(ETheme.muted) }; ForEach(model.graduatedQuestions) { q in Text(q.prompt).font(.system(size:11)).lineLimit(2) } } }
    }.padding(.horizontal,16).padding(.bottom,24).frame(maxWidth:520).frame(maxWidth:.infinity) } } }.navigationBarHidden(true) }
    func metric(_ title:String,_ value:String)->some View { VStack { Text(value).font(.system(size:21,weight:.heavy,design:.rounded)); Text(title).font(.system(size:10)).foregroundStyle(ETheme.muted) } }
}
struct Heatmap: View {
    let days:Set<String>
    private var dates:[Date] {
        let calendar=Calendar.current
        let today=calendar.startOfDay(for:Date())
        return (0..<35).compactMap { calendar.date(byAdding:.day,value:$0-34,to:today) }
    }
    private func key(_ date:Date)->String {
        let formatter=DateFormatter()
        formatter.calendar=Calendar.current
        formatter.locale=Locale(identifier:"en_US_POSIX")
        formatter.timeZone=TimeZone.current
        formatter.dateFormat="yyyy-MM-dd"
        return formatter.string(from:date)
    }
    var body: some View {
        let calendar=Calendar.current
        let firstWeekday=dates.first.map { calendar.component(.weekday,from:$0) } ?? 1
        let symbols=calendar.veryShortStandaloneWeekdaySymbols
        let columns=Array(repeating:GridItem(.flexible(),spacing:5),count:7)
        VStack(alignment:.leading,spacing:6) {
            LazyVGrid(columns:columns,spacing:5) {
                ForEach(0..<7,id:\.self) { column in
                    Text(symbols[(firstWeekday-1+column)%7])
                        .frame(maxWidth:.infinity)
                        .font(.system(size:9,weight:.semibold))
                        .foregroundStyle(ETheme.muted)
                }
                ForEach(Array(dates.enumerated()),id:\.offset) { index,date in
                    let active=days.contains(key(date))
                    let today=calendar.isDateInToday(date)
                    RoundedRectangle(cornerRadius:3)
                        .fill(active ? ETheme.red.opacity(0.45 + 0.11*Double(index%4)) : Color(hex:0xEFE8DA))
                        .aspectRatio(1,contentMode:.fit)
                        .overlay(RoundedRectangle(cornerRadius:3).stroke(today ? ETheme.blue : .clear,lineWidth:1.5))
                        .accessibilityLabel("\(key(date))、\(active ? "学習あり" : "学習なし")")
                }
            }
        }
        .accessibilityElement(children:.contain)
        .accessibilityLabel("直近35日の学習ヒートマップ")
    }
}
struct SettingsView: View {
    @EnvironmentObject var model:StudyModel
    @State private var backupDocument: BackupDocument?
    @State private var showExporter=false
    @State private var showImporter=false
    @State private var status=""
    var body: some View { NavigationStack { Form {
        Section("文字サイズ") { Picker("表示サイズ",selection:$model.fontScale) { Text("標準").tag(0); Text("大").tag(1); Text("特大").tag(2) }.pickerStyle(.segmented) }
        Section("1日の目標") { Picker("問題数",selection:$model.goal) { Text("4問").tag(4); Text("8問").tag(8); Text("16問").tag(16) }.pickerStyle(.segmented) }
        Section("学習データ") {
            Button { do { backupDocument=BackupDocument(data:try model.backupData()); showExporter=true } catch { status=error.localizedDescription } } label: { Label("学習データをJSONで書き出す",systemImage:"square.and.arrow.up") }
            Button { showImporter=true } label: { Label("JSONから学習データを読み込む",systemImage:"square.and.arrow.down") }
            if !status.isEmpty { Text(status).font(.caption).foregroundStyle(ETheme.muted) }
        }
        Section("覚えかたのルール") { Text("苦手問題は3回連続で正解すると卒業します。途中で誤答すると連続正解数は0に戻ります。").font(.subheadline) }
        Section("この教材について") { Text("公式過去問600問を収録しています。転記内容・正答・図版は独立監査前のため、監査完了までは学習参考用として扱ってください。"); Text("収録時は出典・改変表示を行います。") }
    }.navigationTitle("設定").scrollContentBackground(.hidden).background(ETheme.paper)
    .environment(\.dynamicTypeSize,model.fontScale == 0 ? .large : (model.fontScale == 1 ? .xLarge : .xxxLarge))
    .fileExporter(isPresented:$showExporter,document:backupDocument,contentType:.json,defaultFilename:"electrician2-learning-backup") { result in if case .failure(let error)=result { status=error.localizedDescription } else { status="JSONを書き出しました。" } }
    .fileImporter(isPresented:$showImporter,allowedContentTypes:[.json],allowsMultipleSelection:false) { result in do { let url=try result.get(); let access=url.startAccessingSecurityScopedResource(); defer { if access { url.stopAccessingSecurityScopedResource() } }; try model.restoreBackup(Data(contentsOf:url)); status="学習データを読み込みました。" } catch { status=error.localizedDescription } }
    } }
}
struct BackupDocument: FileDocument {
    static var readableContentTypes:[UTType] { [.json] }
    var data:Data
    init(data:Data=Data()) { self.data=data }
    init(configuration:ReadConfiguration)throws { data=configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration:WriteConfiguration)throws->FileWrapper { FileWrapper(regularFileWithContents:data) }
}
