import SwiftUI

struct QuizView: View {
    @EnvironmentObject var model:StudyModel
    var body: some View {
        NavigationStack {
            if let q=model.current {
                ZStack { ETheme.paper.ignoresSafeArea()
                    ScrollView { VStack(alignment:.leading,spacing:16) {
                        HStack { Text("\(model.index+1)/\(model.session.count)").font(.system(size:12,weight:.heavy)); Spacer(); Text("サンプルデータ").font(.system(size:11,weight:.bold)).foregroundStyle(ETheme.red) }
                        ProgressView(value:Double(model.index+1),total:Double(max(1,model.session.count))).tint(ETheme.blue)
                        Text(q.subject).font(.system(size:12,weight:.heavy)).foregroundStyle(ETheme.blue).padding(.horizontal,10).padding(.vertical,5).background(ETheme.blueSoft).clipShape(Capsule())
                        Text(q.prompt).font(.system(size:19,weight:.bold,design:.serif)).lineSpacing(7).foregroundStyle(ETheme.ink)
                        if let id=q.diagramID { DiagramPlaceholder(reference:id) }
                        ForEach(Array(q.choices.enumerated()),id:\.offset) { i,c in
                            Button { model.answer(i) } label: {
                                HStack(spacing:12) {
                                    Text("\(i+1)").font(.system(size:14,weight:.heavy)).frame(width:30,height:30).background(ETheme.paper).clipShape(RoundedRectangle(cornerRadius:8))
                                    Text(c).font(.system(size:14,weight:.medium)).frame(maxWidth:.infinity,alignment:.leading)
                                    if model.graded && i==q.answer { HandMark(correct:true) }
                                    else if model.graded && i==model.selected { HandMark(correct:false) }
                                }.padding(13).frame(minHeight:58).background(choiceColor(i,q)).clipShape(RoundedRectangle(cornerRadius:12)).overlay(RoundedRectangle(cornerRadius:12).stroke(choiceBorder(i,q),lineWidth:1.5))
                            }.buttonStyle(.plain).disabled(model.graded)
                        }
                        if model.graded {
                            VStack(alignment:.leading,spacing:12) {
                                Text(model.selected == q.answer ? "正解" : "惜しい").font(.system(size:14,weight:.heavy)).foregroundStyle(model.selected == q.answer ? ETheme.green : ETheme.red)
                                VStack(alignment:.leading,spacing:5) { Text("ここだけ覚える").font(.system(size:10,weight:.heavy)).tracking(1.5).foregroundStyle(ETheme.gold); Text(q.memory).font(.system(size:16,weight:.bold,design:.serif)).foregroundStyle(ETheme.ink) }.padding(13).frame(maxWidth:.infinity,alignment:.leading).background(Color(hex:0xFFFBEA)).clipShape(RoundedRectangle(cornerRadius:10)).overlay(alignment:.leading) { Rectangle().fill(ETheme.gold).frame(width:4) }
                                Text(q.explanation).font(.system(size:13)).foregroundStyle(ETheme.ink2)
                                Button("次の問題へ") { model.next() }.font(.system(size:15,weight:.heavy)).foregroundStyle(.white).frame(maxWidth:.infinity,minHeight:54).background(ETheme.blue).clipShape(RoundedRectangle(cornerRadius:14))
                            }.padding(16).background(ETheme.card).clipShape(RoundedRectangle(cornerRadius:14)).overlay(RoundedRectangle(cornerRadius:14).stroke(ETheme.line))
                        }
                        Text("※画面・操作確認用の架空データです。試験問題ではありません。").font(.system(size:10)).foregroundStyle(ETheme.muted)
                    }.padding(18).frame(maxWidth:520).frame(maxWidth:.infinity) }
                }.navigationTitle("学習").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement:.topBarLeading) { Button("閉じる") { model.showQuestion=false } } }
            } else { ProgressView() }
        }.preferredColorScheme(.light)
    }
    func choiceColor(_ i:Int,_ q:DemoQuestion)->Color { guard model.graded else{return .white}; if i==q.answer{return ETheme.greenSoft}; if i==model.selected{return ETheme.redSoft}; return .white.opacity(0.5) }
    func choiceBorder(_ i:Int,_ q:DemoQuestion)->Color { guard model.graded else{return ETheme.line}; if i==q.answer{return ETheme.green}; if i==model.selected{return ETheme.red}; return ETheme.line }
}
struct HandMark: View {
    let correct:Bool
    var body: some View {
        ZStack {
            if correct {
                Circle().trim(from:0.04,to:0.96).stroke(ETheme.red,style:StrokeStyle(lineWidth:3.2,lineCap:.round)).frame(width:34,height:34).rotationEffect(.degrees(-14))
                    .overlay(Circle().trim(from:0.05,to:0.92).stroke(ETheme.red.opacity(0.65),style:StrokeStyle(lineWidth:1.2,lineCap:.round)).frame(width:31,height:31).rotationEffect(.degrees(9)))
            } else {
                Path { p in p.move(to:CGPoint(x:7,y:7)); p.addQuadCurve(to:CGPoint(x:27,y:27),control:CGPoint(x:18,y:15)); p.move(to:CGPoint(x:27,y:6)); p.addQuadCurve(to:CGPoint(x:6,y:28),control:CGPoint(x:17,y:20)) }.stroke(ETheme.red,style:StrokeStyle(lineWidth:3.4,lineCap:.round)).frame(width:34,height:34)
            }
        }.frame(width:38,height:38).accessibilityLabel(correct ? "正解" : "誤答")
    }
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
            GeometryReader { geo in ZStack {
                RoundedRectangle(cornerRadius:12).fill(Color.white)
                VStack(spacing:12) { Image(systemName:"point.3.connected.trianglepath.dotted").font(.system(size:54)); Text("図版未搭載").font(.headline); Text("権利確認後に原典図版を登録").font(.caption) }.foregroundStyle(ETheme.blue)
            }.frame(width:geo.size.width,height:220).scaleEffect(scale).offset(offset)
                .gesture(MagnificationGesture().onChanged { v in scale=max(1,min(4,lastScale*v)) }.onEnded { _ in lastScale=scale })
                .simultaneousGesture(DragGesture().onChanged { v in offset=CGSize(width:lastOffset.width+v.translation.width,height:lastOffset.height+v.translation.height) }.onEnded { _ in lastOffset=offset }).clipped()
            }.frame(height:220).clipShape(RoundedRectangle(cornerRadius:12))
            HStack { Text("ピンチで拡大・縮小／ドラッグで移動"); Spacer(); Button("全体表示") { scale=1; lastScale=1; offset = .zero; lastOffset = .zero }.font(.caption.bold()) }.font(.caption2).foregroundStyle(.secondary)
        }.padding(12).background(ETheme.card).clipShape(RoundedRectangle(cornerRadius:14)).overlay(RoundedRectangle(cornerRadius:14).stroke(ETheme.line))
    }
}
