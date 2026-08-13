#!/usr/bin/env python3
from pathlib import Path
import re
import sys

pbx = Path(sys.argv[1] if len(sys.argv) > 1 else "HokenshiSprint.xcodeproj/project.pbxproj")
text = pbx.read_text(encoding="utf-8")
proper = re.compile(r"com\.apple\.InAppPurchase\s*=\s*\{\s*enabled\s*=\s*1;\s*\};", re.S)
if proper.search(text):
    print("PASS: IAP capability present")
    raise SystemExit(0)

malformed = re.compile(
    r'(?m)^(?P<i>[ \t]*)SystemCapabilities\s*=\s*"[^"\n]*com\.apple\.InAppPurchase[^"\n]*";\s*$'
)
match = malformed.search(text)
if match:
    indent = match.group("i")
    replacement = (
        f"{indent}SystemCapabilities = {{\n"
        f"{indent}\tcom.apple.InAppPurchase = {{\n"
        f"{indent}\t\tenabled = 1;\n"
        f"{indent}\t}};\n"
        f"{indent}}};"
    )
    text = text[: match.start()] + replacement + text[match.end() :]
else:
    match = re.search(r"(?m)^(?P<i>[ \t]*)ProvisioningStyle\s*=\s*Automatic;\s*$", text)
    if not match:
        raise SystemExit("ERROR: target ProvisioningStyle not found")
    indent = match.group("i")
    insertion = (
        f"\n{indent}SystemCapabilities = {{\n"
        f"{indent}\tcom.apple.InAppPurchase = {{\n"
        f"{indent}\t\tenabled = 1;\n"
        f"{indent}\t}};\n"
        f"{indent}}};"
    )
    text = text[: match.end()] + insertion + text[match.end() :]

if not proper.search(text):
    raise SystemExit("ERROR: failed to add IAP capability")
pbx.write_text(text, encoding="utf-8")
print("PASS: normalized In-App Purchase capability")
