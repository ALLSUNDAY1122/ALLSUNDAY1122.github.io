#!/usr/bin/env python3
import json
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LEGACY_JS = [
    ROOT / "questions-121-150.js", ROOT / "questions-151-180.js",
    ROOT / "questions-181-210.js", ROOT / "questions-211-240.js",
]
EXTRA_JSON = [
    ROOT / "audit/round2-extra-121-140.json", ROOT / "audit/round2-extra-141-160.json",
    ROOT / "audit/round2-extra-161-170.json", ROOT / "audit/round2-extra-171-180.json",
    ROOT / "audit/round2-extra-181-190.json", ROOT / "audit/round2-extra-191-200.json",
]
REBALANCE_JSON = [ROOT / "audit/round2-rebalance-201-216.json", ROOT / "audit/round2-rebalance-217-232.json"]
OUT = ROOT / "audit/data/questions.round2.canonical.json"
RIGHTS = "独自作問。既存過去問本文・選択肢の転載なし。一次資料による事実監査は公開昇格前に実施。"
EXPECTED = {"社会・環境":16,"人体・疾病":26,"食べ物":25,"基礎栄養":14,"応用栄養":16,"栄養教育":13,"臨床栄養":26,"公衆栄養":16,"給食経営":18,"応用力":30}

SELECTED_EXTRA_IDS = (
    {f"KNR2-{n:03d}" for n in range(121,132)} |
    {"KNR2-139","KNR2-140","KNR2-142","KNR2-143","KNR2-144","KNR2-145","KNR2-146"} |
    {f"KNR2-{n:03d}" for n in range(152,166)} |
    {f"KNR2-{n:03d}" for n in range(173,189)}
)

# 400問横断監査で検出した完全一致・高類似を、別の評価能力へ作り直す。
OVERRIDES = {
    "KNR2-019": {
        "question":"動悸と体重減少があり甲状腺機能亢進が疑われる。甲状腺ホルモン過剰でみられやすい変化はどれか。",
        "choices":["基礎代謝の低下","徐脈のみ","低体温のみ","基礎代謝の亢進","胆汁産生の停止"],"correct_index":3,
        "memory_line":"甲状腺ホルモン過剰では代謝が亢進する。","short_reason":"単純な作用暗記ではなく症状から病態を結びつける。",
        "explanation":"甲状腺ホルモンは代謝を高める方向に作用し、過剰では動悸や体重減少などがみられうる。"
    },
    "KNR2-031": {
        "question":"店頭で保健機能食品を比較している。国の個別審査・許可を経た保健用途表示の製品を選びたい。確認すべき区分はどれか。",
        "choices":["特定保健用食品（トクホ）","機能性表示食品","一般食品","栄養機能食品のみ","医薬部外品"],"correct_index":0,
        "memory_line":"トクホは個別審査・許可、機能性表示食品は届出制度。","short_reason":"制度名称の暗記ではなく購入時の区分判断に変える。",
        "explanation":"特定保健用食品は個別の製品について国の審査を経て許可される制度である。"
    },
    "KNR2-056": {
        "question":"3メッツの歩行を1日60分、7日間行った。1週間の身体活動量は何メッツ・時か。",
        "choices":["7","14","21","23","42"],"correct_index":2,
        "memory_line":"メッツ・時＝メッツ×時間（時）。","short_reason":"3×1時間×7日＝21メッツ・時。",
        "explanation":"日常活動を定量化する計算問題として扱い、単なる『動くべき』の暗記から分離する。"
    },
    "KNR2-123": {
        "question":"自治体が健康格差の存在を把握するために行う分析として最も適切なのはどれか。",
        "choices":["地域平均だけを見て終了する","社会経済状況を記録しない","所得・地域などの属性別に健康指標を比較する","格差指標を公表しない","支援利用状況を調べない"],"correct_index":2,
        "memory_line":"格差は平均値だけでなく集団間の差を測る。","short_reason":"施策の前に、誰に差が生じているかを把握する。",
        "explanation":"地域や社会経済的背景などで健康指標を層別し、集団間の差と支援アクセスを把握する。"
    },
    "KNR2-145": {
        "question":"開封した食用油の酸化をできるだけ遅らせる保存方法として適切なのはどれか。",
        "choices":["透明容器で日なたに置く","高温のコンロ横に置く","ふたを開けたまま保存する","空気を混ぜながら保存する","遮光して密栓し熱源を避ける"],"correct_index":4,
        "memory_line":"油脂は光・熱・酸素を避けて保存する。","short_reason":"酸化促進条件の暗記から、保存行動の判断へ変える。",
        "explanation":"光、熱、酸素への曝露を減らすことが油脂の酸化抑制につながる。"
    }
}


def read_js_array(path: Path):
    text = path.read_text(encoding="utf-8")
    marker = ".concat(["
    if marker not in text: raise ValueError(f"concat JSON array not found: {path}")
    start = text.index(marker) + len(".concat(")
    arr, _ = json.JSONDecoder().raw_decode(text[start:])
    return arr


def legacy_to_canonical(q, idx):
    return {"id":f"KNR2-{idx:03d}","round":2,"subject":q["c"],"topic":q["t"],"question":q["q"],"choices":q["a"],"correct_index":q["x"],"memory_line":q.get("m",""),"short_reason":q.get("r",""),"explanation":q.get("d",""),"source_url":q.get("s",""),"reference_date":q.get("y","2026-08-09"),"source_status":"candidate_from_v04_requires_reaudit","origin_type":"draft_original_pending_source_audit","rights_basis":RIGHTS,"audit_status":"candidate_structure","legacy_id":q.get("id")}


def apply_overrides(items):
    for q in items:
        if q["id"] in OVERRIDES:
            q.update(OVERRIDES[q["id"]])
    return items


def main():
    legacy=[]
    for path in LEGACY_JS: legacy.extend(read_js_array(path))
    if len(legacy)!=120: raise SystemExit(f"legacy candidate count mismatch: {len(legacy)}/120")
    out=[legacy_to_canonical(q,i) for i,q in enumerate(legacy,1)]
    selected=[]
    for path in EXTRA_JSON:
        for q in json.loads(path.read_text(encoding="utf-8")):
            if q["id"] in SELECTED_EXTRA_IDS: selected.append(q)
    if len(selected)!=48: raise SystemExit(f"selected extra count mismatch: {len(selected)}/48")
    out.extend(selected)
    rebalance=[]
    for path in REBALANCE_JSON: rebalance.extend(json.loads(path.read_text(encoding="utf-8")))
    if len(rebalance)!=32: raise SystemExit(f"rebalance count mismatch: {len(rebalance)}/32")
    out.extend(rebalance)
    apply_overrides(out)
    if len(out)!=200: raise SystemExit(f"round2 count mismatch: {len(out)}/200")
    ids=[q["id"] for q in out]
    if len(ids)!=len(set(ids)): raise SystemExit("round2 duplicate IDs")
    counts=Counter(q["subject"] for q in out)
    if dict(counts)!=EXPECTED: raise SystemExit(f"round2 distribution mismatch: {dict(counts)}")
    OUT.parent.mkdir(parents=True,exist_ok=True)
    OUT.write_text(json.dumps(out,ensure_ascii=False,indent=2),encoding="utf-8")
    print(f"built round2 {len(out)} questions -> {OUT}")
    print("distribution:",dict(counts))
    print("legacy=120 selected_extra=48 rebalance=32 reserved_extra=32 overrides=5")

if __name__=="__main__": main()
