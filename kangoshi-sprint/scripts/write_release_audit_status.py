#!/usr/bin/env python3
"""Synchronize source-only release ledgers from validated canonical and hold files.
Writes contemporary summary without overwriting historical audit narrative.
"""
import json, pathlib, collections, os, re
R=pathlib.Path(__file__).resolve().parents[1]
J=R/"release-status.json"
MD=R/"RELEASE_STATUS.md"
S=json.loads(J.read_text(encoding="utf8"))
H=json.loads((R/"audit/dual-engine-hold-20261124.json").read_text(encoding="utf8"))
E=json.loads((R/"product-content/verified-additions-20261124.json").read_text(encoding="utf8"))
P=json.loads((R/"audit/dual-engine-promotion-ledger-20261124.json").read_text(encoding="utf8"))
records=E["questions"]
hold=H["hold"]
ext=len(records)
assert ext==E["count"] and ext+len(hold)==480
assert len(hold)==H["count"]
assert len({q["id"] for q in records})==ext
assert not ({q["id"] for q in records}&{q["id"] for q in hold})
assert all(q.get("publishable") is False and q.get("releaseEligible") is False for q in records)
assert all(q.get("publishable") is False and q.get("releaseEligible") is False for q in records if q.get("reviewStatus"))
reasons=collections.Counter(reason for q in hold for reason in q["reasons"])
run_id=os.getenv("GITHUB_RUN_ID","unrecorded")
pending_file=R/"product-content/coordinate-reextracted-pending-20261124.json"
pending=json.loads(pending_file.read_text()) if pending_file.exists() else {"questions":[]}
verified_ids={q["id"] for q in records}
pending_ids={q["id"] for q in pending["questions"]}
active_pending=pending_ids-verified_ids
evidence_path=R/"audit/coordinate-reextraction-evidence-20261124.json"
reextract=json.loads(evidence_path.read_text()) if evidence_path.exists() else {"summary":{}}
total=720+ext

S.update(recordedImported=total,newlyImported=ext,additionalRequired=len(hold),
         stagedCandidateCount=480,releaseStatus="PREFLIGHT_BLOCKED",submissionAllowed=False,
         contentGate=f"CANONICAL_SOURCE_{total}_OF_1200_EXISTING_RUNTIME_720_NEW{ext}_RELEASE_BLOCKED_{len(hold)}_UNVERIFIED")
S["canonicalBank"].update(sourceVerifiedExtension=ext,verifiedTotal=total,
                           unverifiedRemaining=len(hold),
                           extensionRuntimeEligible=0,extensionPublished=0)
S["staging"].update(verifiedExtensionCount=ext,remainingNotCanonicalVerified=len(hold),publishableNew=0)
S["automation"]["bulkHoldCount"]=len(hold)
S["holdRemediation"].update(finalHold=len(hold),netReleasedFromHold=480-len(hold)-67,
                            reasonCountsNow=dict(reasons))
S["latestBoundaryContextAudit"]={
  "date":"2026-11-24","runId":run_id,"source":"GitHub Actions official PDF dual engine",
  "newPromotedInRun":P["newPromoted"],"newIds":P["newIds"],
  "currentCanonical":total,"currentHeld":len(hold),"reasonCountsOverlap":True,
  "scenarioContextRequiresDualEngineSourcePassage":True,
  "svgOriginalDiagramFaithfulnessVerified":0,"svgPendingDetailedVisualInspection":18,
  "status":"SOURCE_ONLY_NO_RELEASE"}
S["latestContextAndControlAudit"]={
  "runId":run_id,"date":"2026-11-24","scope":"480 source candidates, prioritize 22 reextracted",
  "newPromoted":P["newPromoted"],"newIds":P["newIds"],
  "currentCanonical":total,"remaining":len(hold),
  "reextractedPendingSourcePool":len(pending_ids),
  "reextractedStillHeld":len(active_pending),
  "reextractionSummary":reextract.get("summary",{}),
  "sources":["MHLW official question PDF","MHLW official answer PDF","PyMuPDF","Poppler"],
  "unmappedSourceControlsRequireIndividualEvidence":True,
  "releaseEligibleNew":0,"publishableNew":0,
  "status":"SOURCE_ONLY_RELEASE_BLOCKED"}
S["textAudit"]["notImported"]=len(hold)
OCR_CATEGORY=R/"audit/ocr-category-deep-review-20261124.json"
if OCR_CATEGORY.exists():
  report=json.loads(OCR_CATEGORY.read_text(encoding="utf8"))
  assert report["checked"]>=len(hold)  # category snapshot precedes OCR repair promotion
  S["latestOcrCategoryAudit"]={
    "runId":run_id,"checked":report["checked"],"categories":report["categories"],
    "officialDecisions":report["officialDecisions"],
    "evidenceFile":"kangoshi-sprint/audit/ocr-category-deep-review-20261124.json",
    "newlyPromotedByCategoryAudit":report["newlyPromoted"],
    "sourceOnlyReleaseBlocked":True}
OCR_REPAIR=R/"audit/ocr-cmap-repair-ledger-20261124.json"
if OCR_REPAIR.exists():
  proof=json.loads(OCR_REPAIR.read_text(encoding="utf8"))
  assert proof["scope"]==96
  assert proof["repairedCount"]==proof["promotedSourceOnlyCount"]
  S["latestOcrCmapRepairAudit"]={
    "runId":run_id,"scope":proof["scope"],"actualSourceRepairs":proof["repairedCount"],
    "newSourcePromoted":proof["promotedSourceOnlyCount"],
    "stillHeldFrom96":proof["remainingFrom96"],
    "individualProof":"kangoshi-sprint/audit/ocr-cmap-repair-ledger-20261124.json",
    "beforeAfter":"kangoshi-sprint/product-content/ocr-repaired-candidates-20261124.json",
    "releaseEligible":0,"status":"SOURCE_ONLY"}
OCR_COORD=R/"audit/ocr-coordinate-repair-ledger-20261124.json"
if OCR_COORD.exists():
  proof=json.loads(OCR_COORD.read_text(encoding="utf8"))
  assert len(proof["originalTargetIds"])==46
  assert proof["remaining"]+proof["cumulativePromoted"]==46
  S["latestOcrCoordinateRepairAudit"]={
    "runId":run_id,"scope":46,"checkedThisRun":proof["processedThisRun"],
    "newlyPromoted":proof["newPromoted"],"cumulativePromoted":proof["cumulativePromoted"],
    "remainingFrom46":proof["remaining"],"individualProof":"kangoshi-sprint/audit/ocr-coordinate-repair-ledger-20261124.json",
    "beforeAfter":"kangoshi-sprint/product-content/ocr-coordinate-repaired-candidates-20261124.json",
    "releaseEligible":0,"status":"SOURCE_ONLY"}
NONCMAP21=R/"audit/ocr-noncmap-repair-ledger-20261124.json"
if NONCMAP21.exists():
  evidence=json.loads(NONCMAP21.read_text(encoding="utf8"))
  assert len(evidence["originalTargetIds"])==21
  assert evidence["remaining"]+evidence["cumulativePromoted"]==21
  S["latestNonCmap21ImageAudit"]={
    "runId":run_id,"originalTarget":21,"checkedThisRun":evidence["checkedThisRun"],
    "newlyPromoted":evidence["newlyPromoted"],"cumulativePromoted":evidence["cumulativePromoted"],
    "remainingFrom21":evidence["remaining"],
    "reasons":evidence["reasonCounts"],
    "individualProof":"kangoshi-sprint/audit/ocr-noncmap-repair-ledger-20261124.json",
    "beforeAfter":"kangoshi-sprint/product-content/ocr-noncmap-repaired-candidates-20261124.json",
    "releaseEligible":0,"status":"SOURCE_ONLY"}
VISUAL21=R/"audit/ocr-noncmap-visual-promotion-ledger-20261124.json"
if VISUAL21.exists():
  p=json.loads(VISUAL21.read_text(encoding="utf8"))
  assert p["visualVerifiedScope"]==2
  assert p["cumulativePromoted"]+p["remainingFrom2"]==2
  S["latestNonCmapVisualPageCorrection"]={
    "runId":run_id,"verifiedScope":2,"newlyPromoted":p["newPromoted"],
    "cumulativePromoted":p["cumulativePromoted"],"remainingFrom2":p["remainingFrom2"],
    "individualEvidence":"kangoshi-sprint/audit/ocr-noncmap-visual-promotion-ledger-20261124.json",
    "beforeAfter":"kangoshi-sprint/product-content/ocr-noncmap-visual-repaired-candidates-20261124.json",
    "releaseEligible":0,"status":"SOURCE_ONLY"}
VISUAL19=R/"audit/ocr-noncmap-19-promotion-ledger-20261124.json"
if VISUAL19.exists():
  p=json.loads(VISUAL19.read_text(encoding="utf8"))
  assert p["sourceReviewScope"]==19
  assert p["cumulativePromoted"]+p["remainingFrom19"]==19
  S["latestNonCmap19OriginalImageAudit"]={
    "runId":run_id,"scope":19,"newlyPromoted":p["newPromoted"],
    "cumulativePromoted":p["cumulativePromoted"],"remainingFrom19":p["remainingFrom19"],
    "individualProof":"kangoshi-sprint/audit/ocr-noncmap-19-promotion-ledger-20261124.json",
    "beforeAfter":"kangoshi-sprint/product-content/ocr-noncmap-19-before-after-20261124.json",
    "fifthOptionRetained":"K112-PM077","releaseEligible":0,"status":"SOURCE_ONLY"}
PSM23=R/"audit/ocr-psm-disagreement-23-promotion-ledger-20261124.json"
if PSM23.exists():
  p=json.loads(PSM23.read_text(encoding="utf8"))
  assert p["sourceReviewScope"]==23
  assert p["cumulativePromoted"]+p["remainingFrom23"]==23
  S["latestPsm23OriginalImageAudit"]={
    "runId":run_id,"scope":23,"newlyPromoted":p["newPromoted"],
    "cumulativePromoted":p["cumulativePromoted"],"remainingFrom23":p["remainingFrom23"],
    "mediaHoldCount":p["mediaHoldCount"],"mediaHeld":p["mediaHeld"],
    "individualProof":"kangoshi-sprint/audit/ocr-psm-disagreement-23-promotion-ledger-20261124.json",
    "beforeAfter":"kangoshi-sprint/product-content/ocr-psm-disagreement-23-before-after-20261124.json",
    "fiveChoiceCase":"K112-AM075","releaseEligible":0,"status":"SOURCE_ONLY"}
J.write_text(json.dumps(S,ensure_ascii=False,indent=2)+"\n",encoding="utf8")
old=MD.read_text(encoding="utf8")
# Preserve historical change log, remove previously appended dynamic summaries.
history_marker="## 保留413問の原因別検証と修復"
history=old[old.index(history_marker):] if history_marker in old else ""
for marker in ("## 境界位置・状況設定の再検証（自動実行記録）",
               "## PDF座標による問題番号境界再監査",
               "## 状況設定共通文・制御文字の再監査"):
  if marker in history:history=history[:history.index(marker)].rstrip()
# Old writer accidentally wrote literal "\n" escapes; strip them from historical tail only.
history=history.replace("\\n## 状況設定共通文・制御文字の再監査","")
summary=f"""# 看護師国家試験｜RELEASE_STATUS

更新：2026-11-24 JST　**最終送信禁止／リリース判定 PREFLIGHT_BLOCKED**

## 現時点の問題バンク（全1,200問）

| 種別 | 件数 | 公開範囲 |
|---|---:|---|
| 既存第115〜113回ソースバンク | 720 | 既存ランタイム、厳格原典監査629 PASS／91 HOLD |
| 今回の監査前の検証済みソース拡張 | {ext-P["newPromoted"]} | 履歴を保持、配信不可 |
| **今回の追加昇格** | **{P["newPromoted"]}** | 共通文・制御文字と二方式・公式正答の再検証 |
| **正規ソースバンク** | **{total} / 1,200** | ソース拡張{ext}問を含む |
| **未昇格** | **{len(hold)}問** | 原典の疑義と未合格ゲートは保持 |
| アプリへの今回の追加配信 | 0問 | 解説・図版権利・アプリ／iOSゲート未完了 |

- GitHub Actions Run：{run_id}。先行再抽出22問のうち**{len(active_pending)}問**が引き続き保留。
- 正規ソース：\`product-content/verified-additions-20261124.json\`。保留：\`audit/dual-engine-hold-20261124.json\`。
- 昇格台帳：\`audit/dual-engine-promotion-ledger-20261124.json\`。全新規問の\`publishable=false\`、\`releaseEligible=false\`を維持。
- 制御文字について、両抽出方式が同一の壊れたPDF文字対応表を共有する危険があるため、未確認の原典文字は自動合格としない。

"""
tail=f"""
## 今回の独立共通文・制御文字監査（Run {run_id}）

- 追加昇格 **{P["newPromoted"]}問**、合計 **{total}/1,200問**。残り **{len(hold)}問**。
- 昇格ID：{", ".join(P["newIds"]) if P["newIds"] else "なし"}。
- 保留の多い理由（重複あり）：{", ".join(f"{k} {v}" for k,v in reasons.most_common(12))}。
- 先行再抽出候補：22問のうち残存保留{len(active_pending)}問。権利・解説・アプリ配信ゲートの自動解除は行わない。
"""
if OCR_CATEGORY.exists():
    report=json.loads(OCR_CATEGORY.read_text(encoding="utf8"))
    tail+=("\n## OCR区分別再監査（Run "+str(run_id)+"）\n\n"
      "- 対象："+str(report["checked"])+"問。新規昇格："+str(report["newlyPromoted"])+"問。\n"
      "- 区分："+", ".join(k+" "+str(v) for k,v in report["categories"].items())+"。\n"
      "- 個別の正答・採点例外、OCR文字単位差分、状況設定共通文画像の証拠："
      +"`audit/ocr-category-deep-review-20261124.json`。\n"
      "- この区分別台帳のみで本文・選択肢の確定や公開フラグ解除はしない。\n")
if OCR_REPAIR.exists():
    proof=json.loads(OCR_REPAIR.read_text(encoding="utf8"))
    tail+=("\n## 画像OCRに基づくCMap欠落修復（Run "+str(run_id)+"）\n\n"
      "- 96問を対象に修正判定。実際のデータ修正・ソース昇格："+str(proof["repairedCount"])+"問。"
      "修正未確定："+str(proof["remainingFrom96"])+"問。\n"
      "- 修正前後の本文・全選択肢："+ "`product-content/ocr-repaired-candidates-20261124.json`。\n"
      "- 原典画像・PDFハッシュ、OCR二設定、公式正答の証拠："
      "`audit/ocr-cmap-repair-ledger-20261124.json`。\n"
      "- OCR修正はソース限定。解説・アプリ表示・権利・Apple申請は保留。\n")
if OCR_COORD.exists():
    proof=json.loads(OCR_COORD.read_text(encoding="utf8"))
    tail+=("\n## OCR問題文・選択肢の座標別修復（Run "+str(run_id)+"）\n\n"
        "- 対象46問、今回の新規昇格："+str(proof["newPromoted"])+"問、累計昇格："+str(proof["cumulativePromoted"])+"問、残り："+str(proof["remaining"])+"問。\n"
        "- 原典各領域のOCR・選択肢座標・修正前後・公式正答の記録："
        "`audit/ocr-coordinate-repair-ledger-20261124.json`、"
        "`product-content/ocr-coordinate-repaired-candidates-20261124.json`。\n"
        "- 合格は原典ソース限定。解説・公開・iOS・Apple審査は保留。\n")
if NONCMAP21.exists():
    e=json.loads(NONCMAP21.read_text(encoding="utf8"))
    tail+=("\n## CMap以外のOCR文字差分21問の原典画像再検証（Run "+str(run_id)+"）\n\n"
      "- 個別検証："+str(e["checkedThisRun"])+"問。今回昇格："+str(e["newlyPromoted"])+"問。"
      "元の21問から未確定："+str(e["remaining"])+"問。\n"
      "- 字句差分と原典画像SHA、PDF二方式と公式正答の証拠："
      "`audit/ocr-noncmap-repair-ledger-20261124.json`。\n"
      "- 修正前後：`product-content/ocr-noncmap-repaired-candidates-20261124.json`。"
      "OCR誤読の疑いがあっても文字を推測で置換したものは昇格しない。\n")
if VISUAL21.exists():
    p=json.loads(VISUAL21.read_text(encoding="utf8"))
    tail+=("\n## 原典PDF画像直接照合で修正したOCR誤認識（Run "+str(run_id)+"）\n\n"
      "- 原典画像目視確認2問のうち、今回の修正・正規ソース昇格："
      +str(p["newPromoted"])+"問。累計："+str(p["cumulativePromoted"])+"問。\n"
      "- 修正前後全文：`product-content/ocr-noncmap-visual-repaired-candidates-20261124.json`。\n"
      "- PDF原典ページ、画像ハッシュ、各選択肢OCR一致、公式正答："
      "`audit/ocr-noncmap-visual-promotion-ledger-20261124.json`。\n"
      "- ソースのみ合格。Apple本審査・一般公開不可。\n")
if VISUAL19.exists():
    p=json.loads(VISUAL19.read_text(encoding="utf8"))
    tail+=("\n## CMap以外の文字不一致19問の原典画像逐問修復（Run "+str(run_id)+"）\n\n"
      "- 原典ページ画像の逐問照合19問。今回の新規ソース昇格："+str(p["newPromoted"])+"問、"
      "累計："+str(p["cumulativePromoted"])+"問、未確定："+str(p["remainingFrom19"])+"問。\n"
      "- 第112回午後77は公式原典に従い5選択肢として保持。英語小注記は問題・肢本文とは別に保持。\n"
      "- 公式問題画像・各選択肢のOCR座標証拠・公式正答："
      "`audit/ocr-noncmap-19-promotion-ledger-20261124.json`。\n"
      "- 全問の修正前後：`product-content/ocr-noncmap-19-before-after-20261124.json`。"
      "合格は原典ソース限定、アプリ配信・本審査は禁止。\n")
if PSM23.exists():
    p=json.loads(PSM23.read_text(encoding="utf8"))
    tail+=("\n## OCR複数設定不一致23問の原典画像修復（Run "+str(run_id)+"）\n\n"
      "- 原典画像逐問照合23問、新規ソース昇格："+str(p["newPromoted"])+"問、未昇格："+str(p["remainingFrom23"])+"問。\n"
      "- 図版保留："+str(p["mediaHoldCount"])+"問（"+", ".join(q["id"] for q in p["mediaHeld"])+"）。"
      "第112回午前75は5択として保持。\n"
      "- 問題・全選択肢・公式正答・画像ハッシュ・差分："
      "`audit/ocr-psm-disagreement-23-promotion-ledger-20261124.json`、"
      "`product-content/ocr-psm-disagreement-23-before-after-20261124.json`。\n"
      "- ソース検証限定。解説・権利・実アプリ表示と本審査は未承認。\n")
MD.write_text(summary+history+"\n"+tail,encoding="utf8")
print(json.dumps({"canonical":total,"remaining":len(hold),"new":P["newPromoted"],
                  "pending22Remaining":len(active_pending),"svgPending":18},ensure_ascii=False))
