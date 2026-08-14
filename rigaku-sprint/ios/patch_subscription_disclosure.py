#!/usr/bin/env python3
from pathlib import Path

root = Path(__file__).resolve().parent / "Sources" / "RigakuRootViewV2.swift"
study = Path(__file__).resolve().parent / "Sources" / "RigakuStudyView.swift"

root_text = root.read_text(encoding="utf-8")
root_old = '''                if !appModel.premiumAccess, let price = appModel.purchaseDisplayPrice {
                    Button("月額プランを開始（\\(price)）") {
                        Task { await appModel.purchasePremium() }
                    }
                    .font(LearningSprintTheme.sans(13, weight: .bold))
                    .buttonStyle(.borderedProminent)
                    .tint(LearningSprintTheme.indigo)
                }
'''
root_new = '''                if !appModel.premiumAccess {
                    Text("ベース模試・苦手復習、または設定画面から月額プランの詳細を確認できます。")
                        .font(LearningSprintTheme.sans(11, weight: .medium))
                        .foregroundStyle(LearningSprintTheme.ink3)
                }
'''
if root_old not in root_text:
    raise SystemExit("home purchase block not found")
root_text = root_text.replace(root_old, root_new, 1)
root.write_text(root_text, encoding="utf-8")

study_text = study.read_text(encoding="utf-8")
study_text = study_text.replace(
    'Button("月額プランを開始（\\(price)）") {',
    'Button("月額プランを開始（\\(price) / 1か月）") {',
    1,
)
needle = '''                Button("購入を復元") {
                    Task { await appModel.restorePurchases() }
                }
                .font(LearningSprintTheme.sans(14, weight: .semibold))

                Text("表示価格はApp Storeから取得します。購読の管理・解約はApple Accountのサブスクリプション設定で行えます。")
'''
replacement = '''                Text("1か月ごとに自動更新され、解約するまで継続します。請求額は購入時にApp Storeへ表示される価格です。")
                    .font(LearningSprintTheme.sans(11))
                    .foregroundStyle(LearningSprintTheme.ink2)
                    .multilineTextAlignment(.center)

                Button("購入を復元") {
                    Task { await appModel.restorePurchases() }
                }
                .font(LearningSprintTheme.sans(14, weight: .semibold))

                HStack(spacing: 18) {
                    Link("プライバシー", destination: RigakuAppConfiguration.privacyURL)
                    Link("利用条件", destination: RigakuAppConfiguration.termsURL)
                }
                .font(LearningSprintTheme.sans(12, weight: .semibold))

                Text("購読の管理・解約はApple Accountのサブスクリプション設定で行えます。")
'''
if needle not in study_text:
    raise SystemExit("study paywall disclosure block not found")
study_text = study_text.replace(needle, replacement, 1)
study.write_text(study_text, encoding="utf-8")
