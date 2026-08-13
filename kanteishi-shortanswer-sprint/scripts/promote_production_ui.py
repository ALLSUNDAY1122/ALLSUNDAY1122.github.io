#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / "ios" / "KanteishiShortAnswer"
TESTS = ROOT / "ios" / "KanteishiShortAnswerTests" / "KanteishiShortAnswerTests.swift"


def replace_once(path: Path, old: str, new: str) -> None:
    text = path.read_text(encoding="utf-8")
    if old in text:
        path.write_text(text.replace(old, new, 1), encoding="utf-8")
        print("updated", path)
    elif new in text:
        print("already updated", path)
    else:
        raise SystemExit(f"target not found: {path}: {old[:160]}")


core = APP / "AppCore.swift"
replace_once(
    core,
    '''    func startMock(edition: Int) {
        startSession(
            key: "exam:\\(edition)",
            questions: repository.questions(edition: edition),
            title: "令和\\(edition - 2018)年 模擬試験",
            mode: .mock
        )
    }
''',
    '''    func startMock(edition: Int) {
        startSession(
            key: "exam:\\(edition)",
            questions: repository.questions(edition: edition),
            title: "令和\\(edition - 2018)年 模擬試験",
            mode: .mock
        )
    }

    func startEditionSubject(edition: Int, subject: String) {
        let questions = repository.questions(edition: edition).filter { $0.subject == subject }
        startSession(
            key: "exam:\\(edition):subject:\\(subject)",
            questions: questions,
            title: "令和\\(edition - 2018)年・\\(subject)",
            mode: .practice
        )
    }
''',
)

content_path = APP / "ContentView.swift"
replace_once(
    content_path,
    'Text("令和8・7・6年／製品版は各80問")',
    'Text("令和8・7・6年／公式過去問 各80問")',
)

content = content_path.read_text(encoding="utf-8")
marker = "struct MockView: View {"
new_mock = r'''struct MockView: View {
    @EnvironmentObject private var store: LearningStore
    private let subjects = ["不動産に関する行政法規", "不動産の鑑定評価に関する理論"]

    var body: some View {
        ZStack(alignment: .top) {
            AppTheme.paper.ignoresSafeArea()
            PaperGridBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    PageHeader(title: "模擬試験", subtitle: "令和8・7・6年。年度別80問または科目別40問から選べます。")
                    Text("各年度は行政法規40問＋鑑定理論40問＝80問。3年度合計240問の公式過去問を収録しています。")
                        .appSans(12)
                        .foregroundStyle(AppTheme.ink2)
                        .padding(14)
                        .background(AppTheme.aiSoft)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                    ForEach(store.repository.editions, id: \.self) { edition in
                        let examKey = "exam:\(edition)"
                        let latest = store.latestCompletion(for: examKey)
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("令和\(edition - 2018)年")
                                    .appSerif(20, weight: .bold)
                                    .foregroundStyle(AppTheme.ink)
                                Spacer()
                                Text("公式80問")
                                    .appSans(11, weight: .bold)
                                    .foregroundStyle(AppTheme.ink3)
                            }

                            Button {
                                store.startMock(edition: edition)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("年度別模試・80問")
                                            .appSans(16, weight: .bold)
                                            .foregroundStyle(AppTheme.ink)
                                        Text(
                                            latest.map {
                                                "完答 \(store.completionCount(for: examKey))回・直近 \($0.correct)/\($0.total)"
                                            } ?? "完答 \(store.completionCount(for: examKey))回"
                                        )
                                        .appSans(11)
                                        .foregroundStyle(AppTheme.ink3)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundStyle(AppTheme.ai)
                                }
                                .padding(16)
                                .frame(minHeight: 62)
                            }
                            .buttonStyle(.plain)
                            .appCard()
                            .accessibilityIdentifier("mock.edition.\(edition)")

                            Text("科目別演習")
                                .appSans(11, weight: .bold)
                                .foregroundStyle(AppTheme.ink3)
                                .padding(.top, 2)

                            ForEach(subjects, id: \.self) { subject in
                                let questions = store.repository.questions(edition: edition).filter { $0.subject == subject }
                                let key = "exam:\(edition):subject:\(subject)"
                                Button {
                                    store.startEditionSubject(edition: edition, subject: subject)
                                } label: {
                                    HStack(spacing: 12) {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(shortSubject(subject))
                                                .appSans(14, weight: .bold)
                                                .foregroundStyle(AppTheme.ink)
                                            Text("\(questions.count)問・完答 \(store.completionCount(for: key))回")
                                                .appSans(11)
                                                .foregroundStyle(AppTheme.ink3)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .foregroundStyle(AppTheme.ai)
                                    }
                                    .padding(14)
                                    .frame(minHeight: 56)
                                }
                                .buttonStyle(.plain)
                                .appCard()
                                .accessibilityIdentifier("mock.subject.\(edition).\(subject)")
                            }
                        }
                    }
                    Spacer(minLength: 20)
                }
                .padding(.horizontal, 18)
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
            }
        }
        .accessibilityIdentifier("mock.screen")
    }

    private func shortSubject(_ subject: String) -> String {
        subject == "不動産に関する行政法規" ? "行政法規" : "鑑定理論"
    }
}
'''
if marker not in content:
    raise SystemExit("MockView marker missing")
prefix = content.split(marker, 1)[0]
if "年度別模試・80問" not in content:
    content_path.write_text(prefix + new_mock, encoding="utf-8")
    print("upgraded MockView")
else:
    print("MockView already upgraded")

insert_marker = '''    func testStoreKitAccessPolicyNeverUnlocksUnverifiedStates() {'''
new_test = '''    @MainActor
    func testEditionSubjectPracticeUsesFortyQuestions() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json")
        let store = LearningStore(persistenceURL: url)
        store.startEditionSubject(edition: 2026, subject: "不動産に関する行政法規")
        XCTAssertEqual(store.session?.total, 40)
        XCTAssertEqual(store.session?.mode, .practice)
        XCTAssertEqual(store.session?.key, "exam:2026:subject:不動産に関する行政法規")
    }

    func testStoreKitAccessPolicyNeverUnlocksUnverifiedStates() {'''
replace_once(TESTS, insert_marker, new_test)

print("production exam/subject UI promotion complete")
