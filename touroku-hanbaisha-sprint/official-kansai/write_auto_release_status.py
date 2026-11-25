#!/usr/bin/env python3
"""Derive release status from on-disk audit evidence; no optimistic claims."""
import collections,json
from pathlib import Path
from datetime import datetime,timezone,timedelta
B=Path(__file__).resolve().parent
IOS=B.parents[1]/"touroku-hanbaisha-ios"
by_year={};global_reasons=collections.Counter();global_advisories=collections.Counter()
for y in range(2022,2027):
    file=B/f"AUTO_DIFF_{y}.json"
    if file.exists():
        d=json.loads(file.read_text())
        if len(d["questions"])!=120 or d["autoPass"]+d["held"]!=120:raise RuntimeError("invalid audit count")
        reasons=d["reasonCounts"]
        advisories=d.get("advisoryCounts",{})
        by_year[str(y)]={"candidate":120,"autoDiffPass":d["autoPass"],"autoDiffHeld":d["held"],
                          "notYetDiffed":0,"reasons":reasons,"advisories":advisories,
                          "evidence":f"touroku-hanbaisha-sprint/official-kansai/AUTO_DIFF_{y}.json"}
        global_reasons.update(reasons)
        global_advisories.update(advisories)
    else:
        by_year[str(y)]={"candidate":120,"autoDiffPass":0,"autoDiffHeld":0,"notYetDiffed":120,
                          "reasons":{"PDF_REEXTRACTION_NOT_CONFIRMED":120},"advisories":{},"evidence":None}
bank=json.loads((B/"APPROVED_OFFICIAL_BANK.json").read_text())
manual=json.loads((B/"MANUAL_VISUAL_AUDIT_20261123.json").read_text())
existing=json.loads((IOS/"release-status.json").read_text())
total=bank["count"]
promotion_methods=("auto","geometry","ruby","rubyOrdered","layout","visual","cropImage","rubyFontCluster",
                   "visualRubyV2","imageV3","directRubyV3","sourceOrderUnattached","ruby113Auto")
method_totals={method:sum(s.get(method,0) for s in bank["byYear"].values()) for method in promotion_methods}
if total!=sum(method_totals.values()) or total>600:raise RuntimeError("approved count mismatch")
auto=method_totals["auto"]
visual=method_totals["visual"]
geometry=method_totals["geometry"]
ruby=method_totals["ruby"]
ruby_ordered=method_totals["rubyOrdered"]
layout=method_totals["layout"]
if "KSAI-2023-090" in bank["approvedIds"]:raise RuntimeError("invalid q90 not visually reviewed")
now=datetime.now(timezone(timedelta(hours=9))).isoformat(timespec="seconds")
existing["updated_at"]=now
qb=existing.setdefault("question_bank",{})
qb.update({"verified_official_imported":total,"official_question_text_imported":total,
           "production_official_bank_count":total,"auto_diff_pass_promoted":auto,
           "manual_visual_pass_preserved":visual,"auto_geometry_new_promoted":geometry,"auto_ruby_new_promoted":ruby,"auto_ruby_ordered_promoted":ruby_ordered,"auto_layout_new_promoted":layout,"official_question_text_staged":600,
           "auto_diff_per_year":by_year,
           "auto_diff_reason_totals":dict(global_reasons),"auto_diff_advisory_totals":dict(global_advisories),
           "approved_by_method":method_totals})
gate=existing.setdefault("gates",{})
gate["normalized_pdf_auto_diff"]=f"COMPLETE_{600-sum(x['notYetDiffed'] for x in by_year.values())}_OF_600"
gate["official_source_import"]=f"PARTIAL_APPROVED_{total}_OF_600"
gate["verbatim_and_answer_audit"]=f"AUTO_{auto}_GEOMETRY_{geometry}_RUBY_{ruby}_ORDERED_{ruby_ordered}_LAYOUT_{layout}_VISUAL_{visual}_CROP_{method_totals['cropImage']}_FONT_RUBY_{method_totals['rubyFontCluster']}_VISUAL_RUBY_V2_{method_totals['visualRubyV2']}_IMAGE_V3_{method_totals['imageV3']}_DIRECT_RUBY_V3_{method_totals['directRubyV3']}_SOURCE_ORDER_{method_totals['sourceOrderUnattached']}_RUBY113_{method_totals['ruby113Auto']}_REMAINING_{600-total}"
gate["content_complete"]="PASS" if total==600 else "BLOCKED"
gate["official_release_readiness"]="BLOCKED_UNTIL_CONTENT_AND_APP_REVIEW"
existing["release_gate"]="BLOCKED"
existing["app_review_submitted"]=False
ev=existing.setdefault("evidence",[])
for y in range(2022,2027):
    a=f"touroku-hanbaisha-sprint/official-kansai/AUTO_DIFF_{y}.json"
    if a not in ev:ev.append(a)
(IOS/"release-status.json").write_text(json.dumps(existing,ensure_ascii=False,indent=2)+"\n")
reason_text="\n".join(f"| {k} | {v} |" for k,v in sorted(global_reasons.items()))
advisory_text="\n".join(f"| {k} | {v} |" for k,v in sorted(global_advisories.items()))
table="\n".join(f"| {y} | {t['autoDiffPass']} | {t['autoDiffHeld']} | {t['notYetDiffed']} | {bank['byYear'][y]['visual']} | {bank['byYear'][y]['auto']+bank['byYear'][y]['visual']} |" for y,t in by_year.items())
section=f"""\n## 自動照合ゲート v1：{now}（最新）\n
- **公開判定 BLOCKED**。本番問題バンク **{total}/600問**（目視PASS {visual}、文字diff PASS {auto}、座標照合PASS {geometry}）。
- 検証手順：原典PDFを公式URLから再取得し、保存済SHA-256と一致したバイナリのみPyMuPDF再抽出。問題境界・rawOriginalText・選択肢・解答番号を正規化diff。
- 正規化：**Unicode NFC、Unicode空白（半角・全角・改行・タブ）の除去のみ**。かな、漢字、句読点、記号、ルビ本文は削除・書換しない。ルビ配置は独立審査対象。
- 自動昇格禁止：画像、図表、正誤組合せ表、ルビ独立行、抽出不一致、4/5肢判定失敗、2023年度問90。表組のレイアウト再現は文字diffが一致しても合格しない。
- 注意：PyMuPDF同一エンジンの再抽出のため独立した逐語転記ではない。**原典バイナリの固定・構造diffは確認できるが、非テキスト要素やPDF自体の文字抽出誤りを保証しない。**
- 2023年度問90は収録候補として保持、`answer=null`、全員正解扱い、模試の正答率分母から除外。視覚・公式例外監査完了までは正式昇格不可。

| 年度 | diff PASS候補 | diff HOLD | 未照合 | 保存済目視PASS | 年度別正式昇格 |
|---|---:|---:|---:|---:|---:|
{table}
| **合計** | **{sum(x['autoDiffPass'] for x in by_year.values())}** | **{sum(x['autoDiffHeld'] for x in by_year.values())}** | **{sum(x['notYetDiffed'] for x in by_year.values())}** | **{visual}** | **{total}** |

### 自動検出の保留理由（重複計上、合計は600に一致しない）
| 理由コード | 該当件数 |
|---|---:|
{reason_text}

### 合否判定に使わない参考差異\n| 注意コード | 件数 |\n|---|---:|\n{advisory_text}\n\n実行成功した年度の差分、原典ページ、公式PDF SHA-256、正規化後のハッシュは `official-kansai/AUTO_DIFF_2022.json` ～ `AUTO_DIFF_2026.json`。PASSは `APPROVED_OFFICIAL_BANK.json` に移し、未PASSは非公開。実ブラウザ・iOSビルド・TestFlightは別ゲートのまま。
"""
md_path=IOS/"RELEASE_STATUS.md"
old=md_path.read_text()
md_path.write_text(old+"\n"+section)
print(json.dumps({"approved":total,"auto":auto,"visual":visual,"years":by_year},ensure_ascii=False))
