import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:skill_gui/features/ranking/terminal/command_runner.dart';
import 'package:skill_gui/features/update/skills_cli.dart';
import 'package:skill_gui/features/update/update_check.dart';

class _Fake implements RunningCommand {
  _Fake(this.code, this.out);
  final int code;
  final String out;
  @override
  Stream<String> get lines => Stream.fromIterable(out.split('\n'));
  @override
  Future<int> get exitCode async => code;
  @override
  void send(String line) {}
  @override
  Future<void> stop() async {}
}

class _Runner implements CommandRunner {
  _Runner(this.reply);
  final (int, String) Function(String command) reply;
  final commands = <String>[];
  @override
  String get shellName => 'zsh';
  @override
  Future<RunningCommand> start(String command) async {
    commands.add(command);
    final (code, out) = reply(command);
    return _Fake(code, out);
  }
}

// 실제 `npx skills check` 출력 모양 (색상 코드, \r 포함).
const _real =
    '\x1B[38;5;145mChecking for skill updates…\x1B[0m\n'
    '\r\x1B[K\x1B[38;5;145m↑ agent-browser has an update\x1B[0m\n'
    '\x1B[38;5;145m1 skill(s) can be updated; run \x1B[1mnpx skills update\x1B[0m\n';

/// 확인 결과 스트림을 한 결과로 모은다.
Future<({List<PluginUpdate> found, List<String> errors})> _all(
  Stream<({List<PluginUpdate> found, List<String> errors})> s,
) async {
  final parts = await s.toList();
  return (
    found: [for (final p in parts) ...p.found],
    errors: [for (final p in parts) ...p.errors],
  );
}

void main() {
  test('parseSkillsCheck: 색상 코드를 지우고 이름을 뽑는다', () {
    expect(parseSkillsCheck(_real), ['agent-browser']);
    expect(parseSkillsCheck('All skills are up to date'), isEmpty);
    // 업데이트가 있다는데 이름 줄이 없으면 형식이 바뀐 것.
    expect(parseSkillsCheck('2 skill(s) can be updated'), isNull);
    // 셸에 넣을 수 없는 이름은 버린다.
    expect(parseSkillsCheck('↑ a;rm has an update'), isEmpty);
  });

  test('shellQuote', () {
    expect(shellQuote("it's", windows: false), r"'it'\''s'");
    expect(shellQuote("it's", windows: true), "'it''s'");
  });

  group('SkillsCli', () {
    late Directory home;
    setUp(() async {
      home = await Directory.systemTemp.createTemp('skills_cli_test');
    });
    tearDown(() => home.delete(recursive: true));

    test('전역과 기록이 있는 프로젝트를 확인합니다', () async {
      final withLock = '${home.path}/p1';
      final noLock = '${home.path}/p2';
      await Directory(withLock).create();
      await Directory(noLock).create();
      await File('$withLock/skills-lock.json').writeAsString('{}');
      await File('${home.path}/.claude.json').writeAsString(
        jsonEncode({
          'projects': {withLock: {}, noLock: {}},
        }),
      );
      final runner = _Runner(
        (c) => c.contains('-p') ? (1, '↑ local-one has an update') : (1, _real),
      );
      final cli = SkillsCli(home: home.path, runner: runner, windows: false);

      final r = await _all(cli.check());

      expect(runner.commands, hasLength(2));
      expect(r.errors, isEmpty);
      expect(r.found.map((u) => (u.id, u.projectPath, u.kind)), unorderedEquals([
        ('agent-browser', null, UpdateKind.skill),
        ('local-one', withLock, UpdateKind.skill),
      ]));
    });

    test('npx가 없으면 실패를 숨기지 않고 남긴다', () async {
      final cli = SkillsCli(
        home: home.path,
        runner: _Runner((_) => (127, 'zsh: command not found: npx')),
        windows: false,
      );
      final r = await _all(cli.check());
      expect(r.found, isEmpty);
      expect(r.errors.single, contains('command not found'));
    });

    test('update: 프로젝트 스킬은 그 폴더에서 -p로 실행합니다', () async {
      final runner = _Runner((_) => (0, 'done'));
      final cli = SkillsCli(home: home.path, runner: runner, windows: false);
      final why = await cli.update(
        const PluginUpdate(
          id: 'x',
          scope: 'project',
          current: '',
          latest: null,
          skillCount: 1,
          state: UpdateState.needed,
          kind: UpdateKind.skill,
          projectPath: '/w/p',
        ),
      );
      expect(why, isNull);
      expect(runner.commands.single, "cd '/w/p' && npx skills update x -p -y");
    });
  });
}
