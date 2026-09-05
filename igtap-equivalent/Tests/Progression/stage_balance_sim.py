import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CATALOG = ROOT / "Content" / "Stages" / "stage_catalog_v1.json"


def main():
    data = json.loads(CATALOG.read_text(encoding="utf-8"))
    rows = []
    for stage in data["stages"]:
        first = float(stage["target_first_clear_seconds"])
        mastery = float(stage["target_mastery_seconds"])
        improvement = 1.0 - mastery / first
        segments_per_checkpoint = stage["challenge_segments"] / (len(stage["checkpoints"]) + 1)
        rows.append((stage["id"], first, mastery, improvement, segments_per_checkpoint))
    assert all(0.55 <= row[3] <= 0.75 for row in rows)
    assert all(1.5 <= row[4] <= 4.0 for row in rows)
    print("stage,first_clear,mastery,improvement,segments_per_checkpoint")
    for row in rows:
        print(f"{row[0]},{row[1]:.1f},{row[2]:.1f},{row[3]:.3f},{row[4]:.2f}")


if __name__ == "__main__":
    main()
