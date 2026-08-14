#!/usr/bin/env python3
import re
from pathlib import Path

root=Path(__file__).resolve().parents[1]/'Sources'
changed=[]
pattern=re.compile(r'(?<![A-Za-z0-9_])\.(\d+)')
for p in root.glob('*.swift'):
    s=p.read_text(encoding='utf-8')
    fixed=pattern.sub(r'0.\1',s)
    if fixed!=s:
        p.write_text(fixed,encoding='utf-8')
        changed.append(p.name)
print({'normalized':changed})
