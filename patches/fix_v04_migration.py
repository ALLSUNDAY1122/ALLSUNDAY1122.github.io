from pathlib import Path
import sys

root = Path(sys.argv[1])

model_path = root / 'lib/models/relay_models.dart'
model_text = model_path.read_text(encoding='utf-8')
model_old = """      onboardingCompleted:
          (json['preferences'] as Map?)?.containsKey('onboardingCompleted') == true
          ? (json['preferences'] as Map?)?['onboardingCompleted'] == true
          : ((json['projects'] as List?)?.isNotEmpty ?? false),
"""
model_new = """      onboardingCompleted:
          (json['preferences'] as Map?)?.containsKey('onboardingCompleted') == true
          ? ((json['preferences'] as Map?)?['onboardingCompleted'] == true)
          : ((json['projects'] as List?)?.isNotEmpty ?? false),
"""
if model_old in model_text:
    model_path.write_text(model_text.replace(model_old, model_new, 1), encoding='utf-8')
    print('applied migration expression fix')
elif model_new in model_text:
    print('migration fix already applied')
else:
    raise SystemExit('expected migration block not found')

test_path = root / 'test/widget_test.dart'
test_text = test_path.read_text(encoding='utf-8')
test_old = """    expect(find.text('プライバシーポリシー'), findsOneWidget);
    expect(find.text('バージョン 0.4.0\\n端末内保存・オフライン設計'), findsOneWidget);
"""
test_new = """    expect(find.text('プライバシーポリシー'), findsOneWidget);
    final versionText = find.text('バージョン 0.4.0\\n端末内保存・オフライン設計');
    await tester.scrollUntilVisible(versionText, 300);
    expect(versionText, findsOneWidget);
"""
if test_old in test_text:
    test_path.write_text(test_text.replace(test_old, test_new, 1), encoding='utf-8')
    print('applied settings scroll test fix')
elif test_new in test_text:
    print('widget test fix already applied')
else:
    raise SystemExit('expected widget-test block not found')
