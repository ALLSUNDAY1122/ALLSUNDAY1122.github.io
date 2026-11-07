import SwiftUI

struct StoryLibrary: Codable { let stories: [Story] }
struct Story: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let author: String
    let duration: String
    let symbol: String
    let pages: [StoryPage]
}
struct StoryPage: Codable, Hashable { let text: String; let prompt: String }
struct ScannedBook: Codable, Identifiable, Hashable {
    let id: UUID
    var title: String
    let fileName: String
    let pageCount: Int
    let createdAt: Date
}

enum StoryRepository {
    static func load() -> [Story] {
        guard let url = Bundle.main.url(forResource: "stories", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let library = try? JSONDecoder().decode(StoryLibrary.self, from: data)
        else { return [] }
        return library.stories
    }
}

@main
struct IsshoNiIssatsuApp: App {
    @StateObject private var scannedBooks = PDFBookStore()
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(scannedBooks)
                .tint(.indigo)
        }
    }
}

struct RootView: View {
    private let stories = StoryRepository.load()
    var body: some View {
        TabView {
            NavigationStack { StoryShelfView(stories: stories).navigationTitle("いっしょに一冊") }
                .tabItem { Label("収録絵本", systemImage: "books.vertical") }
            NavigationStack { ScannedBookShelfView().navigationTitle("わたしの絵本") }
                .tabItem { Label("わたしの絵本", systemImage: "doc.viewfinder") }
            NavigationStack { SettingsView().navigationTitle("保護者向け") }
                .tabItem { Label("設定", systemImage: "gearshape") }
        }
    }
}

struct StoryShelfView: View {
    let stories: [Story]
    private let columns = [GridItem(.adaptive(minimum: 150, maximum: 220), spacing: 16)]
    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 18) {
                ForEach(stories) { story in
                    NavigationLink(value: story) {
                        VStack(alignment: .leading, spacing: 10) {
                            ZStack {
                                LinearGradient(colors: [.indigo.opacity(0.8), .mint.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing)
                                Image(systemName: story.symbol).font(.system(size: 64)).foregroundStyle(.white)
                            }
                            .frame(height: 145)
                            .clipShape(RoundedRectangle(cornerRadius: 18))
                            Text(story.title).font(.headline).foregroundStyle(.primary)
                            Text("\(story.author)・\(story.duration)").font(.caption).foregroundStyle(.secondary)
                        }
                        .padding(10)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 22))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
        .navigationDestination(for: Story.self) { StoryReaderView(story: $0) }
    }
}

struct StoryReaderView: View {
    let story: Story
    @State private var index = 0
    @State private var showPrompt = true
    var body: some View {
        GeometryReader { proxy in
            let landscape = proxy.size.width > proxy.size.height
            Group {
                if landscape {
                    HStack(spacing: 0) { illustration.frame(width: proxy.size.width * 0.5); panel }
                } else {
                    VStack(spacing: 0) { illustration.frame(height: proxy.size.height * 0.45); panel }
                }
            }
        }
        .navigationTitle(story.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Button { showPrompt.toggle() } label: {
                Image(systemName: showPrompt ? "bubble.left.fill" : "bubble.left")
            }
        }
    }
    private var illustration: some View {
        ZStack {
            LinearGradient(colors: [.indigo.opacity(0.8), .mint.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing)
            Image(systemName: story.symbol).font(.system(size: 82)).foregroundStyle(.white)
        }.padding()
    }
    private var panel: some View {
        VStack(spacing: 18) {
            ProgressView(value: Double(index + 1), total: Double(story.pages.count))
            Spacer()
            Text(story.pages[index].text).font(.title3.weight(.medium)).lineSpacing(8).frame(maxWidth: 560, alignment: .leading)
            if showPrompt {
                Label(story.pages[index].prompt, systemImage: "bubble.left.and.bubble.right")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding().background(.indigo.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))
            }
            Spacer()
            HStack {
                Button("まえ") { index = max(0, index - 1) }.disabled(index == 0)
                Spacer()
                Text("\(index + 1) / \(story.pages.count)").font(.footnote.monospacedDigit())
                Spacer()
                Button(index == story.pages.count - 1 ? "おしまい" : "つぎ") {
                    index = index == story.pages.count - 1 ? 0 : index + 1
                }.buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .contentShape(Rectangle())
        .gesture(DragGesture(minimumDistance: 35).onEnded { value in
            if value.translation.width < -50, index < story.pages.count - 1 { index += 1 }
            if value.translation.width > 50, index > 0 { index -= 1 }
        })
    }
}

struct SettingsView: View {
    var body: some View {
        List {
            Section("スキャン絵本") {
                Label("OCR・文字認識なし", systemImage: "text.magnifyingglass")
                Label("1冊を1つのPDFとして端末内保存", systemImage: "doc.richtext")
                Label("横向き1ページ表示", systemImage: "rectangle.landscape.rotate")
                Label("共有・クラウド送信なし", systemImage: "lock")
            }
        }
    }
}
