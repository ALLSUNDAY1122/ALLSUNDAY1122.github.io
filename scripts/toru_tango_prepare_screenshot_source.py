#!/usr/bin/env python3
from __future__ import annotations
import sys
from pathlib import Path

root = Path(sys.argv[1] if len(sys.argv) > 1 else "toru-tango-mobile")

# Metro's Release bundler does not resolve the TS @ alias for the root JSON import.
hits = list(root.rglob("src/constants/appInfo.ts"))
if len(hits) != 1:
    raise SystemExit(f"expected one src/constants/appInfo.ts, found {len(hits)}: {hits}")
app_info = hits[0]
text = app_info.read_text(encoding="utf-8")
text = text.replace("@/app.json", "../../app.json")
app_info.write_text(text, encoding="utf-8")
if "@/app.json" in app_info.read_text(encoding="utf-8"):
    raise SystemExit("Metro JSON alias patch failed")

# Add screenshot-only fixture data. This changes only the temporary CI checkout used
# to produce App Store screenshots; the already-uploaded Apple Build 12 is untouched.
storage = root / "src/repositories/storage.ts"
text = storage.read_text(encoding="utf-8")
marker = "  return {\n    cards,\n    history,\n    decks: normalizeDecks([...storedDecks, ...decksFromCards]),\n    studyDays: normalizeStudyDays([...storedStudyDays, ...legacyStudyDays])\n  };"
if marker not in text:
    raise SystemExit("storage fixture marker not found")
fixture = """  if (!cards.length && process.env.EXPO_PUBLIC_SCREENSHOT_FIXTURES === '1') {
    const now = '2026-09-23T00:00:00.000Z';
    const fixtureCards: Card[] = [
      { id:'m1', question:'abandon', answer:'捨てる・断念する', deckName:'メイン', correct:5, wrong:1, lastStudiedAt:now, createdAt:now, updatedAt:now },
      { id:'m2', question:'accurate', answer:'正確な', deckName:'メイン', correct:4, wrong:0, lastStudiedAt:now, createdAt:now, updatedAt:now },
      { id:'k1', question:'いとをかし', answer:'とても趣がある', deckName:'古文', correct:3, wrong:1, lastStudiedAt:now, createdAt:now, updatedAt:now },
      { id:'e1', question:'implement', answer:'実行する・実装する', deckName:'英語', correct:2, wrong:1, lastStudiedAt:now, createdAt:now, updatedAt:now },
      { id:'h1', question:'大政奉還が行われた年は？', answer:'1867年', deckName:'世界史', correct:2, wrong:1, lastStudiedAt:now, createdAt:now, updatedAt:now },
      { id:'g1', question:'日本で最も面積が大きい都道府県は？', answer:'北海道', deckName:'地理', correct:4, wrong:0, lastStudiedAt:now, createdAt:now, updatedAt:now }
    ];
    const fixtureHistory: StudyHistory[] = [
      { id:'r1', cardId:'m1', answeredAt:now, dateKey:'2026-09-23', correct:true },
      { id:'r2', cardId:'k1', answeredAt:now, dateKey:'2026-09-23', correct:false }
    ];
    return { cards: fixtureCards, history: fixtureHistory, decks: ['古文','メイン','英語','漢文','世界史','地理'], studyDays: ['2026-09-23'] };
  }
"""
storage.write_text(text.replace(marker, fixture + marker), encoding="utf-8")
print(f"prepared screenshot source under {root}")
