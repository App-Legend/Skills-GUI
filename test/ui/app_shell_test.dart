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
  testWidgets('처음엔 내 스킬 목록, 탭은 세 개', (t) async {
    await _pump(t);
    expect(find.text('alpha'), findsOneWidget);
    expect(find.text('내 스킬'), findsWidgets);
    expect(find.text('1'), findsOneWidget);
    for (final gone in ['에이전트', '정리', '미사용 후보', '찾기·랭킹']) {
      expect(find.text(gone), findsNothing, reason: gone);
    }
  });

  testWidgets('준비 중 탭', (t) async {
    await _pump(t);
    for (final tab in ['업데이트 있음', '검색']) {
      await t.tap(find.text(tab));
      await t.pump();
      expect(find.text('아직 준비 중입니다'), findsOneWidget, reason: tab);
      expect(find.text('alpha'), findsNothing, reason: tab);
    }
  });

  testWidgets('탭 왕복', (t) async {
    await _pump(t);
    await t.tap(find.text('검색'));
    await t.pump();
    await t.tap(find.text('내 스킬'));
    await t.pump();
    expect(find.text('alpha'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('선택 상태', (t) async {
    await _pump(t);
    final h = t.ensureSemantics();
    expect(
      t.getSemantics(find.bySemanticsLabel('내 스킬\n1')),
      matchesSemantics(
        label: '내 스킬\n1',
        isButton: true,
        isSelected: true,
        hasSelectedState: true,
        hasTapAction: true,
        hasFocusAction: true,
        isFocusable: true,
      ),
    );
    expect(
      t.getSemantics(find.bySemanticsLabel('검색')),
      matchesSemantics(
        label: '검색',
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
