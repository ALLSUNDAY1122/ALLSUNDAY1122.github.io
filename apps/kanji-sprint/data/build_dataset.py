#!/usr/bin/env python3
"""Build the 1,026 kyoiku-kanji dataset for the elementary kanji app.

Sources (kept in data/raw/):
- KANJIDIC2 (EDRDG, CC BY-SA 4.0): grade, readings, stroke counts.
  https://www.edrdg.org/kanjidic/kanjidic2.xml.gz
- KanjiVG (Ulrich Apel et al., CC BY-SA 3.0): stroke-order paths, 109x109 box.
  https://github.com/KanjiVG/kanjivg/releases (r20260714)

Grade assignment follows KANJIDIC2's <grade> (MEXT gakunenbetsu kanji haitouhyou,
2017 notification, in force since 2020). Counts are verified against the official
per-grade totals 80/160/200/202/193/191 = 1026.
"""
import gzip
import json
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

RAW = Path(__file__).parent / "raw"
OUT = Path(__file__).parent / "kanji-1026.json"

EXPECTED = {1: 80, 2: 160, 3: 200, 4: 202, 5: 193, 6: 191}

# Grade-1 list as published from the MEXT table (independent cross-check).
GRADE1_CHECK = set("一九七十人二入八力下口三山子女小上夕千川大土円王火月犬五手水 中天日文木六右玉左四出正生石田白本目立気休糸字耳先早竹虫年百名花貝見車赤足村男町雨学金空青林音草校森".replace(" ", ""))

# Kanji moved/added into grade 4 by the 2020 revision (prefecture names etc.).
GRADE4_2020 = set("茨媛潟岐熊埼崎滋栃奈梨阪阜縄")

def load_kanjidic2():
    with gzip.open(RAW / "kanjidic2.xml.gz", "rb") as f:
        root = ET.parse(f).getroot()
    entries = {}
    for ch in root.iter("character"):
        misc = ch.find("misc")
        grade_el = misc.find("grade") if misc is not None else None
        if grade_el is None:
            continue
        grade = int(grade_el.text)
        if grade not in EXPECTED:
            continue
        literal = ch.findtext("literal")
        sc = misc.find("stroke_count")
        stroke_count = int(sc.text) if sc is not None else None
        on, kun = [], []
        rm = ch.find("reading_meaning")
        if rm is not None:
            for r in rm.iter("reading"):
                if r.get("r_type") == "ja_on":
                    on.append(r.text)
                elif r.get("r_type") == "ja_kun":
                    # strip okurigana markers: "あ.げる" -> keep full form for study use
                    kun.append(r.text)
        entries[literal] = {
            "kanji": literal,
            "grade": grade,
            "strokeCount": stroke_count,
            "on": on,
            "kun": kun,
        }
    return entries

def load_kanjivg():
    """Return {kanji_char: [path_d, ...]} in stroke order."""
    strokes = {}
    with gzip.open(RAW / "kanjivg.xml.gz", "rb") as f:
        data = f.read().decode("utf-8")
    # KanjiVG XML: <kanji id="kvg:kanji_04e00"> ... paths id="kvg:04e00-s1" d="..."
    for m in re.finditer(r'<kanji id="kvg:kanji_([0-9a-f]+)">(.*?)</kanji>', data, re.S):
        code = chr(int(m.group(1), 16))
        paths = re.findall(r'<path[^>]*\bd="([^"]+)"', m.group(2))
        if paths:
            strokes[code] = paths
    return strokes

def main():
    dic = load_kanjidic2()
    counts = {g: 0 for g in EXPECTED}
    for e in dic.values():
        counts[e["grade"]] += 1
    print("per-grade counts:", counts)
    assert counts == EXPECTED, f"count mismatch: {counts} != {EXPECTED}"
    assert len(dic) == 1026, f"total {len(dic)} != 1026"

    g1 = {k for k, e in dic.items() if e["grade"] == 1}
    assert g1 == GRADE1_CHECK, f"grade1 mismatch: extra={g1 - GRADE1_CHECK} missing={GRADE1_CHECK - g1}"
    print("grade 1 set matches the published MEXT list (80 chars)")

    g4 = {k for k, e in dic.items() if e["grade"] == 4}
    assert GRADE4_2020 <= g4, f"2020 grade-4 additions missing: {GRADE4_2020 - g4}"
    print("2020 grade-4 additions all present:", "".join(sorted(GRADE4_2020)))

    vg = load_kanjivg()
    print(f"KanjiVG entries parsed: {len(vg)}")
    missing, mismatch = [], []
    out = []
    for e in sorted(dic.values(), key=lambda x: (x["grade"], x["kanji"])):
        paths = vg.get(e["kanji"])
        if not paths:
            missing.append(e["kanji"])
            paths = []
        elif e["strokeCount"] is not None and len(paths) != e["strokeCount"]:
            mismatch.append((e["kanji"], e["strokeCount"], len(paths)))
        e = dict(e)
        e["strokes"] = paths
        out.append(e)
    print("kanji without KanjiVG strokes:", missing)
    print("stroke-count mismatches (kanjidic2 vs kanjivg):", mismatch)

    OUT.write_text(json.dumps({"kanji": out}, ensure_ascii=False, indent=1), encoding="utf-8")
    print(f"wrote {OUT} ({OUT.stat().st_size:,} bytes, {len(out)} entries)")

if __name__ == "__main__":
    main()
