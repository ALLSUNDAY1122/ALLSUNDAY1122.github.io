#!/usr/bin/env python3
import json
import re
import statistics
import sys
from collections import Counter, defaultdict
from pathlib import Path

HERE = Path(__file__).resolve().parent
TABLES = HERE / "official-scoring-table-summary.json"
SHAPES = HERE / "official-question-shapes-summary.json"
OUT = HERE / "official-scoring-canonical.v1.json"

DIGITS = str.maketrans("０１２３４５６７８９", "0123456789")
LEGAL_GROUPS = ["憲法・行政法", "民法・商法・民事訴訟法", "刑法・刑事訴訟法"]
SUBJECT_RANGES = {
    "憲法・行政法": [(1,12,"憲法"),(13,24,"行政法")],
    "民法・商法・民事訴訟法": [(1,15,"民法"),(16,30,"商法"),(31,45,"民事訴訟法")],
    "刑法・刑事訴訟法": [(1,13,"刑法"),(14,26,"刑事訴訟法")],
}
EXPECTED_SUBJECT_COUNTS = {"憲法":12,"行政法":12,"民法":15,"商法":15,"民事訴訟法":15,"刑法":13,"刑事訴訟法":13}
ANSWER_PDFS = {
    "2024-憲法・行政法":"https://www.moj.go.jp/content/001422569.pdf",
    "2024-民法・商法・民事訴訟法":"https://www.moj.go.jp/content/001422570.pdf",
    "2024-刑法・刑事訴訟法":"https://www.moj.go.jp/content/001422571.pdf",
    "2024-一般教養科目":"https://www.moj.go.jp/content/001422572.pdf",
    "2025-憲法・行政法":"https://www.moj.go.jp/content/001444173.pdf",
    "2025-民法・商法・民事訴訟法":"https://www.moj.go.jp/content/001444174.pdf",
    "2025-刑法・刑事訴訟法":"https://www.moj.go.jp/content/001444175.pdf",
    "2025-一般教養科目":"https://www.moj.go.jp/content/001444176.pdf",
}
PASS_SCORES = {2024:165, 2025:159}
GENERAL_OFFERED = {2024:42, 2025:44}


def num(text):
    return int(str(text).translate(DIGITS))


def kmeans_1d(values, k=4):
    values = sorted(values)
    if len(values) < k:
        raise ValueError(f"too few numeric tokens for {k} columns")
    centers = [values[min(len(values)-1, int((i+0.5)*len(values)/k))] for i in range(k)]
    for _ in range(40):
        groups = [[] for _ in range(k)]
        for value in values:
            index = min(range(k), key=lambda i: abs(value-centers[i]))
            groups[index].append(value)
        new = [statistics.mean(group) if group else centers[i] for i, group in enumerate(groups)]
        if max(abs(a-b) for a,b in zip(new,centers)) < 0.001:
            centers = new
            break
        centers = new
    return sorted(centers)


def full_table(page):
    for table in page.get("tables", []):
        rows = table.get("rows", [])
        if rows and sum(1 for cell in rows[0] if cell == "問") >= 1 and any(cell in ("No", "Ｎｏ.") for cell in rows[0]):
            return rows
    return []


def unordered_questions(page):
    result = set()
    rows = full_table(page)
    if not rows:
        return result
    width = len(rows[0])
    panels = max(1, width // 5)
    current = [None] * panels
    for row in rows[1:]:
        padded = list(row) + [None] * max(0, panels*5-len(row))
        for panel in range(panels):
            segment = padded[panel*5:(panel+1)*5]
            qcell = segment[0]
            if qcell and re.fullmatch(r"[0-9０-９]+", qcell):
                current[panel] = num(qcell)
            note = " ".join(cell or "" for cell in segment[4:5])
            if "順" in note and current[panel] is not None:
                result.add(current[panel])
    return result


def parse_answer_page(document_key, page):
    tokens = page["tokens"]
    headers = sorted([t for t in tokens if t["text"] == "問"], key=lambda t: t["x0"])
    if not headers:
        raise ValueError(f"{document_key}: no table panel headers")
    header_top = min(h["top"] for h in headers)
    q_header_x = [h["x0"] for h in headers]
    numeric_tokens = [t for t in tokens if re.fullmatch(r"[0-9０-９]+", t["text"] or "") and t["top"] > header_top + 3]
    no_answers = {}
    q_points = {}
    q_y = {}
    notes = defaultdict(list)

    numeric_bounds = [-10**9] + [(q_header_x[i]+q_header_x[i+1])/2 for i in range(len(q_header_x)-1)] + [10**9]
    panel_centers = []
    for panel in range(len(headers)):
        values = [t["x0"] for t in numeric_tokens if numeric_bounds[panel] < t["x0"] < numeric_bounds[panel+1]]
        centers = kmeans_1d(values, 4)
        panel_centers.append(centers)
        columns = [[] for _ in range(4)]
        for token in numeric_tokens:
            if not (numeric_bounds[panel] < token["x0"] < numeric_bounds[panel+1]):
                continue
            column = min(range(4), key=lambda i: abs(token["x0"]-centers[i]))
            columns[column].append(token)

        for no_token in columns[1]:
            matches = [answer for answer in columns[2] if abs(answer["top"]-no_token["top"]) < 1.2]
            if matches:
                no = num(no_token["text"])
                answer = num(min(matches,key=lambda t:abs(t["top"]-no_token["top"]))["text"])
                if no in no_answers and no_answers[no] != answer:
                    raise ValueError(f"{document_key}: conflicting answer for No.{no}")
                no_answers[no] = answer

        for q_token in columns[0]:
            matches = [point for point in columns[3] if abs(point["top"]-q_token["top"]) < 1.2]
            if matches:
                question = num(q_token["text"])
                points = num(min(matches,key=lambda t:abs(t["top"]-q_token["top"]))["text"])
                if question in q_points and q_points[question] != points:
                    raise ValueError(f"{document_key}: conflicting points for q{question}")
                q_points[question] = points
                q_y[question] = q_token["top"]

    # Notes live to the right of each panel's points column, up to the next panel.
    for panel, header in enumerate(headers):
        x_low = header["x0"] - 10
        x_high = headers[panel+1]["x0"] - 5 if panel+1 < len(headers) else 10**9
        centers = panel_centers[panel]
        panel_questions = {q:y for q,y in q_y.items() if numeric_bounds[panel] < next((t["x0"] for t in numeric_tokens if num(t["text"])==q and abs(t["top"]-y)<0.2 and min(range(4),key=lambda i:abs(t["x0"]-centers[i]))==0), header["x0"]) < numeric_bounds[panel+1]}
        if not panel_questions:
            continue
        for token in tokens:
            text = token["text"] or ""
            if not (x_low < token["x0"] < x_high):
                continue
            if not any(marker in text for marker in ("問正解", "部分点", "順", "なし")):
                continue
            question = min(panel_questions, key=lambda q: abs(panel_questions[q]-token["top"]))
            notes[question].append((token["top"], text))

    note_text = {q:" ".join(text for _,text in sorted(items)) for q,items in notes.items()}
    unordered = unordered_questions(page)
    return no_answers, q_points, note_text, unordered


def subject_for(group, q):
    for start,end,subject in SUBJECT_RANGES[group]:
        if start <= q <= end:
            return subject
    raise ValueError(f"{group}: q{q} outside subject ranges")


def score_bands(slot_count, max_points, note):
    bands = [{"minimumCorrect":slot_count,"points":max_points}]
    match = re.search(r"([0-9０-９]+)問正解で\s*部分点([0-9０-９]+)点", note or "")
    if match:
        threshold, points = num(match.group(1)), num(match.group(2))
        bands.append({"minimumCorrect":threshold,"points":points})
    elif note and "部分点１点" in note and "部分点なし" not in note:
        if slot_count != 2:
            raise ValueError(f"implicit one-point partial credit requires exactly 2 slots, got {slot_count}: {note}")
        bands.append({"minimumCorrect":1,"points":1})
    # explicit no-partial and no note both mean full-credit threshold only.
    unique = {(b["minimumCorrect"],b["points"]):b for b in bands}
    return sorted(unique.values(), key=lambda b:b["minimumCorrect"], reverse=True)


def build():
    tables = json.loads(TABLES.read_text(encoding="utf-8"))
    shapes = json.loads(SHAPES.read_text(encoding="utf-8"))
    result = {
        "schemaVersion":1,
        "qualification":"司法試験予備試験・短答式",
        "verifiedAt":"2026-08-13",
        "years":{},
    }
    errors = []
    for year in (2024,2025):
        legal_entries = []
        subject_counts = Counter()
        for group in LEGAL_GROUPS:
            key = f"{year}-{group}"
            table_doc = tables["documents"][key]
            page = table_doc["pages"][0]
            no_answers,q_points,notes,unordered = parse_answer_page(key,page)
            shape_doc = shapes["documents"][key]
            shape_by_q = {item["questionNumber"]:item for item in shape_doc["questions"]}
            expected_q = max(end for start,end,subject in SUBJECT_RANGES[group])
            if set(q_points) != set(range(1,expected_q+1)):
                errors.append(f"{key}: points coverage {sorted(set(range(1,expected_q+1))-set(q_points))}")
            for q in range(1,expected_q+1):
                shape = shape_by_q.get(q)
                if not shape or not shape.get("slots"):
                    errors.append(f"{key}: missing slots q{q}")
                    continue
                slots = shape["slots"]
                missing_answers = [slot for slot in slots if slot not in no_answers]
                if missing_answers:
                    errors.append(f"{key}: q{q} slots without answer {missing_answers}")
                    continue
                points = q_points.get(q)
                if points is None:
                    errors.append(f"{key}: missing points q{q}")
                    continue
                subject = subject_for(group,q)
                subject_counts[subject] += 1
                note = notes.get(q,"")
                entry = {
                    "id":f"{year}-{group}-Q{q:02d}",
                    "examYear":year,
                    "subject":subject,
                    "booklet":group,
                    "questionNumber":q,
                    "maxPoints":points,
                    "responseGroups":[{
                        "id":"official",
                        "slotIDs":[f"No.{slot}" for slot in slots],
                        "correctOptions":[no_answers[slot] for slot in slots],
                        "orderSensitive": q not in unordered,
                    }],
                    "scoreBands":score_bands(len(slots),points,note),
                    "sourceURL":ANSWER_PDFS[key],
                    "verifiedAt":"2026-08-13",
                    "officialNote":note or ("順不同" if q in unordered else ""),
                }
                legal_entries.append(entry)

        if subject_counts != Counter(EXPECTED_SUBJECT_COUNTS):
            errors.append(f"{year}: subject counts {dict(subject_counts)}")
        if len(legal_entries) != 95:
            errors.append(f"{year}: legal entries {len(legal_entries)} != 95")
        legal_points = sum(item["maxPoints"] for item in legal_entries)
        if legal_points != 210:
            errors.append(f"{year}: legal max points {legal_points} != 210")

        gkey = f"{year}-一般教養科目"
        ganswers, gpoints, _, _ = parse_answer_page(gkey,tables["documents"][gkey]["pages"][0])
        offered = GENERAL_OFFERED[year]
        expected = set(range(1,offered+1))
        if set(ganswers) != expected:
            errors.append(f"{gkey}: answer coverage missing={sorted(expected-set(ganswers))} extra={sorted(set(ganswers)-expected)}")
        if set(gpoints) != expected or any(value != 3 for value in gpoints.values()):
            errors.append(f"{gkey}: points must cover all {offered} questions at 3 points")

        result["years"][str(year)] = {
            "legal": {
                "questionCount":len(legal_entries),
                "maxPoints":legal_points,
                "questions":legal_entries,
            },
            "generalEducation": {
                "offered":offered,
                "select":20,
                "pointsPerSelectedQuestion":3,
                "maxPoints":60,
                "answerKey":{str(no):answer for no,answer in sorted(ganswers.items())},
                "sourceURL":ANSWER_PDFS[gkey],
            },
            "totalMaxPoints":270,
            "officialPassScore":PASS_SCORES[year],
        }

    if errors:
        for error in errors:
            print("FAIL",error)
        return None
    return result


def main():
    if not TABLES.exists() or not SHAPES.exists():
        print("BLOCKED: generated source summaries are missing")
        return 2
    result = build()
    if result is None:
        return 1
    OUT.write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding="utf-8")
    for year,year_data in result["years"].items():
        print(f"PASS {year}: legal={year_data['legal']['questionCount']} questions/{year_data['legal']['maxPoints']} points, general={year_data['generalEducation']['offered']} offered -> 20/60 points, total=270, pass={year_data['officialPassScore']}")
    print(f"WROTE {OUT} bytes={OUT.stat().st_size}")
    return 0

if __name__ == "__main__":
    sys.exit(main())
