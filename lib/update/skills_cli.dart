import 'dart:async';
import 'dart:io';

import '../features/ranking/terminal/command_runner.dart';
import '../scan/skill_scanner.dart';
import 'update_check.dart';

final _ansi = RegExp(r'\x1B\[[0-9;?]*[A-Za-z]');
final _hasUpdate = RegExp(r'↑\s+(\S+)\s+has an update');
final _safeName = RegExp(r'^[\w.:-]+$');

/// `npx skills check` 출력에서 업데이트가 있는 스킬 이름을 뽑는다.
/// 업데이트가 있다고 했는데 이름을 못 찾으면 출력 형식이 바뀐 것이라 null.
List<String>? parseSkillsCheck(String output) {
  final text = output.replaceAll(_ansi, '');
  final names = [
    for (final m in _hasUpdate.allMatches(text))
      if (_safeName.hasMatch(m[1]!)) m[1]!,
  ];
  if (names.isEmpty && text.contains('can be updated')) return null;
  return names;
}

/// 셸에 넣을 경로. zsh는 '…', PowerShell은 '…'에서 '를 ''로.
String shellQuote(String s, {required bool windows}) => windows
    ? "'${s.replaceAll("'", "''")}'"
    : "'${s.replaceAll("'", r"'\''")}'";

/// skills CLI(`npx skills`)로 설치한 스킬의 업데이트 확인과 업데이트.
/// 설치 기록은 전역 `~/.agents/.skill-lock.json`, 프로젝트 `<프로젝트>/skills-lock.json`에 있다.
class SkillsCli implements SkillUpdateSource {
  SkillsCli({
    required this.home,
    this.runner = const ShellCommandRunner(),
    this.timeout = const Duration(minutes: 3),
    bool? windows,
  }) : windows = windows ?? Platform.isWindows;

  final String home;
  final CommandRunner runner;
  final Duration timeout;
  final bool windows;

  @override
  UpdateKind get kind => UpdateKind.skill;

  String get _npx => windows ? 'npx.cmd' : 'npx';

  String _inDir(String dir, String command) => windows
      ? 'Set-Location -LiteralPath ${shellQuote(dir, windows: true)} -ErrorAction Stop; $command'
      : 'cd ${shellQuote(dir, windows: false)} && $command';

  /// 명령을 실행해 (종료 코드, 출력)을 돌려준다. 시간이 넘으면 멈추고 -1.
  Future<(int, String)> _run(String command) async {
    try {
      final p = await runner.start(command);
      final out = StringBuffer();
      final lines = p.lines.listen(out.writeln);
      try {
        final code = await p.exitCode.timeout(timeout);
        await lines.asFuture<void>().timeout(
          const Duration(seconds: 2),
          onTimeout: () {},
        );
        return (code, out.toString());
      } on TimeoutException {
        await p.stop();
        return (-1, '시간 초과');
      } finally {
        await lines.cancel();
      }
    } on Object catch (e) {
      return (-1, '$e');
    }
  }

  static String _lastLine(String out) {
    final lines = out
        .replaceAll(_ansi, '')
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty);
    return lines.isEmpty ? '출력 없음' : lines.last;
  }

  /// 전역과 기록이 있는 프로젝트를 모두 확인한다. 실패한 곳은 [errors]에 남긴다.
  @override
  Future<({List<PluginUpdate> found, List<String> errors})> check() async {
    final projects = [
      for (final p in await knownProjects(home))
        if (File('$p${Platform.pathSeparator}skills-lock.json').existsSync()) p,
    ];
    final results = await Future.wait([
      _checkOne(null),
      for (final p in projects) _checkOne(p),
    ]);
    return (
      found: [for (final r in results) ...r.$1],
      errors: [for (final r in results) ?r.$2],
    );
  }

  Future<(List<PluginUpdate>, String?)> _checkOne(String? project) async {
    final where = project ?? '전역 스킬';
    final (code, out) = await _run(
      _inDir(
        project ?? home,
        '$_npx skills check ${project == null ? '-g' : '-p'}',
      ),
    );
    // 업데이트가 있으면 1로 끝난다.
    if (code != 0 && code != 1) {
      return (<PluginUpdate>[], '$where: 확인하지 못했습니다 (${_lastLine(out)})');
    }
    final names = parseSkillsCheck(out);
    if (names == null) {
      return (<PluginUpdate>[], '$where: 결과를 읽지 못했습니다 (${_lastLine(out)})');
    }
    return (
      [
        for (final n in names)
          PluginUpdate(
            id: n,
            scope: project == null ? 'user' : 'project',
            current: '',
            latest: null,
            skillCount: 1,
            state: UpdateState.needed,
            kind: UpdateKind.skill,
            projectPath: project,
          ),
      ],
      null,
    );
  }

  /// 스킬 하나를 업데이트한다. 성공하면 null, 실패하면 이유.
  @override
  Future<String?> update(PluginUpdate u) async {
    if (!_safeName.hasMatch(u.id)) return '스킬 이름에 쓸 수 없는 글자가 있습니다';
    final project = u.projectPath;
    final (code, out) = await _run(
      _inDir(
        project ?? home,
        '$_npx skills update ${u.id} ${project == null ? '-g' : '-p'} -y',
      ),
    );
    return code == 0 ? null : '업데이트하지 못했습니다: ${_lastLine(out)}';
  }
}
