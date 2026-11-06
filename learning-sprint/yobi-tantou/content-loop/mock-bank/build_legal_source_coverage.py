#!/usr/bin/env python3
import json
from collections import Counter, defaultdict
from pathlib import Path

HERE = Path(__file__).resolve().parent
CONTENT = HERE.parent
NATIVE = CONTENT.parent / "ios" / "Resources" / "questions.release.json"
OUT = HERE / "legal-source-coverage.generated.json"


def load(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def main() -> int:
    records = []
    for item in load(NATIVE):
        records.append({
            "id": item.get("id"),
            "subject": item.get("subject"),
            "topic": item.get("topic"),
            "sourceTitle": item.get("sourceTitle"),
            "sourceURL": item.get("sourceURL"),
            "practiceMockId": {"foundation":"practice-mock-1","standard":"practice-mock-2","applied":"practice-mock-3"}.get(item.get("difficulty")),
            "bank": "native-seed",
        })
    for path in sorted(HERE.glob("*.release.json")):
        for item in load(path):
            records.append({
                "id": item.get("id"),
                "subject": item.get("subject"),
                "topic": item.get("topic"),
                "sourceTitle": item.get("source_title"),
                "sourceURL": item.get("source_url"),
                "practiceMockId": item.get("practice_mock_id"),
                "bank": path.name,
            })

    ids = [r["id"] for r in records]
    if any(not qid for qid in ids) or len(ids) != len(set(ids)):
        raise SystemExit("FAIL: formal banks contain missing or duplicate IDs")

    by_subject = defaultdict(list)
    source_counts = Counter()
    topic_counts = Counter()
    for record in records:
        by_subject[record["subject"]].append(record)
        if record["sourceTitle"]:
            source_counts[(record["subject"], record["sourceTitle"])] += 1
        if record["topic"]:
            topic_counts[(record["subject"], record["topic"])] += 1

    report = {
        "schemaVersion": 1,
        "formalQuestionCount": len(records),
        "bySubject": {
            subject: {
                "count": len(items),
                "sourceTitles": sorted({r["sourceTitle"] for r in items if r["sourceTitle"]}),
                "topics": sorted({r["topic"] for r in items if r["topic"]}),
            }
            for subject, items in sorted(by_subject.items())
        },
        "reusedSourceTitles": [
            {"subject": subject, "sourceTitle": title, "count": count}
            for (subject, title), count in sorted(source_counts.items())
            if count > 1
        ],
        "reusedTopics": [
            {"subject": subject, "topic": topic, "count": count}
            for (subject, topic), count in sorted(topic_counts.items())
            if count > 1
        ],
    }
    OUT.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"PASS: legal source coverage inventory built for {len(records)} formal questions")
    print(f"reused source titles={len(report['reusedSourceTitles'])}, reused topics={len(report['reusedTopics'])}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
