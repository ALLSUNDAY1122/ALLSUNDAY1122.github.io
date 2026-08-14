#!/usr/bin/env python3
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent
BATCH_DIR = ROOT / "question-batches"
AUDIT_SUFFIX = "重複監査後、同一知識を別角度から問う独立設問へ再構成済み。"

UPDATES = {
    "RIGAKU-R58-PM-041": {
        "prompt": "食事・移乗・歩行など基本的ADLの介助量を経時的に把握したい。目的に合う尺度はどれか。",
        "choices": ["Barthel Index", "Glasgow Coma Scale", "Borg scale", "MMSE", "徒手筋力検査"],
        "correctIndices": [0],
        "memoryPoint": "Barthel Index＝基本的ADLの自立度・介助量を追う尺度。GCSは意識、Borgは自覚的運動強度。",
        "explanation": "Barthel Indexは食事、移乗、移動など基本的日常生活動作の自立度・介助量を評価し、経時変化を追う用途に適する。評価項目表や採点表そのものは本教材へ転載しない。",
    },
    "RIGAKU-R58-PM-047": {
        "prompt": "理学療法士が退職後、在職中に知った患者の秘密を正当な理由なく第三者へ話すことについて正しいのはどれか。",
        "choices": ["退職後も守秘義務が続くため認められない", "退職した時点で自由に話せる", "友人にだけなら自由に話せる", "SNSなら実名でも話せる", "守秘義務は在職中の管理職だけに適用される"],
        "correctIndices": [0],
        "memoryPoint": "PT/OT法16条の守秘義務は、資格・職を離れた後も続く。",
        "explanation": "理学療法士及び作業療法士法16条は、正当な理由なく業務上知り得た人の秘密を漏らすことを禁じ、理学療法士等でなくなった後も同様と定めている。",
    },
    "RIGAKU-R58-PM-088": {
        "prompt": "関節リウマチでMCP関節の慢性炎症が進行した手を観察する。典型的にみられ得る指列の偏位方向はどれか。",
        "choices": ["尺側", "橈側", "掌側だけ", "背側だけ", "上下方向のみ"],
        "correctIndices": [0],
        "memoryPoint": "RAの手ではMCP関節の尺側偏位、スワンネック、ボタン穴変形などがみられ得る。",
        "explanation": "関節リウマチでは慢性滑膜炎と関節・腱周囲組織の障害により、MCP関節で指列が尺側へ偏位する変形を生じ得る。",
    },
    "RIGAKU-R60-PM-050": {
        "prompt": "感染症が未診断の患者から採血する。感染対策として最も適切なのはどれか。",
        "choices": ["診断の有無にかかわらず標準予防策を適用する", "感染症が確定するまで手指衛生を行わない", "手袋を使えば手指衛生は不要である", "血液曝露リスクを評価しない", "使用後の器具を患者間でそのまま共用する"],
        "correctIndices": [0],
        "memoryPoint": "標準予防策は感染症の診断前から全患者へ適用し、手指衛生と曝露リスクに応じたPPEを行う。",
        "explanation": "標準予防策は感染症の診断や推定感染状態にかかわらず、すべての患者ケアへ適用する。採血では手指衛生に加え、予想される血液曝露に応じた手袋などを用いる。",
    },
    "RIGAKU-R58-AM-079": {
        "prompt": "Freudの心理性的発達理論で、乳児期に吸啜など口を介した活動へリビドーが向かうとされる段階はどれか。",
        "choices": ["口唇期", "肛門期", "男根期", "潜伏期", "性器期"],
        "correctIndices": [0],
        "memoryPoint": "Freud理論では乳児期の最初の段階を口唇期とする。これは歴史的な心理発達理論として扱う。",
        "explanation": "Freudの心理性的発達理論では、乳児期に口を介した活動へ心理的エネルギーが向かうとされる段階を口唇期と呼ぶ。本教材では歴史的理論モデルとして学び、現代の発達をこの理論だけで説明しない。",
    },
}


def main() -> int:
    found: set[str] = set()
    changed_files: list[str] = []

    for path in sorted(BATCH_DIR.glob("questions-*.json")):
        original = path.read_text(encoding="utf-8")
        data = json.loads(original)
        for question in data:
            sid = question.get("id")
            update = UPDATES.get(sid)
            if update is None:
                continue
            found.add(sid)
            question.update(update)
            if isinstance(question.get("contentAudit"), dict):
                note = str(question["contentAudit"].get("note", "")).strip()
                if AUDIT_SUFFIX not in note:
                    question["contentAudit"]["note"] = (note + " " + AUDIT_SUFFIX).strip()

        rendered = json.dumps(data, ensure_ascii=False, separators=(",", ":")) + "\n"
        if rendered != original:
            path.write_text(rendered, encoding="utf-8")
            changed_files.append(path.name)

    missing = sorted(set(UPDATES) - found)
    if missing:
        raise SystemExit(f"missing question ids: {missing}")

    print(f"target questions found: {len(found)}")
    print(f"changed files: {len(changed_files)}")
    for name in changed_files:
        print(f"- {name}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
