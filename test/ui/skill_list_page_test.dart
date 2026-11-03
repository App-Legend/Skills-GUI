import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skill_gui/scan/skill.dart';
import 'package:skill_gui/ui/glass.dart';
import 'package:skill_gui/ui/skill_list_page.dart';

const _skills = [
  Skill(name: 'a', description: 'da', source: SkillSource.global, path: '/a'),
  Skill(
      name: 'b',
      description: 'db',
      source: SkillSource.plugin,
      plugin: 'p@m',
      pluginEnabled: true,
      projectPath: '/w/app',
      path: '/b'),
  Skill(
      name: 'c',
      source: SkillSource.global,
      path: '/c',
      problem: SkillProblem(ProblemKind.noPermission, '읽을 수 없음, 폴더 권한 필요')),
  Skill(
      name: 'd',
      description: 'dd',
      source: SkillSource.plugin,
      plugin: 'q@m',
      pluginEnabled: false,
      path: '/d'),
  Skill(name: 'e', source: SkillSource.synced, path: '/e'),
];

Future<void> _pump(WidgetTester t,
    {List<String> notices = const [],
    Future<void> Function()? onRescan,
    bool reduce = false}) async {
  t.view.physicalSize = const Size(1280, 820);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  Widget page = MaterialApp(
    home: SkillListPage(
      result: ScanResult(skills: _skills, notices: notices),
      onRescan: onRescan ?? () async {},
      onOpen: (_) {},
    ),
  );
  if (reduce) page = ReduceTransparency(value: true, child: page);
  await t.pumpWidget(page);
}

void main() {
  testWidgets('카드, 사이드바, 태그', (t) async {
    await _pump(t);
    for (final n in ['a', 'b', 'c', 'd', 'e']) {
      expect(find.text(n), findsOneWidget);
    }
    expect(find.text('Claude Code'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
    expect(find.text('/w/app'), findsOneWidget);
    expect(find.text('읽을 수 없음, 폴더 권한 필요'), findsOneWidget);
    expect(find.text('전역'), findsNWidgets(3)); // 필터 + 카드 a, c
    expect(find.text('p@m'), findsOneWidget);
    expect(find.text('동기화'), findsOneWidget);
  });

  testWidgets('필터', (t) async {
    await _pump(t);
    await t.tap(find.widgetWithText(InkWell, '플러그인'));
    await t.pump();
    expect(find.text('b'), findsOneWidget);
    expect(find.text('d'), findsOneWidget);
    expect(find.text('a'), findsNothing);
    await t.tap(find.text('꺼짐').first);
    await t.pump();
    expect(find.text('b'), findsNothing);
    expect(find.text('d'), findsOneWidget);
    expect(find.text('꺼짐'), findsNWidgets(2)); // 필터 + 배지
  });

  testWidgets('다시 스캔과 notices', (t) async {
    var n = 0;
    await _pump(t, notices: ['안내 문구'], onRescan: () async => n++);
    expect(find.text('안내 문구'), findsOneWidget);
    await t.tap(find.text('다시 스캔'));
    expect(n, 1);
  });

  testWidgets('투명도 줄이기', (t) async {
    await _pump(t);
    expect(find.byType(BackdropFilter), findsWidgets);
    await _pump(t, reduce: true);
    expect(find.byType(BackdropFilter), findsNothing);
  });
}
