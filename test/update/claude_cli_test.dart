import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:skill_gui/update/claude_cli.dart';

void main() {
  test('where 결과에서 실행 가능한 줄을 고른다', () {
    expect(
      pickWherePath('C:\\npm\\claude\r\nC:\\npm\\claude.cmd\r\n'),
      'C:\\npm\\claude.cmd',
    );
    expect(pickWherePath('C:\\a\\claude.exe\n'), 'C:\\a\\claude.exe');
    expect(pickWherePath('C:\\npm\\claude\n'), 'C:\\npm\\claude');
    expect(pickWherePath(''), isNull);
  });

  test('셸에서 못 찾으면 알려진 설치 위치를 본다', () {
    final found = knownClaudePath('/Users/u', (p) => p == '/Users/u/.local/bin/claude');
    expect(found, '/Users/u/.local/bin/claude');
    expect(knownClaudePath('/Users/u', (_) => false), isNull);
  });

  test('멈춘 명령은 시간 초과로 끝낸다', () async {
    final cli = ProcessClaudeCli(
      path: '/bin/sleep',
      timeout: const Duration(milliseconds: 200),
    );
    final r = await cli.run(['5']);
    expect(r!.exitCode, -1);
    expect(r.stderr, '시간 초과');
  }, skip: Platform.isWindows);
}
