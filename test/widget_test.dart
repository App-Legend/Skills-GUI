import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skill_gui/main.dart';
import 'package:skill_gui/features/scan/skill.dart';
import 'package:skill_gui/features/update/update_check.dart';

const _skill = Skill(
  name: 'hello-skill',
  description: '인사',
  source: SkillSource.global,
  path: '/x/hello-skill',
);

Future<ScanResult> _scan(Directory d) async =>
    const ScanResult(skills: [_skill]);

Future<bool> _noReduce() async => false;

void main() {
  testWidgets('켜자마자 스캔해서 목록을 보여준다', (tester) async {
    await tester.pumpWidget(
      SkillGuiApp(
        claudeDir: Directory.systemTemp,
        scan: _scan,
        reduceTransparency: _noReduce,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('hello-skill'), findsOneWidget);
  });

  testWidgets('홈 폴더를 모르면 다시 스캔 버튼이 보입니다', (tester) async {
    await tester.pumpWidget(
      SkillGuiApp(claudeDir: null, scan: _scan, reduceTransparency: _noReduce),
    );
    await tester.pumpAndSettle();
    expect(find.text('스캔하지 못했습니다'), findsOneWidget);
  });

  testWidgets('스캔이 던지면 다시 스캔 버튼이 보입니다', (tester) async {
    await tester.pumpWidget(
      SkillGuiApp(
        claudeDir: Directory.systemTemp,
        scan: (_) async => throw Exception('x'),
        reduceTransparency: _noReduce,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('스캔하지 못했습니다'), findsOneWidget);
    expect(find.text('다시 스캔'), findsOneWidget);
  });

  testWidgets('다시 스캔하면 새 결과를 보여준다', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var n = 0;
    Future<ScanResult> scan(Directory d) async => ScanResult(
      skills: [
        Skill(
          name: 'skill-${n++}',
          source: SkillSource.global,
          path: '/x/s',
        ),
      ],
    );
    await tester.pumpWidget(
      SkillGuiApp(
        claudeDir: Directory.systemTemp,
        scan: scan,
        reduceTransparency: _noReduce,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('skill-0'), findsOneWidget);
    await tester.tap(find.text('다시 스캔'));
    await tester.pumpAndSettle();
    expect(find.text('skill-1'), findsOneWidget);
  });

  testWidgets('다시 스캔해도 고른 필터가 남습니다', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    // 실제 스캔처럼 시간이 걸려야 로딩 화면이 끼어든다.
    Future<ScanResult> slow(Directory d) =>
        Future.delayed(const Duration(milliseconds: 50), () => _scan(d));
    await tester.pumpWidget(
      SkillGuiApp(
        claudeDir: Directory.systemTemp,
        scan: slow,
        reduceTransparency: _noReduce,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Codex'));
    await tester.pump();
    await tester.tap(find.text('다시 스캔'));
    await tester.pump(const Duration(milliseconds: 10));
    expect(find.text('Codex'), findsOneWidget); // 화면을 갈아엎지 않는다
    expect(find.byType(CircularProgressIndicator), findsOneWidget); // 다시 스캔 버튼의 링
    await tester.pumpAndSettle();
    expect(find.text('hello-skill'), findsNothing); // Codex 필터 유지
    await tester.tap(find.text('Claude Code'));
    await tester.pump();
    expect(find.text('hello-skill'), findsOneWidget);
  });

  testWidgets('켤 때 업데이트 필요 개수를 보여준다', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    PluginUpdate up(String id) => PluginUpdate(
      id: id,
      scope: 'user',
      current: '1',
      latest: '2',
      skillCount: 0,
      state: UpdateState.needed,
    );
    await tester.pumpWidget(
      SkillGuiApp(
        claudeDir: Directory.systemTemp,
        scan: _scan,
        reduceTransparency: _noReduce,
        findUpdates: (_) async => [up('a@m'), up('b@m')],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('2'), findsOneWidget);
  });
}
