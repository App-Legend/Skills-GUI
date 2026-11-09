import 'dart:async';

import 'package:flutter/material.dart';

import 'command_runner.dart';

const _bg = Color(0xFF111827);
const _text = Color(0xFFE5E7EB);
const _dim = Color(0xFF9CA3AF);
const _ok = Color(0xFF6CE9A6);
const _bad = Color(0xFFFDA29B);
const _mono = TextStyle(
  fontFamily: 'Consolas',
  fontFamilyFallback: ['Menlo', 'monospace'],
  fontSize: 13,
  height: 1.5,
  color: _text,
);

/// 출력 줄 수 상한. 넘으면 오래된 줄부터 버린다.
const int _maxLines = 2000;

/// 줄 하나와 그 종류.
enum _Kind { output, command, ok, error }

/// 명령을 실행하고 출력을 보여 주는 간단한 터미널 패널.
///
/// 진짜 터미널이 아니라서 색·화살표 메뉴 같은 대화형 화면은 그대로 나오지 않는다.
/// 실행 중에 입력 줄에 쓰면 그 명령의 표준 입력으로 보낸다 (y/n 답하기).
class TerminalPanel extends StatefulWidget {
  const TerminalPanel({super.key, required this.runner, this.onFinished});

  final CommandRunner runner;

  /// 명령이 끝나면 (명령, 종료 코드) 로 부른다.
  final void Function(String command, int exitCode)? onFinished;

  @override
  State<TerminalPanel> createState() => TerminalPanelState();
}

class TerminalPanelState extends State<TerminalPanel> {
  final List<(_Kind, String)> _lines = [];
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final FocusNode _inputFocus = FocusNode();

  RunningCommand? _running;
  StreamSubscription<String>? _sub;

  bool get running => _running != null;

  @override
  void dispose() {
    _sub?.cancel();
    _running?.stop();
    _input.dispose();
    _scroll.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  void _add(_Kind kind, String text) {
    setState(() {
      _lines.add((kind, text));
      if (_lines.length > _maxLines) {
        _lines.removeRange(0, _lines.length - _maxLines);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  /// [command] 를 실행한다. 이미 실행 중이면 무시하고 false.
  Future<bool> run(String command) async {
    if (_running != null || command.trim().isEmpty) return false;
    _add(_Kind.command, command);
    final RunningCommand proc;
    try {
      proc = await widget.runner.start(command);
    } on Object catch (e) {
      _add(_Kind.error, '실행하지 못했습니다: $e');
      return false;
    }
    if (!mounted) {
      await proc.stop();
      return false;
    }
    setState(() => _running = proc);
    final drained = Completer<void>();
    _sub = proc.lines.listen(
      (line) => _add(_Kind.output, line),
      onDone: drained.complete,
    );
    final code = await proc.exitCode;
    // 프로세스가 끝난 뒤 남은 출력까지 받는다. 자식 프로세스가 출력을 붙잡고 있으면 잠깐만 기다린다.
    await drained.future.timeout(const Duration(seconds: 2), onTimeout: () {});
    unawaited(_sub?.cancel());
    _sub = null;
    if (!mounted) return true;
    setState(() => _running = null);
    _add(
      code == 0 ? _Kind.ok : _Kind.error,
      code == 0 ? '완료했습니다 (종료 코드 0)' : '실패했습니다 (종료 코드 $code)',
    );
    widget.onFinished?.call(command, code);
    return true;
  }

  Future<void> _stop() async {
    final proc = _running;
    if (proc == null) return;
    _add(_Kind.error, '중지합니다');
    await proc.stop();
  }

  void _submit(String text) {
    final proc = _running;
    if (proc != null) {
      _add(_Kind.output, '> $text');
      proc.send(text);
    } else {
      run(text);
    }
    _input.clear();
    _inputFocus.requestFocus();
  }

  Color _color(_Kind kind) => switch (kind) {
    _Kind.output => _text,
    _Kind.command => _dim,
    _Kind.ok => _ok,
    _Kind.error => _bad,
  };

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('terminal-panel'),
    decoration: BoxDecoration(
      color: _bg,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
          child: Row(
            children: [
              Text(
                '터미널 · ${widget.runner.shellName}',
                style: _mono.copyWith(color: _dim, fontSize: 12),
              ),
              const SizedBox(width: 10),
              if (running)
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 2, color: _dim),
                ),
              const Spacer(),
              if (running)
                TextButton(
                  key: const Key('terminal-stop'),
                  onPressed: _stop,
                  child: const Text('중지', style: TextStyle(color: _bad)),
                ),
              TextButton(
                key: const Key('terminal-clear'),
                onPressed: running ? null : () => setState(_lines.clear),
                child: const Text('지우기', style: TextStyle(color: _dim)),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 240,
          child: _lines.isEmpty
              ? Center(
                  child: Text(
                    '위 명령의 실행 버튼을 누르거나, 아래에 명령을 입력하세요.',
                    style: _mono.copyWith(color: _dim),
                  ),
                )
              : ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _lines.length,
                  itemBuilder: (context, i) {
                    final (kind, text) = _lines[i];
                    return SelectableText(
                      kind == _Kind.command ? '> $text' : text,
                      style: _mono.copyWith(color: _color(kind)),
                    );
                  },
                ),
        ),
        const Divider(height: 1, color: Color(0xFF374151)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Text(running ? '입력' : '>', style: _mono.copyWith(color: _dim)),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  key: const Key('terminal-input'),
                  controller: _input,
                  focusNode: _inputFocus,
                  onSubmitted: _submit,
                  style: _mono,
                  cursorColor: _text,
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    hintText: running
                        ? '실행 중인 명령에 보낼 답 (예: y)'
                        : '명령 입력 후 Enter',
                    hintStyle: _mono.copyWith(color: const Color(0xFF6B7280)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
