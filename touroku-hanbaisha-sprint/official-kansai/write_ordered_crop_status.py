#!/usr/bin/env python3
"""Write verified ordered-ruby and official-PDF crop counts to canonical release state."""
import collections,json
from datetime import datetime,timezone,timedelta
from pathlib import Path
B=Path(__file__).resolve().parent
IOS=B.parents[1]/"touroku-hanbaisha-ios"
STATE=IOS/"release-status.json"
MD=IOS/"RELEASE_STATUS.md"
bank=json.loads((B/"APPROVED_OFFICIAL_BANK.json").read_text())
st=json.loads(STATE.read_text())
yearly={};holdreasons=collections.Counter()
for year in range(2022,2027):
    ruby=json.loads((B/f"ORDERED_RUBY_{year}.json").read_text())
    crop=json.loads((B/f"LAYOUT_CROPS_{year}.json").read_text())
    if ruby["total"]!=120 or len(ruby["records"])!=120:raise RuntimeError("ruby count")
    if crop["staged"]+crop["unresolved"]!=crop["requested"]:raise RuntimeError("crop count")
    if any(r["publishable"] is not False for r in crop["records"]):raise RuntimeError("crop rights gate unexpectedly cleared")
    stats=bank["byYear"][str(year)]
    if stats.get("rubyOrdered",0)>ruby["recoveryPass"]:
        raise RuntimeError("ruby promotion exceeds verified evidence")
    if sum(len(r["assets"]) for r in crop["records"])==0:raise RuntimeError("crop assets empty")
    yearly[str(year)]={
      "rubySourceOrderedPass":ruby["recoveryPass"],
      "rubyOrderedPromoted":stats.get("rubyOrdered",0),
      "rubyRecoveryHold":ruby["recoveryHold"],
      "cropRequested":crop["requested"],
      "cropStaged":crop["staged"],
      "cropUnresolved":crop["unresolved"],
      "cropAssets":sum(len(r["assets"]) for r in crop["records"]),
      "cropAlreadyApprovedQuestions":crop["alreadyApproved"],
      "cropRightsPending":sum(r["rights"]!="CLEARED" for r in crop["records"]),
      "rubyEvidence":f"touroku-hanbaisha-sprint/official-kansai/ORDERED_RUBY_{year}.json",
      "cropEvidence":f"touroku-hanbaisha-sprint/official-kansai/LAYOUT_CROPS_{year}.json"
    }
    holdreasons.update(ruby["reasonCounts"])
if bank["count"]!=st["question_bank"]["production_official_bank_count"]:
    raise RuntimeError("canonical state not synchronized with bank")
if sum(x["rubyOrderedPromoted"] for x in yearly.values())!=sum(x.get("rubyOrdered",0) for x in bank["byYear"].values()):
    raise RuntimeError("ordered ruby bank mismatch")
if sum(x["cropRequested"] for x in yearly.values())!=49:raise RuntimeError("layout crop scope mismatch")
if "KSAI-2023-090" in bank["approvedIds"]:raise RuntimeError("invalid Q90")
now=datetime.now(timezone(timedelta(hours=9))).isoformat(timespec="seconds")
st["updated_at"]=now
st["release_gate"]="BLOCKED"
st["app_review_submitted"]=False
qb=st["question_bank"]
qb.update({
  "production_official_bank_count":bank["count"],
  "verified_official_imported":bank["count"],
  "official_question_text_imported":bank["count"],
  "auto_ruby_ordered_promoted":sum(x["rubyOrderedPromoted"] for x in yearly.values()),
  "ordered_ruby_and_pdf_crop_per_year":yearly,
  "ordered_ruby_hold_reason_totals":dict(holdreasons),
  "official_pdf_crops_total_questions":sum(x["cropRequested"] for x in yearly.values()),
  "official_pdf_crops_staged_questions":sum(x["cropStaged"] for x in yearly.values()),
  "official_pdf_crop_asset_files":sum(x["cropAssets"] for x in yearly.values()),
  "official_pdf_crops_already_approved":sum(x["cropAlreadyApprovedQuestions"] for x in yearly.values()),
  "official_pdf_crops_newly_promoted":0,
  "official_pdf_crops_rights_and_visual_qa":"PENDING_49_IMAGES_STAGED_NOT_AUTO_APPROVED",
  "official_pdf_crop_display_component":"SUPPORTED_WITH_LICENSE_AND_VISUAL_APPROVAL_FIELDS"
})
st["gates"].update({
  "ordered_ruby_source_alignment":"PASS_WITH_EXPLICIT_AMBIGUOUS_HOLDS",
  "official_pdf_region_crop":"STAGED_49_QUESTIONS_WITH_HASH_AND_COORDS",
  "official_pdf_image_app_release":"BLOCKED_RIGHTS_AND_VISUAL_QA",
  "official_source_import":f"PARTIAL_APPROVED_{bank['count']}_OF_600",
  "content_complete":"BLOCKED"
})
for year in range(2022,2027):
    for pre in ("ORDERED_RUBY","LAYOUT_CROPS"):
        e=f"touroku-hanbaisha-sprint/official-kansai/{pre}_{year}.json"
        if e not in st.setdefault("evidence",[]):st["evidence"].append(e)
STATE.write_text(json.dumps(st,ensure_ascii=False,indent=2)+"\n")
rows="\n".join(f"| {y} | {x['rubyOrderedPromoted']} | {x['rubyRecoveryHold']} | {x['cropStaged']} | {x['cropAlreadyApprovedQuestions']} | {x['cropAssets']} |" for y,x in yearly.items())
codes="\n".join(f"| {name} | {count} |" for name,count in sorted(holdreasons.items()))
text=f"""
## 【最新】重複漢字の出現順序監査・公式PDF領域切り抜き（{now}）

**正式バンク {bank['count']}/600問、未昇格 {600-bank['count']}問。今回の順序照合追加昇格は {sum(x['rubyOrderedPromoted'] for x in yearly.values())}問。App Review：BLOCKED。**

原典PDFの文字ごとのページ・座標・字形出現順位と、候補本文の漢字出現回数および独立したルビ読み行を比較。重複漢字も原典と本文の出現順序が一致し、出現回数が等しく、すべての読みが衝突なく一意に割り当てられる場合のみDOM ruby/rtへ構造化した。曖昧なルビや他のHOLDを解消したものとして扱わない。

49件の保留図表／配置は、公式PDFを保存済SHA-256で検証した上で問題の印刷上の範囲をPNGで切り出し、画像SHA-256、ページ、bbox、出典、加工記録を \`LAYOUT_CROPS_2022.json\` ～ \`LAYOUT_CROPS_2026.json\` に保存。画像は \`official-kansai/layout-crops/\` に置く。**49件中、既に正式採用されている問題が5件あるため、未承認の追加対象は44件。今回の画像追加による新規正式昇格は0件。**

| 年度 | 重複漢字ルビ新規昇格 | 順序監査の保留 | PDF画像切り出し成功（問数） | うち既採用 | 生成ファイル数 |
|---|---:|---:|---:|---:|---:|
{rows}
| **合計** | **{sum(x['rubyOrderedPromoted'] for x in yearly.values())}** | **{sum(x['rubyRecoveryHold'] for x in yearly.values())}** | **{sum(x['cropStaged'] for x in yearly.values())}** | **{sum(x['cropAlreadyApprovedQuestions'] for x in yearly.values())}** | **{sum(x['cropAssets'] for x in yearly.values())}** |

### 順序監査で残る理由（重複計上）
| コード | 件数 |
|---|---:|
{codes}

**図表の再現方式：** \`official-practice.html\` に画像表示部品を追加。個別画像の \`licenseVerified=true\` と \`visualVerified=true\` が両方そろう場合のみ通常アプリで表示を許可する。現状の49問は \`rights=REVIEW_THIRD_PARTY_COMPONENTS\`、\`displayQA=PENDING\`、\`publishable=false\` のため、切り抜き画像を配置しても正式公開扱いにしない。画像切り出しには原典の出典と「表示用切り出し」を併記する。原典PDFへのリンクを保持する。

画像の本番公開には、図版内の第三者権利の確認、問題番号・ページ境界の画像目視、スマートフォン幅での拡大・判読性検証、画像SHA-256のアプリ同梱時確認が必要。2023年度問90の公式不適切問題・全員正解扱い・正答率分母除外は維持し、自動昇格は禁止。
"""
MD.write_text(MD.read_text()+"\n"+text)
print(json.dumps({"approved":bank["count"],"orderedRuby":qb["auto_ruby_ordered_promoted"],
  "cropQuestions":qb["official_pdf_crops_staged_questions"],"cropFiles":qb["official_pdf_crop_asset_files"]},ensure_ascii=False))
