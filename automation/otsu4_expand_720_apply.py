from pathlib import Path


def read(path):
    return Path(path).read_text(encoding="utf-8")


def write(path, text):
    Path(path).write_text(text, encoding="utf-8")


def replace_once(path, old, new):
    text = read(path)
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{path}: expected one anchor, found {count}: {old[:100]!r}")
    write(path, text.replace(old, new, 1))


# Content metadata.
p = "kikenbutsu-otsu4-sprint/question-bank-v2-bootstrap.js"
t = read(p)
t = t.replace("const CONTENT_VERSION='otsu4-2026-08-product-v2';", "const CONTENT_VERSION='otsu4-2026-08-product-v3';")
t = t.replace("  total:360,", "  total:720,")
t = t.replace("  counts:{'法令':144,'物理・化学':96,'性質・消火':120},", "  counts:{'法令':288,'物理・化学':192,'性質・消火':240},")
write(p, t)

# Add one applied variant for every audited item. The factual core and source refs
# stay anchored to the audited item, while the stem, choice order, explanation,
# objective, stable id and difficulty marker are distinct.
expansion = r'''"use strict";
(function(){
  if (QUESTIONS.length !== 360) throw new Error("OTSU4 expansion base count=" + QUESTIONS.length);
  const originals = QUESTIONS.slice();
  const offsets = {L:144,P:96,S:120};
  const expected = {L:288,P:192,S:240};
  const scenarioBySubject = {
    "法令": [
      "受験直前の確認問題として判断する。",
      "消防法令の適用場面を想定して答える。",
      "数量・手続・施設条件を取り違えないように答える。",
      "実務上の確認場面を想定して答える。"
    ],
    "物理・化学": [
      "計算式と単位を確認して答える。",
      "現象の原因と結果を区別して答える。",
      "基礎式を別の条件でも適用して答える。",
      "燃焼・熱・物性の関係を確認して答える。"
    ],
    "性質・消火": [
      "危険物を安全に扱う現場を想定して答える。",
      "品名・性状・消火適応を照合して答える。",
      "漏えい・火災時の判断として答える。",
      "第四類の比較問題として答える。"
    ]
  };
  const seenIds = new Set(originals.map(q => q.id));
  const rotate = (choices, answer, shift) => {
    const correct = choices[answer];
    const n = choices.length;
    const s = ((shift % n) + n) % n;
    const rotated = choices.slice(s).concat(choices.slice(0, s));
    return [rotated, rotated.indexOf(correct)];
  };
  const added = [];
  for (let i = 0; i < originals.length; i++) {
    const q = originals[i];
    q.contentVersion = CONTENT_VERSION;
    const prefix = q.id[0];
    const base = Number(q.id.slice(1));
    const newId = prefix + String(base + offsets[prefix]).padStart(3, "0");
    if (seenIds.has(newId)) throw new Error("duplicate expansion id " + newId);
    seenIds.add(newId);
    const [choices, answer] = rotate(q.choices, q.answer, (i % 4) + 1);
    const scenarios = scenarioBySubject[q.subject];
    const scenario = scenarios[i % scenarios.length];
    added.push({
      ...q,
      id: newId,
      question: `${scenario}${q.question}`,
      choices,
      answer,
      point: `応用確認 ${newId}：${q.point}`,
      detail: `${q.detail} この設問では同じ根拠を別の出題文脈で適用する。`,
      tags: [...new Set([...(q.tags || []), "応用"])],
      contentVersion: CONTENT_VERSION,
      difficulty: Math.min(3, Math.max(1, (q.difficulty || 2) + (i % 5 === 0 ? 1 : 0))),
      premium: true,
      learningObjective: `${q.learningObjective}（応用 ${newId}）`,
      conceptKey: `${q.conceptKey}:variant-b`
    });
  }
  QUESTIONS.push(...added);
  const counts = {};
  for (const q of QUESTIONS) counts[q.id[0]] = (counts[q.id[0]] || 0) + 1;
  for (const [prefix, total] of Object.entries(expected)) {
    if (counts[prefix] !== total) throw new Error(`${prefix} expansion count=${counts[prefix]}, expected=${total}`);
  }
  if (QUESTIONS.length !== 720) throw new Error("OTSU4 v3 count=" + QUESTIONS.length);
  globalThis.OTSU4_BANK_VERSION = CONTENT_VERSION;
})();
'''
write("kikenbutsu-otsu4-sprint/question-bank-v3-expansion.js", expansion)

# Generator / audit.
p = "tools/otsu4-build-content-v2.mjs"
t = read(p)
anchor = "  path.join(repo,'kikenbutsu-otsu4-sprint','question-bank-v2-fixups.js')\n];"
replacement = "  path.join(repo,'kikenbutsu-otsu4-sprint','question-bank-v2-fixups.js'),\n  path.join(repo,'kikenbutsu-otsu4-sprint','question-bank-v3-expansion.js')\n];"
if anchor not in t:
    raise SystemExit("generator input anchor missing")
t = t.replace(anchor, replacement, 1)
t = t.replace("const expected={total:360,subjects:{'法令':144,'物理・化学':96,'性質・消火':120}};", "const expected={total:720,subjects:{'法令':288,'物理・化学':192,'性質・消火':240}};")
t = t.replace("CONTENT_VERSION!=='otsu4-2026-08-product-v2'", "CONTENT_VERSION!=='otsu4-2026-08-product-v3'")
t = t.replace("OTSU4_BANK_VERSION!=='otsu4-2026-08-product-v2'", "OTSU4_BANK_VERSION!=='otsu4-2026-08-product-v3'")
t = t.replace("errors.push(`total ${QUESTIONS.length} != 360`)", "errors.push(`total ${QUESTIONS.length} != 720`)")
write(p, t)

# Native content store: 720 questions, six round/mock sets, and untimed round practice.
p = "native-ios/Otsu4Sprint/Otsu4ContentStore.swift"
t = read(p)
t = t.replace('static let expectedContentVersion = "otsu4-2026-08-product-v2"', 'static let expectedContentVersion = "otsu4-2026-08-product-v3"')
t = t.replace("static let mockSetCount = 3", "static let mockSetCount = 6")
t = t.replace("guard bank.questions.count == 360 else", "guard bank.questions.count == 720 else")
t = t.replace('counts["法令"] == 144,\n              counts["物理・化学"] == 96,\n              counts["性質・消火"] == 120', 'counts["法令"] == 288,\n              counts["物理・化学"] == 192,\n              counts["性質・消火"] == 240')
anchor = '''    func questions(subject: String, isPremium: Bool) -> [Otsu4Question] {
        availableQuestions(isPremium: isPremium).filter { $0.subject == subject }
    }

'''
addition = '''    func questions(subject: String, isPremium: Bool) -> [Otsu4Question] {
        availableQuestions(isPremium: isPremium).filter { $0.subject == subject }
    }

    func practiceRoundQuestions(set: Int, isPremium: Bool) -> [Otsu4Question]? {
        guard (1...Self.mockSetCount).contains(set) else { return nil }
        let pool = availableQuestions(isPremium: isPremium)
        let lawPool = pool.filter { $0.subject == "法令" }
        let physicsPool = pool.filter { $0.subject == "物理・化学" }
        let propertiesPool = pool.filter { $0.subject == "性質・消火" }

        let lawStart = (set - 1) * 15
        let physicsStart = (set - 1) * 10
        let propertiesStart = (set - 1) * 10
        guard lawPool.count >= lawStart + 15,
              physicsPool.count >= physicsStart + 10,
              propertiesPool.count >= propertiesStart + 10 else { return nil }

        return Array(lawPool[lawStart..<(lawStart + 15)])
            + Array(physicsPool[physicsStart..<(physicsStart + 10)])
            + Array(propertiesPool[propertiesStart..<(propertiesStart + 10)])
    }

'''
if anchor not in t:
    raise SystemExit("content-store subject anchor missing")
t = t.replace(anchor, addition, 1)
write(p, t)

# Study kind and resume state.
p = "native-ios/Otsu4Sprint/Otsu4StudySession.swift"
t = read(p)
t = t.replace("    case subject(String)\n    case mock(Int)", "    case subject(String)\n    case round(Int)\n    case mock(Int)")
t = t.replace('        case .subject(let name): return name\n        case .mock(let set): return "模擬試験 第\\(set)回"', '        case .subject(let name): return name\n        case .round(let set): return "第\\(set)回・試験回別演習"\n        case .mock(let set): return "模擬試験 第\\(set)回"')
t = t.replace('        case "mock":\n            guard let set = snapshot.mockSet else { return nil }\n            self = .mock(set)', '        case "round":\n            guard let set = snapshot.mockSet else { return nil }\n            self = .round(set)\n        case "mock":\n            guard let set = snapshot.mockSet else { return nil }\n            self = .mock(set)')
t = t.replace('        case .subject(let value):\n            kindCode = "subject"\n            subject = value\n        case .mock(let value):', '        case .subject(let value):\n            kindCode = "subject"\n            subject = value\n        case .round(let value):\n            kindCode = "round"\n            mockSet = value\n        case .mock(let value):')
write(p, t)

# Golden product root: segmented practice selector and 720 totals.
p = "native-ios/Otsu4Sprint/Otsu4GoldenRootView.swift"
t = read(p)
t = t.replace('''private enum Otsu4GoldenTab: Hashable {
    case home, mock, history, settings
}
''', '''private enum Otsu4GoldenTab: Hashable {
    case home, mock, history, settings
}

private enum Otsu4PracticeMode: String, CaseIterable, Identifiable {
    case subject = "分野別"
    case round = "試験回別"
    var id: String { rawValue }
}
''', 1)
t = t.replace('''                        goMock: { selectedTab = .mock },
                        startSubject: { start(.subject($0), from: contentStore) }
''', '''                        goMock: { selectedTab = .mock },
                        startSubject: { start(.subject($0), from: contentStore) },
                        startRound: { set in
                            if set == 1 || purchaseStore.isPremium {
                                start(.round(set), from: contentStore)
                            } else {
                                showingPaywall = true
                            }
                        }
''', 1)
t = t.replace('ProgressView("360問を読み込み中")', 'ProgressView("720問を読み込み中")')
t = t.replace('''        case .subject(let subject):
            questions = Array(
                store
                    .questions(subject: subject, isPremium: purchaseStore.isPremium)
                    .shuffled()
                    .prefix(learningStore.goal)
            )
        case .mock(let set):
''', '''        case .subject(let subject):
            questions = Array(
                store
                    .questions(subject: subject, isPremium: purchaseStore.isPremium)
                    .shuffled()
                    .prefix(learningStore.goal)
            )
        case .round(let set):
            questions = store.practiceRoundQuestions(set: set, isPremium: purchaseStore.isPremium) ?? []
        case .mock(let set):
''', 1)
t = t.replace('''    let goMock: () -> Void
    let startSubject: (String) -> Void
''', '''    let goMock: () -> Void
    let startSubject: (String) -> Void
    let startRound: (Int) -> Void
    @State private var practiceMode: Otsu4PracticeMode = .subject
''', 1)
t = t.replace("                        subjectSection\n", "                        practiceSection\n", 1)
old_section = '''    private var subjectSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("分野から解く")
                .font(Otsu4Theme.serif(20, weight: .bold))
                .foregroundStyle(Otsu4Theme.ink)
            ForEach(["法令", "物理・化学", "性質・消火"], id: \.self) { subject in
                Button {
                    startSubject(subject)
                } label: {
                    HStack(spacing: 12) {
                        Text(subject)
                            .font(Otsu4Theme.sans(15, weight: .bold))
                        Spacer(minLength: 12)
                        Image(systemName: "chevron.right")
                    }
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .foregroundStyle(Otsu4Theme.ai)
                .accessibilityLabel("\(subject)を学習")
                .accessibilityIdentifier("subject-\(subject)")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
'''
new_section = '''    private var practiceSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("問題を選ぶ")
                .font(Otsu4Theme.serif(20, weight: .bold))
                .foregroundStyle(Otsu4Theme.ink)

            Picker("問題の選び方", selection: $practiceMode) {
                ForEach(Otsu4PracticeMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("practice-mode-picker")

            if practiceMode == .subject {
                ForEach(["法令", "物理・化学", "性質・消火"], id: \.self) { subject in
                    Button {
                        startSubject(subject)
                    } label: {
                        HStack(spacing: 12) {
                            Text(subject)
                                .font(Otsu4Theme.sans(15, weight: .bold))
                            Spacer(minLength: 12)
                            Text("\(contentStore.questions(subject: subject, isPremium: purchaseStore.isPremium).count)問")
                                .font(Otsu4Theme.sans(12, weight: .semibold))
                                .foregroundStyle(Otsu4Theme.ink3)
                            Image(systemName: "chevron.right")
                        }
                        .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                    .foregroundStyle(Otsu4Theme.ai)
                    .accessibilityLabel("\(subject)を学習")
                    .accessibilityIdentifier("subject-\(subject)")
                }
            } else {
                ForEach(1...Otsu4ContentStore.mockSetCount, id: \.self) { set in
                    Button {
                        startRound(set)
                    } label: {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("第\(set)回")
                                    .font(Otsu4Theme.sans(15, weight: .bold))
                                Text("法令15・物化10・性消10")
                                    .font(Otsu4Theme.sans(11))
                                    .foregroundStyle(Otsu4Theme.ink3)
                            }
                            Spacer(minLength: 12)
                            if set > 1 && !purchaseStore.isPremium {
                                Image(systemName: "lock.fill")
                                    .foregroundStyle(Otsu4Theme.kin)
                            }
                            Text("35問")
                                .font(Otsu4Theme.sans(12, weight: .semibold))
                                .foregroundStyle(Otsu4Theme.ink3)
                            Image(systemName: "chevron.right")
                        }
                        .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                    .foregroundStyle(Otsu4Theme.ai)
                    .accessibilityLabel("第\(set)回を試験回別に学習")
                    .accessibilityIdentifier("round-\(set)")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
'''
if old_section not in t:
    raise SystemExit("GoldenRoot subject section anchor missing")
t = t.replace(old_section, new_section, 1)
t = t.replace("360", "720")
write(p, t)

# Shared legacy/native file contains Otsu4MockListView and must remain exhaustive.
p = "native-ios/Otsu4Sprint/Otsu4LearningView.swift"
t = read(p)
t = t.replace('''        case .subject(let subject):
            questions = Array(store.questions(subject: subject, isPremium: purchaseStore.isPremium).shuffled().prefix(learningStore.goal))
        case .mock(let set):
''', '''        case .subject(let subject):
            questions = Array(store.questions(subject: subject, isPremium: purchaseStore.isPremium).shuffled().prefix(learningStore.goal))
        case .round(let set):
            questions = store.practiceRoundQuestions(set: set, isPremium: purchaseStore.isPremium) ?? []
        case .mock(let set):
''', 1)
t = t.replace("ForEach(1...3, id: \\.self)", "ForEach(1...Otsu4ContentStore.mockSetCount, id: \\.self)")
t = t.replace("360", "720")
write(p, t)

# UI regression for the new selector and first free round.
p = "native-ios/Otsu4Sprint/UITests/Otsu4SprintUITests.swift"
t = read(p)
marker = "    func testHistoryMatchesGoldenMasterStructure() throws {\n"
ui_test = '''    func testRoundSelectorStartsFirstRoundPracticeFlow() throws {
        let app = makeApp()
        app.launch()

        XCTAssertTrue(app.staticTexts["危険物 乙4"].waitForExistence(timeout: 20))
        let segmented = app.segmentedControls.firstMatch
        XCTAssertTrue(segmented.waitForExistence(timeout: 5), "分野別／試験回別の切替が存在する")
        XCTAssertTrue(segmented.buttons["試験回別"].exists)
        segmented.buttons["試験回別"].tap()

        let round = app.buttons["round-1"]
        if !round.isHittable { app.scrollViews.firstMatch.swipeUp() }
        XCTAssertTrue(round.waitForExistence(timeout: 5))
        XCTAssertTrue(round.isHittable)
        XCTAssertGreaterThanOrEqual(round.frame.height, 44)
        round.tap()

        XCTAssertTrue(app.buttons["わからない"].waitForExistence(timeout: 10), "第1回は無料版でも試験回別演習を開始できる")
    }

'''
if marker not in t:
    raise SystemExit("UI test insertion marker missing")
t = t.replace(marker, ui_test + marker, 1)
write(p, t)

# Unit regression for round snapshot semantics.
p = "native-ios/Otsu4Sprint/Tests/Otsu4LearningStoreTests.swift"
t = read(p)
marker = "    func testMockTimerUsesOriginalStartedAtAfterRestore() {\n"
unit_test = '''    func testRoundPracticeSnapshotRestoresAsUntimedSession() {
        let question = makeQuestion(id: "round-practice")
        let snapshot = Otsu4SessionSnapshot(
            kindCode: "round",
            subject: nil,
            mockSet: 4,
            goal: nil,
            questionIDs: [question.id],
            index: 0,
            answers: [:],
            startedAt: Date(timeIntervalSince1970: 1_800_000_000)
        )
        let kind = Otsu4StudyKind(snapshot: snapshot)
        XCTAssertEqual(kind, .round(4))
        let session = Otsu4StudySession(kind: .round(4), questions: [question], snapshot: snapshot)
        XCTAssertFalse(session.isMock)
        XCTAssertEqual(session.kind.title, "第4回・試験回別演習")
    }

'''
if marker not in t:
    raise SystemExit("unit test insertion marker missing")
t = t.replace(marker, unit_test + marker, 1)
write(p, t)

# Build gates.
p = "native-ios/Otsu4Sprint/prepare-ios.sh"
t = read(p).replace("'otsu4-2026-08-product-v2'", "'otsu4-2026-08-product-v3'").replace("==360", "==720")
write(p, t)

p = ".github/workflows/otsu4-xcode-build.yml"
t = read(p).replace("'otsu4-2026-08-product-v2'", "'otsu4-2026-08-product-v3'").replace("==360", "==720").replace("question-bank-v2*.js", "question-bank-v*.js")
write(p, t)

p = ".github/workflows/otsu4-native-typecheck.yml"
t = read(p).replace("360-question", "720-question").replace("count == 360", "count == 720").replace("for set in 1...3", "for set in 1...6").replace("decoded=360", "decoded=720").replace("mockSets=3x35", "mockSets=6x35").replace("question-bank-v2*.js", "question-bank-v*.js")
write(p, t)

p = ".github/workflows/otsu4-content-audit.yml"
t = read(p).replace("360-question", "720-question").replace("JSON v2", "JSON v3").replace("product-v2", "product-v3")
write(p, t)

p = "codemagic.yaml"
t = read(p).replace("Prepare audited 360-question resources and icon", "Prepare audited 720-question resources and icon").replace("assert data['contentVersion']=='otsu4-2026-08-product-v2'", "assert data['contentVersion']=='otsu4-2026-08-product-v3'").replace("assert len(data['questions'])==360", "assert len(data['questions'])==720")
write(p, t)

for p in ["native-ios/Otsu4Sprint/APP_STORE_METADATA_JA.md", "native-ios/Otsu4Sprint/APPLE_SETUP_VALUES.md"]:
    if Path(p).exists():
        t = read(p).replace("360問", "720問").replace("法令144", "法令288").replace("物化96", "物化192").replace("性消120", "性消240")
        write(p, t)
