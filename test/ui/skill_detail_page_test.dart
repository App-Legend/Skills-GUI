import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skill_gui/scan/skill.dart';
import 'package:skill_gui/ui/skill_detail_page.dart';

Future<void> _pump(WidgetTester t, Skill s,
    {Future<void> Function(String)? onGrant}) async {
  t.view.physicalSize = const Size(1200, 900);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(MaterialApp(
    home: SkillDetailPage(skill: s, onGrantFolder: onGrant),
  ));
}

void main() {
  const full = Skill(
    name: 'alpha',
    description: '알파 설명',
    source: SkillSource.global,
    path: '/home/.claude/skills/alpha',
    skillMd: '# 원문 본문',
    files: ['SKILL.md', 'a.txt'],
  );

  testWidgets('기본 정보 표시', (t) async {
    await _pump(t, full);
    for (final x in [
      'alpha', '전역', '경로', '/home/.claude/skills/alpha', '알파 설명',
      'SKILL.md 원문', '# 원문 본문', '포함된 파일', 'a.txt',
    ]) {
      expect(find.text(x), findsWidgets, reason: x);
    }
    expect(find.text('폴더 추가 허락'), findsNothing);
  });

  const denied = Skill(
    name: 'c',
    source: SkillSource.global,
    path: '/home/.claude/skills/c',
    linkTarget: '/x/y/c',
    problem: SkillProblem(ProblemKind.noPermission, '읽을 수 없음, 폴더 권한 필요'),
  );

  testWidgets('허락 버튼은 상위 폴더로 호출, 원문 대신 문제 메시지', (t) async {
    String? got;
    await _pump(t, denied, onGrant: (p) async => got = p);
    expect(find.text('읽을 수 없음, 폴더 권한 필요'), findsOneWidget);
    expect(find.text('SKILL.md 원문'), findsNothing);
    await t.tap(find.text('폴더 추가 허락'));
    expect(got, '/x/y');
  });

  testWidgets('onGrantFolder 없으면 버튼 없음', (t) async {
    await _pump(t, denied);
    expect(find.text('폴더 추가 허락'), findsNothing);
  });

  testWidgets('꺼진 프로젝트 플러그인 스킬', (t) async {
    await _pump(
      t,
      const Skill(
        name: 'd',
        source: SkillSource.plugin,
        plugin: 'p@m',
        pluginEnabled: false,
        projectPath: '/w/app',
        path: '/d',
        skillMd: 'x',
      ),
    );
    expect(find.text('꺼짐'), findsOneWidget);
    expect(find.text('/w/app'), findsOneWidget);
  });

  testWidgets('뒤로 가기', (t) async {
    await t.pumpWidget(MaterialApp(
      home: Builder(
        builder: (c) => TextButton(
          onPressed: () => Navigator.push(
              c, MaterialPageRoute(builder: (_) => SkillDetailPage(skill: full))),
          child: const Text('go'),
        ),
      ),
    ));
    await t.tap(find.text('go'));
    await t.pumpAndSettle();
    await t.tap(find.text('Claude Code 스킬'));
    await t.pumpAndSettle();
    expect(find.text('go'), findsOneWidget);
  });

  testWidgets('onGrantFolder가 던지면 안내 문구', (t) async {
    await _pump(t, denied, onGrant: (_) async => throw Exception('x'));
    await t.tap(find.text('폴더 추가 허락'));
    await t.pump();
    expect(find.text('폴더를 허락하지 못했습니다'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('실행 중에는 버튼 비활성', (t) async {
    final c = Completer<void>();
    var n = 0;
    await _pump(t, denied, onGrant: (_) {
      n++;
      return c.future;
    });
    await t.tap(find.text('폴더 추가 허락'));
    await t.pump();
    expect(t.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);
    await t.tap(find.text('폴더 추가 허락'), warnIfMissed: false);
    expect(n, 1);
    c.complete();
    await t.pump();
    expect(t.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNotNull);
  });
}
