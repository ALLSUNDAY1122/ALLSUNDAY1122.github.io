#!/usr/bin/env python3
from pathlib import Path
import subprocess
import sys

root = Path(sys.argv[1])
path = root / 'test/widget_test.dart'
text = path.read_text(encoding='utf-8')
text = text.replace(
    "import 'package:aihandoverlog/services/state_store.dart';",
    "import 'package:aihandoverlog/services/state_store.dart';\nimport 'package:aihandoverlog/widgets/edit_dialogs.dart';",
    1,
)
text = text.replace(
    'バージョン 0.4.0\\n端末内保存・オフライン設計',
    'バージョン 0.5.0\\n端末内保存・オフライン設計',
)
addition = r'''

  testWidgets('onboarding fits a compact iPhone screen', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 568);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final controller = RelayController(store: MemoryStateStore());
    await controller.initialize();
    await tester.pumpWidget(AiHandoverLogApp(controller: controller));
    await tester.pumpAndSettle();

    expect(find.text('長期作業の現在地を残す'), findsOneWidget);
    expect(find.text('次へ'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('home navigation fits iPhone 16 with a long project name', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(393, 852);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final controller = RelayController(store: MemoryStateStore());
    await controller.initialize();
    await controller.loadDemo();
    final project = controller.activeProject!;
    await controller.updateProject(
      name: '複数生成AIを使った非常に長い自治体比較サイト制作プロジェクト',
      objective: project.objective,
      status: project.status,
      nextAction: project.nextAction,
    );

    await tester.pumpWidget(AiHandoverLogApp(controller: controller));
    await tester.pumpAndSettle();
    for (final label in ['現在地', 'タスク', 'ログ', '引継ぎ']) {
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('task editor remains usable with the iPhone keyboard shown', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(393, 852);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetViewInsets);

    final controller = RelayController(store: MemoryStateStore());
    await controller.initialize();
    await controller.loadDemo();
    await tester.pumpWidget(AiHandoverLogApp(controller: controller));
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 320);
    await tester.pump();

    final future = showTaskEditor(
      tester.element(find.byTooltip('設定・バックアップ')),
      project: controller.activeProject!,
    );
    await tester.pumpAndSettle();
    expect(find.text('タスクを追加'), findsOneWidget);
    expect(find.text('保存'), findsOneWidget);
    expect(find.text('キャンセル'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('キャンセル'));
    await tester.pumpAndSettle();
    expect(await future, isNull);
  });
'''
index = text.rfind('\n}')
if index < 0:
    raise SystemExit('widget test closing brace not found')
text = text[:index] + addition + text[index:]
path.write_text(text, encoding='utf-8')
subprocess.run(
    [sys.executable, 'patches/fix_v05_dialog_controller_disposal.py', str(root)],
    check=True,
)
print('added v0.5 mobile widget tests and dialog disposal fix')
