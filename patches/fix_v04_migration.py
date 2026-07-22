from pathlib import Path
import sys

root = Path(sys.argv[1])
path = root / 'lib/models/relay_models.dart'
text = path.read_text(encoding='utf-8')
old = """      onboardingCompleted:
          (json['preferences'] as Map?)?.containsKey('onboardingCompleted') == true
          ? (json['preferences'] as Map?)?['onboardingCompleted'] == true
          : ((json['projects'] as List?)?.isNotEmpty ?? false),
"""
new = """      onboardingCompleted:
          (json['preferences'] as Map?)?.containsKey('onboardingCompleted') == true
          ? ((json['preferences'] as Map?)?['onboardingCompleted'] == true)
          : ((json['projects'] as List?)?.isNotEmpty ?? false),
"""
if old not in text:
    if new in text:
        print('migration fix already applied')
        raise SystemExit(0)
    raise SystemExit('expected migration block not found')
path.write_text(text.replace(old, new, 1), encoding='utf-8')
print('applied migration expression fix')
