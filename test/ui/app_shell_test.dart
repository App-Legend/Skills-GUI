import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skill_gui/features/scan/skill.dart';
import 'package:skill_gui/ui/app_shell.dart';
import 'package:skill_gui/ui/skill_detail_page.dart';

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
    for (final gone in ['에이전트', '정리', '미사용 후보', '찾기·랭킹', '검색']) {
      expect(find.text(gone), findsNothing, reason: gone);
    }
  });

  testWidgets('준비 중 탭', (t) async {
    await _pump(t);
    for (final tab in ['업데이트 필요', '랭킹']) {
      await t.tap(find.text(tab));
      await t.pump();
      expect(find.text('아직 준비 중입니다'), findsOneWidget, reason: tab);
      expect(find.text('alpha'), findsNothing, reason: tab);
    }
  });

  testWidgets('탭 왕복', (t) async {
    await _pump(t);
    await t.tap(find.text('랭킹'));
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
      t.getSemantics(find.bySemanticsLabel('랭킹')),
      matchesSemantics(
        label: '랭킹',
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

  testWidgets('탭을 옮겼다 와도 필터가 남습니다', (t) async {
    await _pump(t);
    await t.tap(find.text('Codex'));
    await t.pump();
    expect(find.text('alpha'), findsNothing);
    await t.tap(find.text('랭킹'));
    await t.pump();
    await t.tap(find.text('내 스킬').first);
    await t.pump();
    expect(find.text('alpha'), findsNothing); // Codex 필터 유지
  });

  testWidgets('업데이트 탭에 넘겨준 화면', (t) async {
    t.view.physicalSize = const Size(1280, 820);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        home: AppShell(
          result: const ScanResult(skills: [_skill]),
          onRescan: () async {},
            updates: const Text('업데이트 화면'),
        ),
      ),
    );
    expect(find.text('업데이트 화면', skipOffstage: false), findsNothing); // 열기 전엔 만들지 않는다
    await t.tap(find.text('업데이트 필요'));
    await t.pump();
    expect(find.text('업데이트 화면'), findsOneWidget);
  });

  testWidgets('스킬을 누르면 사이드바는 두고 오른쪽에 상세', (t) async {
    await _pump(t);
    await t.tap(find.text('alpha'));
    await t.pumpAndSettle();
    expect(find.byType(SkillDetailPage), findsOneWidget); // 상세
    expect(find.text('업데이트 필요'), findsOneWidget); // 사이드바 그대로
    final h = t.ensureSemantics();
    expect(find.bySemanticsLabel('업데이트 필요'), findsOneWidget); // 화면 낭독에도 남는다
    h.dispose();
    await t.tap(find.byIcon(Icons.chevron_left));
    await t.pumpAndSettle();
    expect(find.byType(SkillDetailPage), findsNothing);
    expect(find.text('alpha'), findsOneWidget);
  });

  testWidgets('상세에서 내 스킬 탭을 누르면 목록으로', (t) async {
    await _pump(t);
    await t.tap(find.text('alpha'));
    await t.pumpAndSettle();
    await t.tap(find.text('내 스킬').first);
    await t.pumpAndSettle();
    expect(find.byType(SkillDetailPage), findsNothing);
    expect(find.text('alpha'), findsOneWidget);
  });

  testWidgets('상세에서 다른 탭에 갔다가 내 스킬로 오면 목록', (t) async {
    await _pump(t);
    await t.tap(find.text('alpha'));
    await t.pumpAndSettle();
    expect(find.byType(SkillDetailPage), findsOneWidget);
    await t.tap(find.text('랭킹'));
    await t.pumpAndSettle();
    await t.tap(find.text('내 스킬').first);
    await t.pumpAndSettle();
    expect(find.byType(SkillDetailPage), findsNothing);
    expect(find.text('alpha'), findsOneWidget);
  });

  testWidgets('업데이트 필요 탭에 개수, 0이면 숨김', (t) async {
    t.view.physicalSize = const Size(1280, 820);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    Widget shell(int n) => MaterialApp(
      home: AppShell(
        result: const ScanResult(skills: [_skill]),
        onRescan: () async {},
        updateCount: n,
      ),
    );
    await t.pumpWidget(shell(2));
    expect(find.text('2'), findsOneWidget);
    await t.pumpWidget(shell(0));
    expect(find.text('0'), findsNothing);
  });
}
