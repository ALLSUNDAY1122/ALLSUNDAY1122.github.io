#!/usr/bin/env python3
import re
from pathlib import Path

root=Path(__file__).resolve().parents[1]/'Sources'
changed=[]
numeric_pattern=re.compile(r'(?<![A-Za-z0-9_])\.(\d+)')
legacy_mock_pattern=re.compile(
    r'\nstruct MockView: View \{.*?\n\}\n\nstruct HistoryView: View \{',
    re.S,
)
for p in root.glob('*.swift'):
    s=p.read_text(encoding='utf-8')
    fixed=numeric_pattern.sub(r'0.\1',s)
    if p.name=='MainViews.swift' and (root/'MockViews.swift').exists():
        replacement='\nstruct LegacyMockView: View { var body: some View { EmptyView() } }\n\nstruct HistoryView: View {'
        fixed,n=legacy_mock_pattern.subn(replacement,fixed,count=1)
        if n!=1 and 'struct LegacyMockView: View' not in fixed:
            raise SystemExit('failed to replace legacy MockView')
    if p.name=='QuizViews.swift' and '.accessibilityLabel("閉じる")' not in fixed:
        old='                .foregroundStyle(KSTheme.ink)\n                VStack(alignment: .leading, spacing: 2) {'
        new='                .foregroundStyle(KSTheme.ink)\n                .accessibilityLabel("閉じる")\n                VStack(alignment: .leading, spacing: 2) {'
        if old not in fixed:
            raise SystemExit('quiz close-button marker missing')
        fixed=fixed.replace(old,new,1)
    if fixed!=s:
        p.write_text(fixed,encoding='utf-8')
        changed.append(p.name)
print({'normalized':changed})
