import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// 실행 중인 명령 하나.
abstract class RunningCommand {
  /// 표준 출력과 표준 오류를 줄 단위로 섞어서 내보낸다.
  Stream<String> get lines;

  /// 끝나면 종료 코드.
  Future<int> get exitCode;

  /// 표준 입력에 한 줄 보낸다 (y/n 질문에 답할 때).
  void send(String line);

  /// 명령과 그 아래 프로세스까지 멈춘다.
  Future<void> stop();
}

/// 명령을 셸에서 실행한다. 테스트에서는 가짜로 바꿔 끼운다.
abstract class CommandRunner {
  /// 화면에 보일 셸 이름 (PowerShell / zsh).
  String get shellName;

  Future<RunningCommand> start(String command);
}

/// 실제 셸 실행기. Windows 는 PowerShell, macOS·리눅스는 zsh(로그인 셸).
///
/// 대화형 화면은 지원하지 않는다. npx 가 설치 여부를 묻지 않도록 `npm_config_yes=true` 를 준다.
class ShellCommandRunner implements CommandRunner {
  const ShellCommandRunner();

  @override
  String get shellName => Platform.isWindows ? 'PowerShell' : 'zsh';

  @override
  Future<RunningCommand> start(String command) async {
    final environment = {'npm_config_yes': 'true', 'FORCE_COLOR': '0'};
    final Process process;
    if (Platform.isWindows) {
      // 출력이 한글로 깨지지 않게 UTF-8 로 맞춘 뒤 실행한다.
      process = await Process.start('powershell.exe', [
        '-NoProfile',
        '-NonInteractive',
        '-Command',
        '[Console]::OutputEncoding = [Text.Encoding]::UTF8; '
            '\$OutputEncoding = [Text.Encoding]::UTF8; '
            '$command',
      ], environment: environment);
    } else {
      // 앱으로 켜면 셸 설정의 PATH 가 없어서 로그인 셸(-l)로 npx·brew 를 찾게 한다.
      process = await Process.start('/bin/zsh', [
        '-lc',
        command,
      ], environment: environment);
    }
    return _ProcessCommand(process);
  }
}

class _ProcessCommand implements RunningCommand {
  _ProcessCommand(this._process) {
    final decoder = const Utf8Decoder(allowMalformed: true);
    var open = 2;
    void done() {
      if (--open == 0) _lines.close();
    }

    for (final stream in [_process.stdout, _process.stderr]) {
      stream
          .transform(decoder)
          .transform(const LineSplitter())
          .listen(_lines.add, onDone: done, onError: (_) => done());
    }
  }

  final Process _process;
  final _lines = StreamController<String>();

  @override
  Stream<String> get lines => _lines.stream;

  @override
  Future<int> get exitCode => _process.exitCode;

  @override
  void send(String line) {
    try {
      _process.stdin.writeln(line);
    } on Object {
      // 이미 끝난 프로세스면 무시한다.
    }
  }

  @override
  Future<void> stop() async {
    if (Platform.isWindows) {
      // PowerShell 만 끄면 그 아래 node 가 남는다. 프로세스 트리째 끈다.
      await Process.run('taskkill', ['/T', '/F', '/PID', '${_process.pid}']);
    } else {
      _process.kill(ProcessSignal.sigterm);
    }
  }
}
