#!/usr/bin/env python3
from __future__ import annotations

import re
import extract_r8_official_v3 as v3


def parse_choices_v4(segment: str):
    # PDF抽出では「1．」が「1 ．」になる場合があるため、数字と句点間の空白を許容する。
    markers = list(re.finditer(r"(?<![0-9])([1-6])[ \t　]*[．.]\s*", segment))
    labels = [int(m.group(1)) for m in markers]
    candidates = []

    # 設問資料中の番号付き列を混ぜず、marker列上で隣接した1→2→...の完全連番だけを回答肢候補にする。
    for i in range(len(markers)):
        for n in (6, 5):
            if i + n > len(markers):
                continue
            if labels[i:i+n] == list(range(1, n + 1)):
                candidates.append(markers[i:i+n])

    if not candidates:
        return None, None

    # 6択を5択より優先。同じ長さなら、資料内番号ではなく末尾に近い回答肢列を採用する。
    group = max(candidates, key=lambda g: (len(g), g[0].start()))
    prompt = segment[:group[0].start()].strip()
    choices = []
    for i, marker in enumerate(group):
        start = marker.end()
        end = group[i + 1].start() if i + 1 < len(group) else len(segment)
        choices.append(segment[start:end].strip())
    return prompt, choices


v3.parse_choices = parse_choices_v4
v3.main()
