#!/usr/bin/env python3
from __future__ import annotations

import json
from collections import Counter, defaultdict
from pathlib import Path

from validate_exam_structure import load_classification_records

ROOT = Path(__file__).resolve().parent
SUBJECTS = [
    "解剖学",
    "生理学",
    "運動学",
    "病理学概論",
    "臨床心理学",
    "リハビリテーション医学",
    "臨床医学大要",
    "理学療法",
]


def main() -> None:
    records, errors = load_classification_records()
    if errors:
        raise SystemExit("\n".join(errors))

    by_round: dict[int, Counter] = defaultdict(Counter)
    by_round_category: dict[int, Counter] = defaultdict(Counter)
    overall = Counter()
    rights = Counter()
    media = Counter()
    dispositions = Counter()

    for record in records:
        round_no = int(record["round"])
        subject = record["subject"]
        by_round[round_no][subject] += 1
        by_round_category[round_no]["practical" if int(record["questionNumber"]) <= 20 else "general"] += 1
        overall[subject] += 1
        rights[record["rightsStatus"]] += 1
        media[record["mediaStatus"]] += 1
        dispositions[record["productDisposition"]] += 1

    result = {
        "qualification": "理学療法士国家試験",
        "generatedFrom": "classification.json + classification-batches/*.json",
        "total": len(records),
        "rounds": {
            str(round_no): {
                "total": sum(by_round[round_no].values()),
                "category": dict(sorted(by_round_category[round_no].items())),
                "subjects": {subject: by_round[round_no][subject] for subject in SUBJECTS},
            }
            for round_no in sorted(by_round, reverse=True)
        },
        "overallSubjects": {subject: overall[subject] for subject in SUBJECTS},
        "rights": dict(sorted(rights.items())),
        "media": dict(sorted(media.items())),
        "productDisposition": dict(sorted(dispositions.items())),
    }
    print(json.dumps(result, ensure_ascii=False, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()
