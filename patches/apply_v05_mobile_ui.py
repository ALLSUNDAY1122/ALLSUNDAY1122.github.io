#!/usr/bin/env python3
from pathlib import Path
import re
import sys

root = Path(sys.argv[1])


def update(rel: str, transform) -> None:
    path = root / rel
    text = path.read_text(encoding='utf-8')
    changed = transform(text)
    if changed == text:
        raise SystemExit(f'no v0.5 changes applied to {rel}')
    path.write_text(changed, encoding='utf-8')


def app(text: str) -> str:
    text = text.replace('seedColor: const Color(0xFF4255D4),', 'seedColor: const Color(0xFF3157D5),')
    anchor = '      scaffoldBackgroundColor: scheme.surface,\n'
    addition = '''      scaffoldBackgroundColor: scheme.surface,\n      appBarTheme: AppBarTheme(\n        centerTitle: false,\n        backgroundColor: scheme.surface,\n        surfaceTintColor: Colors.transparent,\n      ),\n      navigationBarTheme: NavigationBarThemeData(\n        indicatorColor: scheme.primaryContainer,\n        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,\n      ),\n      dialogTheme: DialogThemeData(\n        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),\n        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),\n      ),\n'''
    return text.replace(anchor, addition, 1)


def home(text: str) -> str:
    text = text.replace(
        "title: Text(project?.name ?? 'AI引継ぎ帳'),",
        "title: Text(\n          project?.name ?? 'AI引継ぎ帳',\n          maxLines: 1,\n          overflow: TextOverflow.ellipsis,\n        ),",
        1,
    )
    text = text.replace(
        '''              Icon(\n                Icons.account_tree_outlined,\n                size: 72,\n                color: Theme.of(context).colorScheme.primary,\n              ),''',
        '              const _BrandMark(size: 88),',
        1,
    )
    widget = '''class _BrandMark extends StatelessWidget {\n  const _BrandMark({required this.size});\n\n  final double size;\n\n  @override\n  Widget build(BuildContext context) {\n    final scheme = Theme.of(context).colorScheme;\n    return Semantics(\n      label: 'AI引継ぎ帳',\n      image: true,\n      child: Container(\n        width: size,\n        height: size,\n        decoration: BoxDecoration(\n          gradient: const LinearGradient(\n            begin: Alignment.topLeft,\n            end: Alignment.bottomRight,\n            colors: [Color(0xFF112B46), Color(0xFF3157D5)],\n          ),\n          borderRadius: BorderRadius.circular(size * 0.24),\n          boxShadow: [\n            BoxShadow(\n              color: scheme.shadow.withAlpha(46),\n              blurRadius: 18,\n              offset: const Offset(0, 8),\n            ),\n          ],\n        ),\n        child: Stack(\n          alignment: Alignment.center,\n          children: [\n            Container(\n              width: size * 0.48,\n              height: size * 0.60,\n              decoration: BoxDecoration(\n                color: Colors.white,\n                borderRadius: BorderRadius.circular(size * 0.07),\n              ),\n            ),\n            Positioned(\n              left: size * 0.24,\n              bottom: size * 0.25,\n              child: Icon(\n                Icons.arrow_outward_rounded,\n                size: size * 0.52,\n                color: const Color(0xFF22D3C5),\n              ),\n            ),\n          ],\n        ),\n      ),\n    );\n  }\n}\n\n'''
    return text.replace('class _SectionHeader extends StatelessWidget {', widget + 'class _SectionHeader extends StatelessWidget {', 1)


def onboarding(text: str) -> str:
    start = text.index('                  return Padding(')
    end = text.index('                },\n              ),', start)
    replacement = '''                  return LayoutBuilder(\n                    builder: (context, constraints) => SingleChildScrollView(\n                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),\n                      child: ConstrainedBox(\n                        constraints: BoxConstraints(\n                          minHeight: constraints.maxHeight - 36,\n                        ),\n                        child: Column(\n                          mainAxisAlignment: MainAxisAlignment.center,\n                          children: [\n                            Container(\n                              width: 112,\n                              height: 112,\n                              decoration: BoxDecoration(\n                                gradient: const LinearGradient(\n                                  begin: Alignment.topLeft,\n                                  end: Alignment.bottomRight,\n                                  colors: [Color(0xFF112B46), Color(0xFF3157D5)],\n                                ),\n                                borderRadius: BorderRadius.circular(28),\n                              ),\n                              child: Icon(\n                                item.icon,\n                                size: 56,\n                                color: const Color(0xFF8FF7EC),\n                              ),\n                            ),\n                            const SizedBox(height: 28),\n                            Text(\n                              item.title,\n                              textAlign: TextAlign.center,\n                              style: Theme.of(context).textTheme.headlineSmall,\n                            ),\n                            const SizedBox(height: 14),\n                            ConstrainedBox(\n                              constraints: const BoxConstraints(maxWidth: 520),\n                              child: Text(\n                                item.body,\n                                textAlign: TextAlign.center,\n                                style: Theme.of(context).textTheme.bodyLarge,\n                              ),\n                            ),\n                          ],\n                        ),\n                      ),\n                    ),\n                  );\n'''
    return text[:start] + replacement + text[end:]


def settings(text: str) -> str:
    text = text.replace(
        '      body: ListView(\n        padding: const EdgeInsets.only(bottom: 32),',
        '      body: SafeArea(\n        top: false,\n        child: ListView(\n          padding: const EdgeInsets.only(bottom: 32),',
        1,
    )
    text = text.replace(
        '        ],\n      ),\n    );\n  }\n}\n\nclass PrivacyPolicyScreen',
        '          ],\n        ),\n      ),\n    );\n  }\n}\n\nclass PrivacyPolicyScreen',
        1,
    )
    text = text.replace(
        '      body: ListView(\n        padding: const EdgeInsets.all(20),',
        '      body: SafeArea(\n        top: false,\n        child: ListView(\n          padding: const EdgeInsets.all(20),',
        1,
    )
    text = text.replace(
        '        ],\n      ),\n    );\n  }\n}\n\nclass _PolicySection',
        '          ],\n        ),\n      ),\n    );\n  }\n}\n\nclass _PolicySection',
        1,
    )
    return text.replace('バージョン 0.4.0\\n端末内保存・オフライン設計', 'バージョン 0.5.0\\n端末内保存・オフライン設計')


def dialogs(text: str) -> str:
    return re.sub(
        r'(\bAlertDialog\(\n)(\s+)(title:)',
        r'\1\2insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),\n\2\3',
        text,
    )


update('lib/app.dart', app)
update('lib/screens/home_screen.dart', home)
update('lib/screens/onboarding_screen.dart', onboarding)
update('lib/screens/settings_screen.dart', settings)
update('lib/widgets/edit_dialogs.dart', dialogs)
update('pubspec.yaml', lambda t: t.replace('version: 0.4.0+4', 'version: 0.5.0+5'))
update('CHANGELOG.md', lambda t: '''## 0.5.0\n\n- iPhone向けSafe Areaと小画面レイアウトを調整。\n- キーボード表示時に編集ダイアログを操作しやすく改善。\n- 正式ブランドカラー、アプリアイコン、起動画面を追加。\n- iPhone 16相当、小画面、キーボード表示のWidgetテストを追加。\n\n''' + t)
print('applied v0.5 mobile UI polish')
