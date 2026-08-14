#!/usr/bin/env python3
from pathlib import Path

PATH = Path(__file__).resolve().parent / "Sources" / "RigakuRootViewV2.swift"
ANCHOR = '                    Section("この教材について") {'
INSERTION = '''                    RigakuPurchaseSettingsSection()\n                    RigakuLegalSettingsSection()\n\n                    Section("この教材について") {'''

text = PATH.read_text(encoding="utf-8")
if "RigakuLegalSettingsSection()" in text and "RigakuPurchaseSettingsSection()" in text:
    print("release settings sections already wired")
elif ANCHOR not in text:
    raise SystemExit("settings insertion anchor not found")
else:
    PATH.write_text(text.replace(ANCHOR, INSERTION, 1), encoding="utf-8")
    print("wired StoreKit and legal settings sections")
