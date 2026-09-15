"""未知形式（holdout）給与明細の生成規則。

PoC（tedorilog-poc/tools/slip_templates.py）とは意図的に別の作り方にしている:
  - PoC: 1形式ずつ手書きでレイアウトを固定
  - ここ: レイアウト原型 × 語彙プール × 金額生成 を乱数（固定シード）で組み合わせる

そのため、PoCで調整したルールがそのまま当たる保証がない。実データの代替ではないが、
「調整に使っていない形式」を作るための最低限の独立性を確保する。

実在の給与明細・個人情報は使用しない。会社名・金額はすべて架空。
"""

import random

# ---------------------------------------------------------------------------
# 語彙プール（PoCの辞書に載っている語・載っていない語を混ぜる）
# ---------------------------------------------------------------------------

BASIC = ["基本給", "基本給与", "本俸", "月例給", "基準内給与", "基本給額"]
OVERTIME = [
    ("時間外手当", 1), ("普通残業", 1), ("時間外勤務手当", 1), ("残業手当", 1),
    ("法定内残業", 1), ("超勤手当", 1), ("所定外賃金", 1),
]
OVERTIME_EXTRA = ["深夜勤務手当", "深夜割増", "休日出勤手当", "法定休日勤務", "休日割増賃金"]
ALLOWANCES = [
    "通勤手当", "通勤費", "住宅手当", "家族手当", "扶養手当", "役職手当", "職務手当",
    "資格手当", "技能手当", "皆勤手当", "精勤手当", "食事補助", "在宅勤務手当",
    "地域手当", "調整手当", "特殊作業手当", "営業手当", "単身赴任手当",
]
HEALTH = ["健康保険料", "健康保険", "健保", "健保料", "健康保険料等"]
PENSION = ["厚生年金保険料", "厚生年金", "厚年", "厚生年金保険", "厚年保険料"]
EMPLOYMENT = ["雇用保険料", "雇用保険", "雇保", "雇用保険料等"]
INCOME_TAX = ["所得税", "源泉所得税", "源泉税", "所得税額"]
RESIDENT_TAX = ["住民税", "市県民税", "特別徴収住民税", "地方税", "市町村民税"]
NET = ["差引支給額", "差引支払額", "銀行振込額", "振込額", "手取額", "差引合計", "お振込金額"]
GROSS_TOTAL = ["総支給額", "支給合計", "支給額計", "支給計", "総支給"]
DEDUCT_TOTAL = ["控除合計", "控除額計", "控除計", "総控除額"]
OTHER_DEDUCTIONS = ["介護保険料", "組合費", "財形貯蓄", "社宅使用料", "団体生命保険料", "共済会費"]

COMPANIES = [
    "株式会社アカツキ工業", "株式会社ヒノデ商会", "合同会社カワセミ設計", "株式会社シラユキ物流",
    "有限会社トキワ電機", "株式会社ミドリ野フーズ", "株式会社ソラチ製作所", "株式会社ハマナス建設",
    "合同会社クロガネ機工", "株式会社アオイ運輸", "株式会社ユキヤナギ製菓", "有限会社スミレ商店",
    "株式会社カエデ情報", "株式会社ナナカマド工房", "株式会社シオカゼ水産",
]

# 勤怠ブロック（金額と紛らわしい数値をあえて混ぜる）
ATTENDANCE = [
    ("出勤日数", "{d}日"), ("欠勤日数", "0日"), ("有給消化", "{p}日"),
    ("時間外時間", "{h}.5時間"), ("深夜時間", "{n}.0時間"), ("総労働時間", "1{t}0.0時間"),
]


def make_amounts(rnd):
    """9項目の正解値を作る。合計は常に整合させる。"""
    basic = rnd.randrange(180, 460) * 1000
    overtime_parts = [rnd.randrange(8, 60) * 100 * 5 for _ in range(rnd.randint(1, 3))]
    allowance_parts = [rnd.randrange(20, 350) * 100 for _ in range(rnd.randint(1, 5))]
    overtime = sum(overtime_parts)
    other = sum(allowance_parts)
    gross = basic + overtime + other

    health = int(gross * rnd.uniform(0.045, 0.055) / 10) * 10
    pension = int(gross * rnd.uniform(0.085, 0.095) / 10) * 10
    employment = int(gross * rnd.uniform(0.005, 0.007))
    income_tax = int(gross * rnd.uniform(0.015, 0.032) / 10) * 10
    resident_tax = int(gross * rnd.uniform(0.03, 0.06) / 100) * 100
    extra_deductions = []
    if rnd.random() < 0.45:
        for name in rnd.sample(OTHER_DEDUCTIONS, rnd.randint(1, 2)):
            extra_deductions.append((name, rnd.randrange(5, 40) * 100))
    deduct_total = health + pension + employment + income_tax + resident_tax + sum(v for _, v in extra_deductions)
    net = gross - deduct_total

    return {
        "truth": {
            "basic_pay": basic,
            "overtime": overtime,
            "other_allowance": other,
            "health_insurance": health,
            "pension": pension,
            "employment_insurance": employment,
            "income_tax": income_tax,
            "resident_tax": resident_tax,
            "net_pay": net,
        },
        "overtime_parts": overtime_parts,
        "allowance_parts": allowance_parts,
        "gross": gross,
        "deduct_total": deduct_total,
        "extra_deductions": extra_deductions,
    }


def money(value, style):
    """表記スタイルを変える。style: plain / yen / comma_none / suffix / paren_minus / triangle"""
    if style == "comma_none":
        return str(value)
    text = f"{value:,}"
    if style == "yen":
        return "¥" + text
    if style == "suffix":
        return text + "円"
    if style == "paren_minus":
        return f"({text})"
    if style == "triangle":
        return "△" + text
    return text


def build_rows(spec, rnd, deduction_style):
    """(区分, ラベル, 金額文字列, 金額値) の行リストを作る。"""
    t = spec["truth"]
    pay_rows = [("pay", rnd.choice(BASIC), spec["truth"]["basic_pay"])]
    ot_labels = [rnd.choice(OVERTIME)[0]] + rnd.sample(OVERTIME_EXTRA, max(0, len(spec["overtime_parts"]) - 1))
    for label, value in zip(ot_labels, spec["overtime_parts"]):
        pay_rows.append(("pay", label, value))
    for label, value in zip(rnd.sample(ALLOWANCES, len(spec["allowance_parts"])), spec["allowance_parts"]):
        pay_rows.append(("pay", label, value))

    ded_rows = [
        ("deduct", rnd.choice(HEALTH), t["health_insurance"]),
        ("deduct", rnd.choice(PENSION), t["pension"]),
        ("deduct", rnd.choice(EMPLOYMENT), t["employment_insurance"]),
        ("deduct", rnd.choice(INCOME_TAX), t["income_tax"]),
        ("deduct", rnd.choice(RESIDENT_TAX), t["resident_tax"]),
    ]
    for name, value in spec["extra_deductions"]:
        ded_rows.insert(rnd.randint(0, len(ded_rows)), ("deduct", name, value))
    return pay_rows, ded_rows
