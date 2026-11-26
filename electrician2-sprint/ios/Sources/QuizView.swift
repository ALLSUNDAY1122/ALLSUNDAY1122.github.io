import SwiftUI

struct QuizView: View {
    @EnvironmentObject var model:StudyModel
    var body: some View {
        NavigationStack {
            if let q=model.current {
                ScrollView { VStack(alignment:.leading,spacing:16) {
                    HStack { Text("\(model.index+1)/\(model.session.count)").font(.caption.bold()); Spacer(); Text("デモデータ").font(.caption.bold()).foregroundStyle(ETheme.red) }
                    Text(q.subject).font(.caption.bold()).foregroundStyle(ETheme.blue)
                    Text(q.prompt).font(.title3.weight(.semibold)).lineSpacing(6)
                    if let id=q.diagramID { DiagramPlaceholder(reference:id) }
                    ForEach(Array(q.choices.enumerated()),id:\.offset) { i,c in
                        Button { model.answer(i) } label: { HStack { Text(["イ","ロ","ハ","ニ"][i]).font(.headline).frame(width:34,height:34).background(ETheme.paper).clipShape(RoundedRectangle(cornerRadius:8)); Text(c).frame(maxWidth:.infinity,alignment:.leading); if model.graded && i==q.answer { Image(systemName:"checkmark.circle.fill").foregroundStyle(.green) } }.padding(13).background(choiceColor(i,q)).clipShape(RoundedRectangle(cornerRadius:12)).overlay(RoundedRectangle(cornerRadius:12).stroke(ETheme.line)) }.buttonStyle(.plain).disabled(model.graded)
                    }
                    if model.graded { Panel { VStack(alignment:.leading,spacing:10) { Text(model.selected == q.answer ? "正解" : "不正解").font(.headline).foregroundStyle(model.selected == q.answer ? .green : ETheme.red); Text("ここだけ覚える").font(.caption.bold()).foregroundStyle(ETheme.red); Text(q.memory).font(.headline); Text(q.explanation).font(.subheadline).foregroundStyle(.secondary); Button("次の問題へ") { model.next() }.buttonStyle(.borderedProminent).tint(ETheme.blue) } } }
                    Text("※画面・操作確認用の架空データです。試験問題ではありません。").font(.caption2).foregroundStyle(.secondary)
                }.padding(18) }
                .background(ETheme.paper.ignoresSafeArea()).navigationTitle("スプリント").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement:.topBarLeading) { Button("閉じる") { model.showQuestion=false } } }
            } else { ProgressView() }
        }
    }
    func choiceColor(_ i:Int,_ q:DemoQuestion)->Color { guard model.graded else{return .white}; if i==q.answer{return Color.green.opacity(0.12)}; if i==model.selected{return ETheme.red.opacity(0.12)}; return .white }
}
struct DiagramPlaceholder: View {
    let reference:String
    @State private var scale:CGFloat=1
    @State private var lastScale:CGFloat=1
    @State private var offset:CGSize = .zero
    @State private var lastOffset:CGSize = .zero
    var body: some View {
        VStack(alignment:.leading,spacing:8) {
            HStack { Text("共通配線図（ダミー）").font(.caption.bold()); Spacer(); Text(reference).font(.caption2).foregroundStyle(.secondary) }
            GeometryReader { geo in
                ZStack {
                    RoundedRectangle(cornerRadius:12).fill(Color.white)
                    VStack(spacing:12) { Image(systemName:"point.3.connected.trianglepath.dotted").font(.system(size:54)); Text("図版未搭載").font(.headline); Text("権利確認後に原典図版を登録").font(.caption) }.foregroundStyle(ETheme.blue)
                }.frame(width:geo.size.width,height:220).scaleEffect(scale).offset(offset)
                    .gesture(MagnificationGesture().onChanged { v in scale=max(1,min(4,lastScale*v)) }.onEnded { _ in lastScale=scale })
                    .simultaneousGesture(DragGesture().onChanged { v in offset=CGSize(width:lastOffset.width+v.translation.width,height:lastOffset.height+v.translation.height) }.onEnded { _ in lastOffset=offset })
                    .clipped()
            }.frame(height:220).clipShape(RoundedRectangle(cornerRadius:12))
            HStack { Text("ピンチで拡大・縮小／ドラッグで移動"); Spacer(); Button("全体表示") { scale=1; lastScale=1; offset = .zero; lastOffset = .zero }.font(.caption.bold()) }.font(.caption2).foregroundStyle(.secondary)
        }.padding(12).background(Color.white).clipShape(RoundedRectangle(cornerRadius:14)).overlay(RoundedRectangle(cornerRadius:14).stroke(ETheme.line))
    }
}
