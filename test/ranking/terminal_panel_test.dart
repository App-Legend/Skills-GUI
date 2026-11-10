import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skill_gui/features/ranking/terminal/command_runner.dart';
import 'package:skill_gui/features/ranking/terminal/terminal_panel.dart';

/// 출력과 종료를 테스트가 직접 정하는 가짜 명령.
class FakeCommand implements RunningCommand {
  final controller = StreamController<String>();
  final exit = Completer<int>();
  final sent = <String>[];
  bool stopped = false;

  @override
  Stream<String> get lines => controller.stream;

  @override
  Future<int> get exitCode => exit.future;

  @override
  void send(String line) => sent.add(line);

  @override
  Future<void> stop() async {
    stopped = true;
    finish(1);
  }

  void finish(int code) {
    if (!controller.isClosed) controller.close();
    if (!exit.isCompleted) exit.complete(code);
  }
}

class FakeRunner implements CommandRunner {
  final started = <String>[];
  final commands = <FakeCommand>[];

  @override
  String get shellName => '가짜셸';

  @override
  Future<RunningCommand> start(String command) async {
    started.add(command);
    final c = FakeCommand();
    commands.add(c);
    return c;
  }
}

Future<GlobalKey<TerminalPanelState>> _pump(
  WidgetTester tester,
  FakeRunner runner, {
  void Function(String, int)? onFinished,
}) async {
  final key = GlobalKey<TerminalPanelState>();
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: TerminalPanel(key: key, runner: runner, onFinished: onFinished),
      ),
    ),
  );
  return key;
}

void main() {
  testWidgets('run 하면 명령·출력·완료 줄을 보이고 onFinished 를 부른다', (tester) async {
    final runner = FakeRunner();
    final finished = <(String, int)>[];
    final key = await _pump(
      tester,
      runner,
      onFinished: (c, code) => finished.add((c, code)),
    );

    key.currentState!.run('echo 안녕');
    await tester.pump();
    expect(runner.started, ['echo 안녕']);
    expect(find.text('> echo 안녕'), findsOneWidget);
    expect(find.byKey(const Key('terminal-stop')), findsOneWidget);

    runner.commands.single.controller.add('안녕');
    await tester.pump();
    expect(find.text('안녕'), findsOneWidget);

    runner.commands.single.finish(0);
    await tester.pumpAndSettle();
    expect(find.text('완료했습니다 (종료 코드 0)'), findsOneWidget);
    expect(find.byKey(const Key('terminal-stop')), findsNothing);
    expect(finished, [('echo 안녕', 0)]);
  });

  testWidgets('실패하면 종료 코드를 보입니다', (tester) async {
    final runner = FakeRunner();
    final key = await _pump(tester, runner);
    key.currentState!.run('bad');
    await tester.pump();
    runner.commands.single.finish(2);
    await tester.pumpAndSettle();
    expect(find.text('실패했습니다 (종료 코드 2)'), findsOneWidget);
  });

  testWidgets('입력 줄: 쉬고 있으면 명령 실행, 실행 중이면 표준 입력으로', (tester) async {
    final runner = FakeRunner();
    await _pump(tester, runner);

    await tester.enterText(find.byKey(const Key('terminal-input')), 'npm -v');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(runner.started, ['npm -v']);

    await tester.enterText(find.byKey(const Key('terminal-input')), 'y');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(runner.started, hasLength(1));
    expect(runner.commands.single.sent, ['y']);

    runner.commands.single.finish(0);
    await tester.pumpAndSettle();
  });

  testWidgets('실행 중에는 새 명령을 받지 않고, 중지 버튼으로 멈춘다', (tester) async {
    final runner = FakeRunner();
    final key = await _pump(tester, runner);
    key.currentState!.run('long');
    await tester.pump();
    expect(await key.currentState!.run('other'), isFalse);
    expect(runner.started, ['long']);

    await tester.tap(find.byKey(const Key('terminal-stop')));
    await tester.pumpAndSettle();
    expect(runner.commands.single.stopped, isTrue);
    expect(find.text('실패했습니다 (종료 코드 1)'), findsOneWidget);
  });

  test('실제 셸에서 명령을 실행하고 한글 출력을 읽는다', () async {
    const runner = ShellCommandRunner();
    final command = await runner.start(
      Platform.isWindows ? "Write-Output '안녕 skill'" : "echo '안녕 skill'",
    );
    final lines = await command.lines.toList();
    expect(await command.exitCode, 0);
    expect(lines, contains('안녕 skill'));
  });
}
