import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skill_gui/main.dart';
import 'package:skill_gui/scan/skill.dart';

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

  testWidgets('홈 폴더를 모르면 다시 스캔 버튼이 보인다', (tester) async {
    await tester.pumpWidget(
      SkillGuiApp(claudeDir: null, scan: _scan, reduceTransparency: _noReduce),
    );
    await tester.pumpAndSettle();
    expect(find.text('스캔하지 못했습니다'), findsOneWidget);
  });

  testWidgets('스캔이 던지면 다시 스캔 버튼이 보인다', (tester) async {
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
}
