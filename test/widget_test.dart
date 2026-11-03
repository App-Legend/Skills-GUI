import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:skill_gui/access/folder_access.dart';
import 'package:skill_gui/main.dart';
import 'package:skill_gui/scan/skill.dart';

class _FakeAccess implements FolderAccess {
  final Directory? dir;
  _FakeAccess(this.dir);
  @override
  Future<Directory?> restore() async => dir;
  @override
  Future<Directory?> pickClaudeDir() async => dir;
  @override
  Future<bool> grantFolder(String suggestedPath) async => true;
  @override
  Future<bool> reduceTransparency() async => false;
}

const _skill = Skill(
  name: 'hello-skill',
  description: '인사',
  source: SkillSource.global,
  path: '/x/hello-skill',
);

Future<ScanResult> _scan(Directory d) async =>
    const ScanResult(skills: [_skill]);

void main() {
  testWidgets('복원되면 스캔해서 목록을 보여준다', (tester) async {
    await tester.pumpWidget(
      SkillGuiApp(
        access: _FakeAccess(Directory.systemTemp),
        scan: _scan,
        showGrant: false,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('hello-skill'), findsOneWidget);
  });

  testWidgets('권한이 없으면 폴더 고르기 버튼이 보인다', (tester) async {
    await tester.pumpWidget(
      SkillGuiApp(access: _FakeAccess(null), scan: _scan, showGrant: false),
    );
    await tester.pumpAndSettle();
    expect(find.text('폴더 고르기'), findsOneWidget);
  });

  testWidgets('스캔이 던지면 다시 스캔 버튼이 보인다', (tester) async {
    await tester.pumpWidget(
      SkillGuiApp(
        access: _FakeAccess(Directory.systemTemp),
        scan: (_) async => throw Exception('x'),
        showGrant: false,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('스캔하지 못했습니다'), findsOneWidget);
    expect(find.text('다시 스캔'), findsOneWidget);
  });
}
