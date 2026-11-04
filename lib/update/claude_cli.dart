import 'dart:async';
import 'dart:convert';
import 'dart:io';

class CmdResult {
  final int exitCode;
  final String stdout;
  final String stderr;

  const CmdResult(this.exitCode, this.stdout, this.stderr);
}

/// `claude` 명령 실행. 명령을 찾지 못하면 null.
abstract class ClaudeCli {
  Future<CmdResult?> run(List<String> args);
}

/// `where claude` 결과에서 실행할 줄을 고른다. npm은 확장자 없는 파일을 먼저 내놓아서 `.exe`·`.cmd`를 앞세운다.
String? pickWherePath(String out) {
  final lines = out.split(RegExp(r'\r?\n')).map((l) => l.trim()).where((l) => l.isNotEmpty);
  final exe = lines.where((l) => RegExp(r'\.(exe|cmd)$', caseSensitive: false).hasMatch(l));
  return exe.firstOrNull ?? lines.firstOrNull;
}

/// 로그인 셸 PATH에 없을 때(.zshrc에만 PATH를 둔 경우 등) 알려진 설치 위치를 본다.
String? knownClaudePath(String home, bool Function(String) exists) => [
  '$home/.local/bin/claude',
  '$home/.claude/local/claude',
  '/opt/homebrew/bin/claude',
  '/usr/local/bin/claude',
].where(exists).firstOrNull;

class ProcessClaudeCli implements ClaudeCli {
  String? _path;
  final Duration timeout;

  ProcessClaudeCli({this._path, this.timeout = const Duration(minutes: 3)});

  Future<String?> _find() async {
    if (_path != null) return _path;
    try {
      if (Platform.isWindows) {
        final r = await Process.run('where', ['claude'], runInShell: true);
        if (r.exitCode == 0) _path = pickWherePath('${r.stdout}');
      } else {
        // 더블클릭으로 연 앱은 터미널 PATH를 모르므로 로그인 셸에 묻는다.
        final r = await Process.run('/bin/zsh', ['-lc', 'command -v claude']);
        final line = '${r.stdout}'.trim().split('\n').first.trim();
        if (r.exitCode == 0 && line.isNotEmpty) _path = line;
      }
    } on ProcessException {
      // 셸이 없으면 아래 알려진 위치로
    }
    final home = Platform.environment['HOME'];
    if (_path == null && home != null && !Platform.isWindows) {
      _path = knownClaudePath(home, (p) => File(p).existsSync());
    }
    return _path;
  }

  @override
  Future<CmdResult?> run(List<String> args) async {
    final path = await _find();
    if (path == null) return null;
    try {
      final p = await Process.start(path, args, runInShell: Platform.isWindows);
      // 입력을 기다리며 멈추지 않도록 바로 닫는다.
      await p.stdin.close();
      final out = p.stdout.transform(utf8.decoder).join();
      final err = p.stderr.transform(utf8.decoder).join();
      try {
        final code = await p.exitCode.timeout(timeout);
        return CmdResult(code, await out, await err);
      } on TimeoutException {
        p.kill();
        return const CmdResult(-1, '', '시간 초과');
      }
    } on ProcessException catch (e) {
      return CmdResult(-1, '', e.message);
    }
  }
}
