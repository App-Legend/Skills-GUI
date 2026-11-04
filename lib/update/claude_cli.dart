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

class ProcessClaudeCli implements ClaudeCli {
  String? _path;

  /// 더블클릭으로 연 앱은 터미널 PATH를 모르므로 macOS는 로그인 셸에 묻는다.
  Future<String?> _find() async {
    if (_path != null) return _path;
    try {
      final r = Platform.isWindows
          ? await Process.run('where', ['claude'], runInShell: true)
          : await Process.run('/bin/zsh', ['-lc', 'command -v claude']);
      final line = '${r.stdout}'.trim().split('\n').first.trim();
      if (r.exitCode == 0 && line.isNotEmpty) _path = line;
    } on ProcessException {
      // 셸이 없으면 못 찾은 것으로 본다
    }
    return _path;
  }

  @override
  Future<CmdResult?> run(List<String> args) async {
    final path = await _find();
    if (path == null) return null;
    try {
      final r = await Process.run(path, args, runInShell: Platform.isWindows);
      return CmdResult(r.exitCode, '${r.stdout}', '${r.stderr}');
    } on ProcessException catch (e) {
      return CmdResult(-1, '', e.message);
    }
  }
}
