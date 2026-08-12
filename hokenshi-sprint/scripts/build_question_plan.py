#!/usr/bin/env python3
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "content" / "question-plan.generated.json"

SUBJECTS = [
    ("A", "公衆衛生看護学概論", [
        ("地域診断と健康課題の優先順位", ["S03"]),
        ("PDCAサイクルによる地域保健施策", ["S03"]),
        ("個別課題から地域課題への展開", ["S03"]),
        ("予防的介入と早期支援", ["S03"]),
        ("住民主体・自助・共助の支援", ["S03", "S04"]),
        ("健康格差と社会環境への働きかけ", ["S05"]),
        ("健康寿命の延伸", ["S05"]),
        ("ポピュレーションアプローチとハイリスクアプローチ", ["S05", "S06"]),
        ("多職種・多機関連携", ["S03", "S04"]),
        ("保健師の地区担当制・横断的活動", ["S03"]),
        ("エビデンスと住民ニーズを統合した意思決定", ["S03", "S05"]),
    ]),
    ("B", "公衆衛生看護方法論I", [
        ("家庭訪問の目的と事前準備", ["S03"]),
        ("家族全体を捉えるアセスメント", ["S03"]),
        ("本人の意思決定支援", ["S06"]),
        ("行動変容段階に応じた保健指導", ["S06"]),
        ("健康相談における傾聴と課題整理", ["S03", "S06"]),
        ("ケースマネジメントと支援調整", ["S03"]),
        ("グループ形成初期の支援", ["S03"]),
        ("セルフヘルプグループへの支援", ["S03"]),
        ("ハイリスク者の継続支援", ["S06"]),
        ("スクリーニング後のフォローアップ", ["S06"]),
        ("支援拒否・接触困難事例への継続的アプローチ", ["S03"]),
    ]),
    ("C", "公衆衛生看護方法論II", [
        ("地域診断の情報源", ["S03", "S11"]),
        ("定量データと定性データの統合", ["S03"]),
        ("健康課題の優先順位づけ", ["S03"]),
        ("事業目標・評価指標の設定", ["S03", "S06"]),
        ("プロセス評価", ["S06"]),
        ("アウトカム評価", ["S06"]),
        ("住民組織との協働", ["S03"]),
        ("地域資源の把握とネットワーク化", ["S03", "S04"]),
        ("事業化・予算化への展開", ["S03"]),
        ("施策化と庁内連携", ["S03", "S04"]),
        ("アカウンタビリティと情報公開", ["S04"]),
    ]),
    ("D", "対象別公衆衛生看護活動論", [
        ("妊産婦への切れ目ない支援", ["S12"]),
        ("乳幼児健康診査後の支援", ["S12"]),
        ("児童虐待予防における早期支援", ["S12"]),
        ("高齢者の介護予防・地域支援", ["S12"]),
        ("精神保健相談と地域生活支援", ["S12"]),
        ("自殺予防と地域連携", ["S12"]),
        ("難病患者と家族への地域支援", ["S12"]),
        ("結核・感染症患者への支援", ["S07", "S12"]),
        ("生活習慣病の発症・重症化予防", ["S05", "S06"]),
        ("がん検診の受診勧奨と精検フォロー", ["S05", "S12"]),
        ("歯・口腔の健康づくり", ["S05"]),
    ]),
    ("E", "学校保健・産業保健", [
        ("学校健康診断の目的", ["S09"]),
        ("健康診断時のプライバシー配慮", ["S09"]),
        ("学校における健康相談・保健指導", ["S09"]),
        ("学校保健関係者の連携", ["S09"]),
        ("職場の健康診断と事後措置", ["S10", "S12"]),
        ("ストレスチェック制度", ["S10"]),
        ("小規模事業場へのストレスチェック義務化時期", ["S10"]),
        ("作業環境管理・作業管理・健康管理", ["S10", "S12"]),
        ("メンタルヘルス不調者の職場復帰支援", ["S10"]),
        ("長時間労働者への健康確保措置", ["S10", "S12"]),
        ("地域・職域連携", ["S04", "S10"]),
    ]),
    ("F", "健康危機管理", [
        ("健康危機発生時の初動", ["S04", "S08"]),
        ("避難所ラピッドアセスメント", ["S08"]),
        ("避難所の衛生・感染症対策", ["S08"]),
        ("要配慮者の把握と支援", ["S08"]),
        ("保健師の応援派遣・受援", ["S08"]),
        ("DHEAT等との連携", ["S08"]),
        ("IHEAT等の人材活用", ["S04"]),
        ("感染症発生動向調査", ["S07"]),
        ("積極的疫学調査", ["S07"]),
        ("リスクコミュニケーション", ["S04", "S08"]),
        ("平時からの健康危機対応体制整備", ["S04", "S08"]),
    ]),
    ("G", "公衆衛生看護管理論", [
        ("統括保健師の役割", ["S03", "S08"]),
        ("人員配置と業務量の把握", ["S03"]),
        ("人材育成・能力開発", ["S03"]),
        ("新任保健師への支援体制", ["S03"]),
        ("ケースの組織的共有", ["S03"]),
        ("個人情報・記録の管理", ["S03", "S12"]),
        ("事業の予算管理", ["S03"]),
        ("業務の標準化と質改善", ["S03"]),
        ("健康危機時の指揮命令系統", ["S08"]),
        ("応援職員の受援調整", ["S08"]),
        ("部署横断・自治体間連携", ["S03", "S04"]),
    ]),
    ("H", "疫学", [
        ("罹患率と有病率", ["S01", "S07"]),
        ("累積罹患率と人年法の考え方", ["S01"]),
        ("相対危険・リスク比", ["S01"]),
        ("オッズ比", ["S01"]),
        ("感度", ["S01"]),
        ("特異度", ["S01"]),
        ("陽性的中率と有病割合の関係", ["S01"]),
        ("コホート研究", ["S01"]),
        ("症例対照研究", ["S01"]),
        ("交絡", ["S01"]),
        ("選択バイアス・情報バイアス", ["S01"]),
    ]),
    ("I", "保健統計", [
        ("人口動態統計の対象", ["S11"]),
        ("粗死亡率", ["S11"]),
        ("年齢調整死亡率", ["S11"]),
        ("標準化死亡比（SMR）", ["S11"]),
        ("平均寿命と健康寿命", ["S05", "S11"]),
        ("合計特殊出生率", ["S11"]),
        ("乳児死亡率", ["S11"]),
        ("患者調査", ["S11"]),
        ("国民健康・栄養調査", ["S05", "S11"]),
        ("割合・率・比の分母", ["S11"]),
        ("地域比較で年齢構成を考慮する必要性", ["S11"]),
    ]),
    ("J", "保健医療福祉行政論", [
        ("地域保健法と保健所・市町村保健センター", ["S04", "S12"]),
        ("健康増進法と健康増進計画", ["S05", "S12"]),
        ("母子保健法と母子保健サービス", ["S12"]),
        ("感染症法と届出・調査", ["S07", "S12"]),
        ("医療法と医療提供体制", ["S12"]),
        ("介護保険法と保険者", ["S12"]),
        ("国民健康保険の保険者", ["S12"]),
        ("後期高齢者医療制度", ["S12"]),
        ("障害福祉制度と地域生活支援", ["S12"]),
        ("生活保護制度と実施機関", ["S12"]),
        ("保健師助産師看護師法における保健師", ["S12"]),
    ]),
]

FOUR_SITUATIONAL = {
    1: {"A", "C", "D", "F", "H"},
    2: {"B", "D", "E", "G", "I"},
    3: {"A", "B", "E", "H", "J"},
}


def selected_situational_indices(round_no: int, count: int) -> list[int]:
    if round_no == 1:
        return list(range(11 - count, 11))
    if round_no == 2:
        start = 4
        return list(range(start, start + count))
    return list(range(0, count))


def taxonomy(round_no: int, question_type: str, topic_index: int) -> str:
    if question_type == "situational":
        return ["II", "III"][(round_no + topic_index) % 2]
    return ["I", "I-prime", "II"][(round_no + topic_index) % 3]


def build_round(round_no: int) -> list[dict]:
    rows: list[dict] = []
    extras: list[dict] = []
    question_number = 1

    for code, subject, topics in SUBJECTS:
        situational_count = 4 if code in FOUR_SITUATIONAL[round_no] else 3
        selected = selected_situational_indices(round_no, situational_count)
        core_situational = set(selected[:3])
        extra_situational = set(selected[3:])
        core_scenario_id = f"HOK-R{round_no}-SC-{code}"

        core_position = 0
        for topic_index, (topic, source_refs) in enumerate(topics):
            is_situational = topic_index in set(selected)
            row = {
                "id": f"HOK-R{round_no}-{code}-{topic_index + 1:02d}",
                "round": round_no,
                "question_number": question_number,
                "subject_code": code,
                "subject": subject,
                "topic": topic,
                "question_type": "situational" if is_situational else "general",
                "taxonomy": taxonomy(round_no, "situational" if is_situational else "general", topic_index),
                "source_refs": source_refs,
                "content_version": "hokenshi-plan-2026-08-13",
                "audit_status": "planned",
            }

            if topic_index in core_situational:
                core_position += 1
                row.update({
                    "scenario_id": core_scenario_id,
                    "scenario_index": core_position,
                    "scenario_total": 3,
                })
            elif topic_index in extra_situational:
                extras.append(row)

            rows.append(row)
            question_number += 1

    if len(extras) != 5:
        raise RuntimeError(f"round {round_no}: expected 5 extra situational rows, got {len(extras)}")

    extra_groups = [extras[:3], extras[3:]]
    for group_no, group in enumerate(extra_groups, 1):
        scenario_id = f"HOK-R{round_no}-SC-X{group_no}"
        total = len(group)
        for index, row in enumerate(group, 1):
            row.update({
                "scenario_id": scenario_id,
                "scenario_index": index,
                "scenario_total": total,
            })

    return rows


def build() -> list[dict]:
    rows: list[dict] = []
    for round_no in range(1, 4):
        rows.extend(build_round(round_no))
    return rows


def main() -> None:
    rows = build()
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(rows, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"generated={len(rows)} path={OUT}")


if __name__ == "__main__":
    main()
