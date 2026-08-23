"""合成給与明細テンプレート定義（PoC用）。

実在の給与明細・個人情報は一切使用しない。全て架空の会社名・金額で構成した合成データ。
1ケース = レイアウト仕様（描画アイテム＋罫線）＋ 正解値（9項目）。

座標系: A4相当 595x842pt、原点は左上（描画時に各レンダラが変換する）。
"""

from dataclasses import dataclass, field


@dataclass
class Item:
    text: str
    x: float
    y: float
    size: float = 9.0
    align: str = "l"  # l=左寄せ, r=右寄せ, c=中央
    bold: bool = False


@dataclass
class Case:
    id: str
    title: str
    kind: str  # text_pdf | screenshot | photo | image_pdf
    note: str
    items: list = field(default_factory=list)
    lines: list = field(default_factory=list)  # (x0,y0,x1,y1)
    boxes: list = field(default_factory=list)  # (x0,y0,x1,y1)
    truth: dict = field(default_factory=dict)
    render: dict = field(default_factory=dict)  # レンダラ向けオプション


def yen(n):
    return f"{n:,}"


ITEM_KEYS = [
    "basic_pay",
    "overtime",
    "other_allowance",
    "health_insurance",
    "pension",
    "employment_insurance",
    "income_tax",
    "resident_tax",
    "net_pay",
]


# ---------------------------------------------------------------------------
# 描画ヘルパ
# ---------------------------------------------------------------------------

def hline(lines, x0, x1, y):
    lines.append((x0, y, x1, y))


def vline(lines, x, y0, y1):
    lines.append((x, y0, x, y1))


def grid(lines, x0, y0, w, h, rows, cols):
    """rows行 cols列（colsはx相対位置リスト）の罫線を引く。"""
    for i in range(rows + 1):
        hline(lines, x0, x0 + w, y0 + i * h)
    for c in cols:
        vline(lines, x0 + c, y0, y0 + rows * h)
    vline(lines, x0, y0, y0 + rows * h)
    vline(lines, x0 + w, y0, y0 + rows * h)


def rows_block(items, x_label, x_amount, y0, rows, step=18, size=9.5, unit=""):
    """(ラベル, 金額) を縦に並べる。金額は右寄せ。"""
    y = y0
    for label, amount in rows:
        items.append(Item(label, x_label, y, size))
        if amount is not None:
            items.append(Item(f"{amount}{unit}", x_amount, y, size, align="r"))
        y += step
    return y


# ---------------------------------------------------------------------------
# ケース定義
# ---------------------------------------------------------------------------

def case01():
    """Web給与明細PDF: 支給／控除／合計の3ブロック、罫線あり、標準表記。"""
    items, lines = [], []
    items.append(Item("2026年3月分 給与明細書", 60, 60, 14, bold=True))
    items.append(Item("株式会社ミライテック", 60, 84, 9))
    items.append(Item("所属: 開発部    社員番号: 10234    氏名: 山田 太郎 様", 60, 100, 8.5))

    # 支給
    items.append(Item("【支給】", 60, 140, 10, bold=True))
    grid(lines, 60, 150, 240, 18, 6, [150])
    pay = [
        ("基本給", yen(280000)),
        ("時間外手当", yen(42500)),
        ("深夜手当", yen(5200)),
        ("通勤手当", yen(12000)),
        ("住宅手当", yen(15000)),
        ("支給合計", yen(354700)),
    ]
    rows_block(items, 66, 294, 163, pay)

    # 控除
    items.append(Item("【控除】", 330, 140, 10, bold=True))
    grid(lines, 330, 150, 220, 18, 6, [140])
    ded = [
        ("健康保険料", yen(17400)),
        ("厚生年金保険料", yen(32000)),
        ("雇用保険料", yen(2128)),
        ("所得税", yen(7320)),
        ("住民税", yen(18500)),
        ("控除合計", yen(77348)),
    ]
    rows_block(items, 336, 544, 163, ded)

    # 合計
    items.append(Item("【合計】", 60, 290, 10, bold=True))
    grid(lines, 60, 300, 490, 20, 1, [150, 300])
    items.append(Item("差引支給額", 66, 314, 10, bold=True))
    items.append(Item(yen(277352), 540, 314, 11, align="r", bold=True))
    items.append(Item("銀行振込", 220, 314, 9))

    return Case(
        id="case01",
        title="Web明細PDF・3ブロック罫線あり（標準表記）",
        kind="text_pdf",
        note="最も標準的なWeb給与明細PDF。支給/控除が左右ブロック、合計が別行。",
        items=items,
        lines=lines,
        truth=dict(
            basic_pay=280000,
            overtime=47700,
            other_allowance=27000,
            health_insurance=17400,
            pension=32000,
            employment_insurance=2128,
            income_tax=7320,
            resident_tax=18500,
            net_pay=277352,
        ),
    )


def case02():
    """Web給与明細PDF: 横並び2段組、¥記号付き、控除は括弧表記のマイナス。"""
    items, lines = [], []
    items.append(Item("給 与 支 給 明 細 書", 180, 55, 15, bold=True))
    items.append(Item("合同会社ノースゲート", 60, 82, 9))
    items.append(Item("支給日 2026/03/25", 420, 82, 9))

    items.append(Item("支給項目", 70, 120, 10, bold=True))
    items.append(Item("金額", 250, 120, 10, bold=True))
    items.append(Item("控除項目", 330, 120, 10, bold=True))
    items.append(Item("金額", 520, 120, 10, bold=True))
    hline(lines, 60, 550, 128)

    pay = [
        ("基本給額", "¥310,000"),
        ("時間外勤務手当", "¥28,400"),
        ("休日出勤手当", "¥12,000"),
        ("役職手当", "¥30,000"),
        ("通勤手当", "¥8,600"),
        ("総支給額", "¥389,000"),
    ]
    ded = [
        ("健康保険", "(¥19,220)"),
        ("介護保険", "(¥3,100)"),
        ("厚生年金", "(¥35,600)"),
        ("雇用保険", "(¥2,334)"),
        ("所得税", "(¥9,870)"),
        ("住民税", "(¥21,300)"),
    ]
    y = 145
    for i in range(6):
        items.append(Item(pay[i][0], 70, y, 9.5))
        items.append(Item(pay[i][1], 300, y, 9.5, align="r"))
        items.append(Item(ded[i][0], 330, y, 9.5))
        items.append(Item(ded[i][1], 550, y, 9.5, align="r"))
        y += 20
    items.append(Item("控除合計", 330, y, 9.5))
    items.append(Item("(¥91,424)", 550, y, 9.5, align="r"))
    hline(lines, 60, 550, y + 12)

    items.append(Item("差引支給額", 330, y + 34, 11, bold=True))
    items.append(Item("¥297,576", 550, y + 34, 12, align="r", bold=True))

    return Case(
        id="case02",
        title="Web明細PDF・2段組（支給/控除を左右に並列）+ 括弧マイナス表記",
        kind="text_pdf",
        note="同一行に支給ラベル・支給額・控除ラベル・控除額が並ぶ。行内の項目境界判定が必要。",
        items=items,
        lines=lines,
        truth=dict(
            basic_pay=310000,
            overtime=40400,
            other_allowance=38600,
            health_insurance=19220,
            pension=35600,
            employment_insurance=2334,
            income_tax=9870,
            resident_tax=21300,
            net_pay=297576,
        ),
    )


def case03():
    """Web給与明細PDF: 縦1列のラベル/値ペア。金額は右端寄せで距離が遠い。"""
    items, lines = [], []
    items.append(Item("サンライズ商事株式会社", 60, 60, 11, bold=True))
    items.append(Item("2026年3月度 給与明細", 60, 82, 12, bold=True))
    hline(lines, 60, 535, 95)

    rows = [
        ("本給", "280,000円"),
        ("残業手当", "36,750円"),
        ("家族手当", "20,000円"),
        ("資格手当", "10,000円"),
        ("支給額計", "346,750円"),
        ("健保料", "16,900円"),
        ("厚年保険料", "31,110円"),
        ("雇用保険料", "2,080円"),
        ("源泉所得税", "6,930円"),
        ("市県民税", "15,800円"),
        ("控除額計", "72,820円"),
        ("差引支給額", "273,930円"),
    ]
    y = 120
    for label, amount in rows:
        items.append(Item(label, 70, y, 10))
        items.append(Item(amount, 530, y, 10, align="r"))
        y += 24
    hline(lines, 60, 535, y - 34)

    return Case(
        id="case03",
        title="Web明細PDF・縦1列ラベル/値、金額右端（ラベルとの距離が大）",
        kind="text_pdf",
        note="ラベルと金額が同一行だが水平距離が離れている。円記号付き。",
        items=items,
        lines=lines,
        truth=dict(
            basic_pay=280000,
            overtime=36750,
            other_allowance=30000,
            health_insurance=16900,
            pension=31110,
            employment_insurance=2080,
            income_tax=6930,
            resident_tax=15800,
            net_pay=273930,
        ),
    )


def case04():
    """Web給与明細PDF: 略語中心のクラウド勤怠系レイアウト。項目が横並び（列ヘッダ+値行）。"""
    items, lines = [], []
    items.append(Item("PAYSLIP / 給与明細", 60, 55, 13, bold=True))
    items.append(Item("株式会社アオゾラワークス", 60, 78, 9))
    items.append(Item("対象期間 2026-02-16 ~ 2026-03-15", 330, 78, 9))

    # 支給: 列ヘッダの下に金額（縦方向の対応関係）
    items.append(Item("＜支給＞", 60, 120, 10, bold=True))
    heads = ["本給", "時間外", "深夜残業", "通勤費", "食事手当"]
    vals = ["295,000", "51,200", "8,400", "10,500", "6,000"]
    x = 70
    for h, v in zip(heads, vals):
        items.append(Item(h, x, 140, 9))
        items.append(Item(v, x + 60, 162, 9, align="r"))
        x += 95
    grid(lines, 60, 130, 480, 20, 2, [95, 190, 285, 380])
    items.append(Item("支給計", 60, 200, 9, bold=True))
    items.append(Item("371,100", 200, 200, 9, align="r"))

    items.append(Item("＜控除＞", 60, 240, 10, bold=True))
    heads2 = ["健保", "厚年", "雇保", "所得税", "市民税"]
    vals2 = ["18,500", "34,100", "2,226", "8,240", "19,700"]
    x = 70
    for h, v in zip(heads2, vals2):
        items.append(Item(h, x, 260, 9))
        items.append(Item(v, x + 60, 282, 9, align="r"))
        x += 95
    grid(lines, 60, 250, 480, 20, 2, [95, 190, 285, 380])
    items.append(Item("控除計", 60, 320, 9, bold=True))
    items.append(Item("82,766", 200, 320, 9, align="r"))

    items.append(Item("振込額", 330, 360, 11, bold=True))
    items.append(Item("288,334", 540, 360, 12, align="r", bold=True))

    return Case(
        id="case04",
        title="Web明細PDF・略語表記＋列ヘッダ縦対応（金額がラベルの下）",
        kind="text_pdf",
        note="健保/厚年/雇保/市民税など略語。ラベルの真下に金額があり、同一行探索では取れない。",
        items=items,
        lines=lines,
        truth=dict(
            basic_pay=295000,
            overtime=59600,
            other_allowance=16500,
            health_insurance=18500,
            pension=34100,
            employment_insurance=2226,
            income_tax=8240,
            resident_tax=19700,
            net_pay=288334,
        ),
    )


def case05():
    """スクリーンショット: Web明細画面の標準表。"""
    items, lines = [], []
    items.append(Item("給与明細 2026年3月", 50, 50, 14, bold=True))
    items.append(Item("株式会社ハルカゼ", 50, 74, 9.5))
    items.append(Item("支給", 50, 110, 11, bold=True))
    grid(lines, 45, 120, 480, 22, 6, [280])
    pay = [
        ("基本給", "265,000"),
        ("残業手当", "38,900"),
        ("通勤手当", "9,800"),
        ("家族手当", "18,000"),
        ("皆勤手当", "5,000"),
        ("支給合計", "336,700"),
    ]
    y = 136
    for label, amount in pay:
        items.append(Item(label, 55, y, 10.5))
        items.append(Item(amount, 515, y, 10.5, align="r"))
        y += 22

    items.append(Item("控除", 50, 290, 11, bold=True))
    grid(lines, 45, 300, 480, 22, 6, [280])
    ded = [
        ("健康保険", "16,050"),
        ("厚生年金", "30,300"),
        ("雇用保険", "2,020"),
        ("所得税", "6,540"),
        ("住民税", "14,900"),
        ("控除合計", "69,810"),
    ]
    y = 316
    for label, amount in ded:
        items.append(Item(label, 55, y, 10.5))
        items.append(Item(amount, 515, y, 10.5, align="r"))
        y += 22

    items.append(Item("差引支給額", 55, 470, 12, bold=True))
    items.append(Item("266,890", 515, 470, 13, align="r", bold=True))
    lines.append((45, 450, 525, 450))

    return Case(
        id="case05",
        title="スクリーンショット・Web明細標準表（OCR）",
        kind="screenshot",
        note="PC画面のスクリーンショット想定。文字は鮮明でOCR条件は良好。",
        items=items,
        lines=lines,
        render=dict(width=600, height=520, scale=2.4),
        truth=dict(
            basic_pay=265000,
            overtime=38900,
            other_allowance=32800,
            health_insurance=16050,
            pension=30300,
            employment_insurance=2020,
            income_tax=6540,
            resident_tax=14900,
            net_pay=266890,
        ),
    )


def case06():
    """スクリーンショット: 低コントラスト（薄いグレー文字）。"""
    items, lines = [], []
    items.append(Item("MY PAGE / 給与明細", 45, 45, 13, bold=True))
    items.append(Item("有限会社ミナトサービス", 45, 70, 9.5))
    rows = [
        ("基本給", "242,000"),
        ("時間外手当", "24,600"),
        ("休日手当", "9,800"),
        ("通勤手当", "7,400"),
        ("総支給額", "283,800"),
        ("健康保険料", "14,800"),
        ("厚生年金保険料", "27,900"),
        ("雇用保険料", "1,702"),
        ("所得税", "5,120"),
        ("住民税", "12,600"),
        ("控除合計", "62,122"),
        ("手取額", "221,678"),
    ]
    y = 110
    for label, amount in rows:
        items.append(Item(label, 55, y, 10.5))
        items.append(Item(amount, 480, y, 10.5, align="r"))
        lines.append((45, y + 14, 500, y + 14))
        y += 28

    return Case(
        id="case06",
        title="スクリーンショット・低コントラスト（薄いグレー文字）（OCR）",
        kind="screenshot",
        note="文字色が薄くOCRの文字欠落が起きやすい条件。手取額という表記ゆれを含む。",
        items=items,
        lines=lines,
        render=dict(width=540, height=470, scale=2.4, fg=(120, 120, 128), bg=(248, 248, 250),
                    line_color=(215, 215, 220)),
        truth=dict(
            basic_pay=242000,
            overtime=34400,
            other_allowance=7400,
            health_insurance=14800,
            pension=27900,
            employment_insurance=1702,
            income_tax=5120,
            resident_tax=12600,
            net_pay=221678,
        ),
    )


def case07():
    """スクリーンショット: スマホ縦長。ラベル左端、金額右端で距離が遠い。"""
    items, lines = [], []
    items.append(Item("給与明細", 25, 40, 15, bold=True))
    items.append(Item("2026年3月 / ワカバ物流株式会社", 25, 66, 8.5))
    sections = [
        ("支給", [("基本給", "228,000"), ("残業代", "31,500"), ("深夜割増", "4,300"),
                  ("通勤手当", "11,200"), ("支給合計", "275,000")]),
        ("控除", [("健保", "13,900"), ("厚年", "26,300"), ("雇保", "1,650"),
                  ("源泉税", "4,880"), ("市県民税", "11,400"), ("控除合計", "58,130")]),
        ("お支払い", [("振込額", "216,870")]),
    ]
    y = 100
    for title, rows in sections:
        items.append(Item(title, 25, y, 11, bold=True))
        y += 24
        for label, amount in rows:
            items.append(Item(label, 30, y, 10))
            items.append(Item(amount, 330, y, 10, align="r"))
            lines.append((25, y + 13, 335, y + 13))
            y += 26
        y += 12

    return Case(
        id="case07",
        title="スクリーンショット・スマホ縦長（ラベル左端/金額右端）（OCR）",
        kind="screenshot",
        note="スマホWeb明細。行の左右端に離れて配置。略語＋残業代/振込額の表記ゆれ。",
        items=items,
        lines=lines,
        render=dict(width=360, height=520, scale=3.0),
        truth=dict(
            basic_pay=228000,
            overtime=35800,
            other_allowance=11200,
            health_insurance=13900,
            pension=26300,
            employment_insurance=1650,
            income_tax=4880,
            resident_tax=11400,
            net_pay=216870,
        ),
    )


def case08():
    """紙明細の写真: 傾き・ノイズ・影あり、罫線ありの表。"""
    items, lines = [], []
    items.append(Item("給 与 明 細 書", 150, 45, 14, bold=True))
    items.append(Item("トウカイ精機株式会社", 40, 72, 9))
    items.append(Item("2026年 3月分", 330, 72, 9))
    grid(lines, 40, 100, 440, 24, 7, [220])
    rows = [
        ("基本給", "252,000"),
        ("超過勤務手当", "45,300"),
        ("職務手当", "22,000"),
        ("通勤手当", "6,800"),
        ("支給額合計", "326,100"),
        ("健康保険料", "15,900"),
        ("厚生年金保険料", "30,000"),
    ]
    y = 118
    for label, amount in rows:
        items.append(Item(label, 50, y, 10))
        items.append(Item(amount, 470, y, 10, align="r"))
        y += 24
    grid(lines, 40, 268, 440, 24, 5, [220])
    rows2 = [
        ("雇用保険料", "1,956"),
        ("所得税", "6,180"),
        ("住民税", "13,700"),
        ("控除額合計", "67,736"),
        ("差引支給額", "258,364"),
    ]
    y = 286
    for label, amount in rows2:
        items.append(Item(label, 50, y, 10))
        items.append(Item(amount, 470, y, 10, align="r"))
        y += 24

    return Case(
        id="case08",
        title="紙明細の写真・傾き＋ノイズ＋影（OCR）",
        kind="photo",
        note="紙をスマホで撮影した想定。回転2.5度、影グラデーション、ガウシアンノイズ。",
        items=items,
        lines=lines,
        render=dict(width=520, height=430, scale=2.6, rotate=2.5, noise=4, shadow=0.15, blur=0.3),
        truth=dict(
            basic_pay=252000,
            overtime=45300,
            other_allowance=28800,
            health_insurance=15900,
            pension=30000,
            employment_insurance=1956,
            income_tax=6180,
            resident_tax=13700,
            net_pay=258364,
        ),
    )


def case09():
    """紙明細の写真: 罫線なし・等幅ドットプリンタ風。表構造が取れない。"""
    items, lines = [], []
    items.append(Item("キタヤマ工業  給与支払明細書  2026-03", 30, 40, 10))
    rows = [
        ("基準給        252000", None),
        ("所定外        38400", None),
        ("休日出勤      12600", None),
        ("通勤費         5400", None),
        ("支給計       308400", None),
        ("健康保険      15100", None),
        ("厚生年金      28400", None),
        ("雇用保険       1850", None),
        ("所得税         5760", None),
        ("地方税        12900", None),
        ("控除計        64010", None),
        ("差引支給     244390", None),
    ]
    y = 80
    for label, _ in rows:
        items.append(Item(label, 40, y, 10.5))
        y += 26

    return Case(
        id="case09",
        title="紙明細の写真・罫線なし等幅（ドットプリンタ風）（OCR）",
        kind="photo",
        note="罫線が無く、桁区切りも無い。ラベルと金額が空白で区切られるのみ。",
        items=items,
        lines=lines,
        render=dict(width=420, height=420, scale=2.8, rotate=-1.5, noise=5, shadow=0.10,
                    blur=0.35, mono=True),
        truth=dict(
            basic_pay=252000,
            overtime=51000,
            other_allowance=5400,
            health_insurance=15100,
            pension=28400,
            employment_insurance=1850,
            income_tax=5760,
            resident_tax=12900,
            net_pay=244390,
        ),
    )


def case10():
    """画像PDF（スキャン）: 2段組＋合計が別枠＋△マイナス表記。"""
    items, lines = [], []
    items.append(Item("給与明細書（2026年3月）", 60, 45, 13, bold=True))
    items.append(Item("株式会社セイリュウ建設", 60, 70, 9))

    items.append(Item("支給", 60, 105, 10, bold=True))
    items.append(Item("控除", 300, 105, 10, bold=True))
    grid(lines, 55, 115, 220, 22, 6, [130])
    grid(lines, 295, 115, 220, 22, 6, [140])
    pay = [
        ("基本給", "302,000"),
        ("時間外手当", "56,800"),
        ("現場手当", "25,000"),
        ("通勤手当", "9,200"),
        ("皆勤手当", "5,000"),
        ("支給合計", "398,000"),
    ]
    ded = [
        ("健康保険料", "18,900"),
        ("厚生年金保険料", "35,200"),
        ("雇用保険料", "2,388"),
        ("所得税", "10,240"),
        ("住民税", "22,800"),
        ("控除合計", "89,528"),
    ]
    y = 131
    for i in range(6):
        items.append(Item(pay[i][0], 62, y, 9.5))
        items.append(Item(pay[i][1], 268, y, 9.5, align="r"))
        items.append(Item(ded[i][0], 302, y, 9.5))
        items.append(Item("△" + ded[i][1], 508, y, 9.5, align="r"))
        y += 22

    lines.append((55, 285, 515, 285))
    items.append(Item("差引支給額（振込）", 62, 305, 11, bold=True))
    items.append(Item("308,472", 508, 305, 12, align="r", bold=True))
    lines.append((55, 320, 515, 320))

    return Case(
        id="case10",
        title="画像PDF（スキャン）・2段組＋△マイナス表記（OCR）",
        kind="image_pdf",
        note="テキストを持たないスキャンPDF。PDF直接抽出が失敗しOCR経路へフォールバックする。",
        items=items,
        lines=lines,
        render=dict(width=560, height=360, scale=2.6, noise=3, blur=0.3, rotate=0.8),
        truth=dict(
            basic_pay=302000,
            overtime=56800,
            other_allowance=39200,
            health_insurance=18900,
            pension=35200,
            employment_insurance=2388,
            income_tax=10240,
            resident_tax=22800,
            net_pay=308472,
        ),
    )


ALL_CASES = [case01, case02, case03, case04, case05, case06, case07, case08, case09, case10]


def build_all():
    return [fn() for fn in ALL_CASES]
