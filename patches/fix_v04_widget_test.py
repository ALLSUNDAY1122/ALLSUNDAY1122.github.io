from pathlib import Path
import sys

root = Path(sys.argv[1])
path = root / 'test/widget_test.dart'
text = path.read_text(encoding='utf-8')
old = """    expect(find.text('プライバシーポリシー'), findsOneWidget);
    expect(find.text('バージョン 0.4.0\\n端末内保存・オフライン設計'), findsOneWidget);
"""
new = """    expect(find.text('プライバシーポリシー'), findsOneWidget);
    final versionText = find.text('バージョン 0.4.0\\n端末内保存・オフライン設計');
    await tester.scrollUntilVisible(versionText, 300);
    expect(versionText, findsOneWidget);
"""
if old not in text:
    if new in text:
        print('widget test fix already applied')
        raise SystemExit(0)
    raise SystemExit('expected widget-test block not found')
path.write_text(text.replace(old, new, 1), encoding='utf-8')
print('applied settings scroll test fix')
