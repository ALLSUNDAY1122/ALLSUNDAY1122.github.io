import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aihandoverlog/app.dart';
import 'package:aihandoverlog/controllers/relay_controller.dart';
import 'package:aihandoverlog/models/relay_models.dart';
import 'package:aihandoverlog/services/state_store.dart';

Future<void> _loadJapaneseFonts() async {
  final appFont = FontLoader('AppStoreNoto')
    ..addFont(rootBundle.load('assets/NotoSansJP.ttf'));
  final monospaceFont = FontLoader('monospace')
    ..addFont(rootBundle.load('assets/NotoSansJP.ttf'));
  await Future.wait([appFont.load(), monospaceFont.load()]);
}

Future<RelayController> _controller() async {
  final controller = RelayController(store: MemoryStateStore());
  await controller.initialize();
  await controller.loadDemo();
  await controller.setShowSafetyNotice(false);
  await controller.setTheme('light');

  final project = controller.activeProject!;
  final chatGpt = project.aiMembers.firstWhere((item) => item.name == 'ChatGPT');
  final codex = project.aiMembers.firstWhere((item) => item.name == 'Codex');
  final claude = project.aiMembers.firstWhere((item) => item.name == 'Claude');

  await controller.addTask(
    title: '公式サイトの更新日を再確認',
    ownerAiId: chatGpt.id,
    status: TaskStatus.todo,
    priority: Priority.high,
    notes: '公開前に一次資料とJSONの更新日を一致させる。',
  );
  await controller.addTask(
    title: 'PRのCI失敗を修正',
    ownerAiId: codex.id,
    status: TaskStatus.doing,
    priority: Priority.high,
    notes: '自治体JSONの必須項目と出典URLを検証する。',
  );
  await controller.addTask(
    title: '説明文の表現を監査',
    ownerAiId: claude.id,
    status: TaskStatus.todo,
    priority: Priority.medium,
    notes: '断定表現を避け、公式情報と整合させる。',
  );
  await controller.addSession(
    aiId: codex.id,
    summary: '自治体JSONと検証スクリプトを更新した。',
    decisions: '未確認項目は推測で埋めず、保留理由を残す。',
    output: 'PRとCIログを保存。',
    nextAction: '公式資料の更新日を照合し、次の自治体へ進む。',
  );
  await controller.addSession(
    aiId: claude.id,
    summary: '制度説明と出典の対応関係を監査した。',
    decisions: '自治体独自制度と国制度を分けて表示する。',
    output: '修正候補を3件抽出。',
    nextAction: '統括AIが修正内容を確定する。',
  );
  await controller.addInstruction(
    title: '公開前監査指示',
    version: 'v3.1',
    content: '一次資料、更新日、対象年度、適用条件を確認し、根拠のない補完を行わない。',
  );
  await controller.addRisk(
    title: '複数AI間で指示版がずれる',
    severity: Priority.medium,
    mitigation: '現行指示を1件だけ指定し、引継ぎ文に版番号を含める。',
  );
  await controller.addDeliverable(
    name: '公開前チェックリスト',
    location: 'GitHub / docs/release-checklist.md',
    notes: '出典・更新日・CI・表示確認を記録。',
  );
  return controller;
}

void main() {
  testWidgets('generate five App Store screenshots', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(430, 932);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await _loadJapaneseFonts();
    final controller = await _controller();
    await tester.pumpWidget(AiHandoverLogApp(controller: controller));
    await tester.pumpAndSettle();

    Future<void> capture(String name) async {
      await expectLater(
        find.byType(Scaffold).first,
        matchesGoldenFile('goldens/$name.png'),
      );
    }

    await capture('01_overview_raw');

    final overviewList = find.byType(ListView).first;
    await tester.drag(overviewList, const Offset(0, -1150));
    await tester.pumpAndSettle();
    await capture('02_ai_risk_raw');

    await tester.tap(find.text('タスク'));
    await tester.pumpAndSettle();
    await capture('03_tasks_raw');

    await tester.tap(find.text('ログ'));
    await tester.pumpAndSettle();
    await capture('04_logs_raw');

    await tester.tap(find.text('引継ぎ'));
    await tester.pumpAndSettle();
    await capture('05_handoff_raw');
  });
}
