#!/usr/bin/env python3
from pathlib import Path

path = Path(__file__).resolve().parent / "Sources" / "RigakuRootViewV2.swift"
text = path.read_text(encoding="utf-8")
original = text

replacements = [
    (
        "                        contentProgress\n                        resumeCard",
        "                        contentProgress\n                        accessPlanCard\n                        resumeCard",
    ),
    (
        "                subtitle: \"誤答・わからない \\(appModel.weakCount)問\",",
        "                subtitle: appModel.canAccessFullWeakReview ? \"誤答・わからない \\(appModel.weakCount)問\" : \"月額プランで全苦手復習を解放\",",
    ),
    (
        "                let count = appModel.auditedQuestionCount(forSubject: subject)",
        "                let count = appModel.availableQuestionCount(forSubject: subject)",
    ),
    (
        "                                Text(\"監査済み \\(count)問\")",
        "                                Text(\"利用可能 \\(count)問\")",
    ),
    (
        "                            let ready = appModel.isMockReady(round: round, expectedQuestionCount: exam.officialQuestionCount)",
        "                            let contentReady = appModel.isMockReady(round: round, expectedQuestionCount: exam.officialQuestionCount)\n                            let accessReady = contentReady && appModel.canAccessBaseMocks",
    ),
    (
        "                                            .foregroundStyle(ready ? LearningSprintTheme.green : LearningSprintTheme.ink2)",
        "                                            .foregroundStyle(contentReady ? LearningSprintTheme.green : LearningSprintTheme.ink2)",
    ),
    (
        "                                        Text(ready ? \"200問のベース模試を開始\" : \"全問PASS後に解放\")",
        "                                        Text(accessReady ? \"200問のベース模試を開始\" : (contentReady ? \"月額プランで解放\" : \"全問PASS後に解放\"))",
    ),
    (
        "                                    Image(systemName: ready ? \"checkmark.seal\" : \"lock\")",
        "                                    Image(systemName: accessReady ? \"checkmark.seal\" : \"lock\")",
    ),
    (
        "                                        .foregroundStyle(ready ? LearningSprintTheme.green : LearningSprintTheme.gold)",
        "                                        .foregroundStyle(accessReady ? LearningSprintTheme.green : LearningSprintTheme.gold)",
    ),
    (
        "                            .disabled(!ready)",
        "                            .disabled(!contentReady)",
    ),
]

for old, new in replacements:
    if old not in text:
        raise SystemExit(f"required UI source not found: {old[:80]!r}")
    text = text.replace(old, new, 1)

marker = "    @ViewBuilder\n    private var resumeCard: some View {"
access_card = '''    @ViewBuilder
    private var accessPlanCard: some View {
        if appModel.purchaseConfigured {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label(
                        appModel.premiumAccess ? "月額プラン利用中" : "無料プラン",
                        systemImage: appModel.premiumAccess ? "checkmark.seal.fill" : "sparkles"
                    )
                    .font(LearningSprintTheme.sans(13, weight: .bold))
                    .foregroundStyle(appModel.premiumAccess ? LearningSprintTheme.green : LearningSprintTheme.indigo)
                    Spacer()
                    Text(appModel.premiumAccess ? "600問" : "60問")
                        .font(LearningSprintTheme.sans(13, weight: .bold))
                }

                Text(appModel.premiumAccess
                     ? "全600問・3回分ベース模試・全苦手復習を利用できます。"
                     : "8分野の60問を無料で試せます。月額プランで全600問・ベース模試・全苦手復習を解放します。")
                    .font(LearningSprintTheme.sans(12, weight: .medium))
                    .foregroundStyle(LearningSprintTheme.ink2)
                    .fixedSize(horizontal: false, vertical: true)

                if !appModel.premiumAccess, let price = appModel.purchaseDisplayPrice {
                    Button("月額プランを開始（\\(price)）") {
                        Task { await appModel.purchasePremium() }
                    }
                    .font(LearningSprintTheme.sans(13, weight: .bold))
                    .buttonStyle(.borderedProminent)
                    .tint(LearningSprintTheme.indigo)
                }
            }
            .padding(14)
            .background(LearningSprintTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(LearningSprintTheme.line))
            .accessibilityIdentifier("home.accessPlan")
        }
    }

'''
if marker not in text:
    raise SystemExit("resumeCard marker not found")
text = text.replace(marker, access_card + marker, 1)

if text == original:
    raise SystemExit("no UI changes produced")
path.write_text(text, encoding="utf-8")
