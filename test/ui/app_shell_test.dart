import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skill_gui/scan/skill.dart';
import 'package:skill_gui/ui/app_shell.dart';

const _skill = Skill(name: 'alpha', source: SkillSource.global, path: '/a');

Future<void> _pump(WidgetTester t, {Size size = const Size(1280, 820)}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    MaterialApp(
      home: AppShell(
        result: const ScanResult(skills: [_skill]),
        onRescan: () async {},
        onOpen: (_) {},
      ),
    ),
  );
}

void main() {
  testWidgets('처음엔 Claude Code 목록', (t) async {
    await _pump(t);
    expect(find.text('alpha'), findsOneWidget);
    expect(find.text('Claude Code'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('에이전트'), findsOneWidget);
    expect(find.text('정리'), findsOneWidget);
  });

  testWidgets('준비 중 탭', (t) async {
    await _pump(t);
    for (final tab in ['Codex', '업데이트 있음', '미사용 후보', '찾기·랭킹']) {
      await t.tap(find.text(tab));
      await t.pump();
      expect(find.text('아직 준비 중입니다'), findsOneWidget, reason: tab);
      expect(find.text('alpha'), findsNothing, reason: tab);
    }
  });

  testWidgets('탭 왕복', (t) async {
    await _pump(t);
    await t.tap(find.text('Codex'));
    await t.pump();
    await t.tap(find.text('Claude Code'));
    await t.pump();
    expect(find.text('alpha'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('선택 상태', (t) async {
    await _pump(t);
    final h = t.ensureSemantics();
    expect(
      t.getSemantics(find.bySemanticsLabel('Claude Code\n1')),
      matchesSemantics(
        label: 'Claude Code\n1',
        isButton: true,
        isSelected: true,
        hasSelectedState: true,
        hasTapAction: true,
        hasFocusAction: true,
        isFocusable: true,
      ),
    );
    expect(
      t.getSemantics(find.bySemanticsLabel('Codex')),
      matchesSemantics(
        label: 'Codex',
        isButton: true,
        isSelected: false,
        hasSelectedState: true,
        hasTapAction: true,
        hasFocusAction: true,
        isFocusable: true,
      ),
    );
    h.dispose();
  });

  testWidgets('좁은 창', (t) async {
    await _pump(t, size: const Size(900, 600));
    expect(t.takeException(), isNull);
  });
}
