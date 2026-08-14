#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
root_view = (ROOT / "ios/JosanshiSprintFeature/Sources/JosanshiSprintFeature/JosanshiRootView.swift").read_text()
question_view = (ROOT / "ios/JosanshiSprintFeature/Sources/JosanshiSprintFeature/JosanshiQuestionSessionView.swift").read_text()


def require_order(text: str, markers: list[str], label: str) -> None:
    cursor = -1
    for marker in markers:
        position = text.find(marker, cursor + 1)
        if position < 0:
            raise SystemExit(f"FAIL: {label}: missing {marker}")
        if position <= cursor:
            raise SystemExit(f"FAIL: {label}: order violation at {marker}")
        cursor = position


require_order(
    root_view,
    [
        'Text("学びスプリント")',
        'Text("助産師国家試験")',
        'Text("今日も1問、力に変える。")',
        'Text("今日の学習")',
        'Text("続きから再開")',
        'Text("今日のスプリント")',
        'title: "苦手をつぶす"',
        'title: "模擬試験"',
        'Text("分野から解く")',
        'Text("これまで")',
    ],
    "home fixed order",
)

require_order(
    root_view,
    [
        'Section("文字サイズ")',
        'Section("1日の目標")',
        'Section("出題順シャッフル")',
        'Section("選択肢シャッフル")',
        'Section("試験日")',
        'Section("学習データ")',
        'Section("覚えかたのルール")',
        'Section("この教材について")',
        'Section("学習記録リセット")',
    ],
    "settings fixed order",
)

require_order(
    root_view,
    [
        'Text("達成度")',
        'Text("分野別正答率")',
        'Text("直近5週間")',
        'Text("苦手一覧")',
        'Text("直近のスプリント")',
    ],
    "history fixed blocks",
)

if '.dynamicTypeSize(dynamicTypeRange)' not in root_view:
    raise SystemExit("FAIL: text-size control is not applied to the app hierarchy")
if 'model.requiredDailyPace' not in root_view or 'あと\\(days)日' not in root_view:
    raise SystemExit("FAIL: exam countdown / required pace missing")

if 'submit(question: question, payload: AnswerPayload(selectedIndices: [originalIndex]))' not in question_view:
    raise SystemExit("FAIL: single-choice immediate grading is missing")

require_order(
    question_view,
    [
        'LearningSprintMemoryBlock(question.memoryPoint)',
        'DisclosureGroup("詳しい解説"',
    ],
    "feedback memory/detail order",
)

require_order(
    question_view,
    [
        'Text("間違えた問題をすぐ復習")',
        'Text("もう一度\\(result.totalCount)問")',
        'Button("ホームへ戻る"',
    ],
    "result CTA order",
)

if 'return evaluation.isCorrect ? "○" : "×"' not in question_view:
    raise SystemExit("FAIL: vermilion circle/cross feedback marker missing")
if 'coordinator.preferences.shuffleChoices' not in question_view:
    raise SystemExit("FAIL: choice shuffle is not wired")

print("PASS: #14 native Golden Master v2.1 structural gate")
print("  home fixed order: PASS")
print("  settings 9-section order: PASS")
print("  history five blocks: PASS")
print("  countdown/text-size/shuffle: PASS")
print("  immediate grading + feedback detail order: PASS")
print("  result CTA order: PASS")
