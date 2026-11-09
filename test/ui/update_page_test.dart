import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skill_gui/ui/glass.dart';
import 'package:skill_gui/ui/update_page.dart';
import 'package:skill_gui/update/claude_cli.dart';
import 'package:skill_gui/update/update_check.dart';

class _FakeCli implements ClaudeCli {
  final calls = <List<String>>[];
  final bool missing;
  CmdResult Function(List<String>) answer;
  Completer<void>? gate;

  _FakeCli({this.missing = false, CmdResult Function(List<String>)? answer})
    : answer = answer ?? ((_) => const CmdResult(0, '', ''));

  @override
  Future<CmdResult?> run(List<String> args) async {
    calls.add(args);
    await gate?.future;
    return missing ? null : answer(args);
  }
}

const _needed = PluginUpdate(
  id: 'p@m',
  scope: 'user',
  current: '1.0',
  latest: '1.1',
  skillCount: 3,
  state: UpdateState.needed,
);
const _unknown = PluginUpdate(
  id: 'q@n',
  scope: 'user',
  current: '2.0',
  latest: null,
  skillCount: 0,
  state: UpdateState.unknown,
);

Future<void> _pump(
  WidgetTester t,
  _FakeCli cli, {
  List<PluginUpdate> found = const [_needed],
  Future<void> Function()? onUpdated,
  void Function(List<PluginUpdate>)? onChecked,
}) async {
  t.view.physicalSize = const Size(1280, 820);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: UpdatePage(
          claudeDir: Directory.systemTemp,
          cli: cli,
          check: (_) async => found,
          onUpdated: onUpdated ?? () async {},
          onChecked: onChecked ?? (_) {},
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('확인하면 마켓을 새로 받고 목록을 보여준다', (t) async {
    final cli = _FakeCli();
    await _pump(t, cli);
    expect(find.text('p@m'), findsNothing);
    await t.tap(find.text('업데이트 확인'));
    await t.pumpAndSettle();
    expect(cli.calls.single, ['plugin', 'marketplace', 'update']);
    expect(find.text('p@m'), findsOneWidget);
    expect(find.text('1.0 → 1.1'), findsOneWidget);
    expect(find.text('스킬 3개'), findsOneWidget);
  });

  testWidgets('확인 중 다시 눌러도 한 번만 실행', (t) async {
    final cli = _FakeCli()..gate = Completer<void>();
    await _pump(t, cli);
    await t.tap(find.text('업데이트 확인'));
    await t.pump();
    expect(find.byType(CircularProgressIndicator), findsWidgets); // 진행 중 링
    await t.tap(find.byType(GlassTap)); // 링이 돈다고 다시 눌러도
    await t.pump();
    cli.gate!.complete();
    await t.pumpAndSettle();
    expect(cli.calls, hasLength(1));
  });

  testWidgets('모두 최신', (t) async {
    await _pump(t, _FakeCli(), found: const []);
    await t.tap(find.text('업데이트 확인'));
    await t.pumpAndSettle();
    expect(find.text('모든 플러그인이 최신이다'), findsOneWidget);
  });

  testWidgets('확인할 수 없음 묶음', (t) async {
    await _pump(t, _FakeCli(), found: const [_needed, _unknown]);
    await t.tap(find.text('업데이트 확인'));
    await t.pumpAndSettle();
    expect(find.text('확인할 수 없음'), findsOneWidget);
    expect(find.text('q@n'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '업데이트'), findsOneWidget);
  });

  testWidgets('업데이트는 확인 창 뒤에, 취소하면 실행 안 함', (t) async {
    final cli = _FakeCli();
    var updated = 0;
    await _pump(t, cli, onUpdated: () async => updated++);
    await t.tap(find.text('업데이트 확인'));
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(FilledButton, '업데이트'));
    await t.pumpAndSettle();
    expect(
      find.text('p@m을(를) 1.0 → 1.1(으)로 업데이트한다. Claude Code를 다시 시작해야 적용된다.'),
      findsOneWidget,
    );
    await t.tap(find.text('취소'));
    await t.pumpAndSettle();
    expect(cli.calls, hasLength(1));

    await t.tap(find.widgetWithText(FilledButton, '업데이트'));
    await t.pumpAndSettle();
    await t.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('업데이트')));
    await t.pumpAndSettle();
    expect(cli.calls.last, ['plugin', 'update', 'p@m', '--scope', 'user', '--json']);
    expect(updated, 1);
  });

  testWidgets('업데이트 실패는 이유를 보여준다', (t) async {
    final cli = _FakeCli(
      answer: (a) => a[1] == 'update' ? const CmdResult(1, '', 'boom') : const CmdResult(0, '', ''),
    );
    await _pump(t, cli);
    await t.tap(find.text('업데이트 확인'));
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(FilledButton, '업데이트'));
    await t.pumpAndSettle();
    await t.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('업데이트')));
    await t.pumpAndSettle();
    expect(find.textContaining('boom'), findsOneWidget);
  });

  testWidgets('claude 명령이 없으면 안내', (t) async {
    await _pump(t, _FakeCli(missing: true));
    await t.tap(find.text('업데이트 확인'));
    await t.pumpAndSettle();
    expect(find.text('Claude Code 명령(claude)을 찾지 못했다'), findsOneWidget);
  });

  testWidgets('추가 확인이 필요한 플러그인은 직접 업데이트 안내', (t) async {
    final cli = _FakeCli(
      answer: (a) => a[1] == 'update'
          ? const CmdResult(2, '{"shownCommand":{"sha256":"x"}}', '')
          : const CmdResult(0, '', ''),
    );
    await _pump(t, cli);
    await t.tap(find.text('업데이트 확인'));
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(FilledButton, '업데이트'));
    await t.pumpAndSettle();
    await t.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('업데이트')));
    await t.pumpAndSettle();
    expect(find.text('Claude Code에서 직접 업데이트해야 한다'), findsOneWidget);
  });

  testWidgets('확인·업데이트 결과를 알린다', (t) async {
    final seen = <int>[];
    await _pump(t, _FakeCli(), onChecked: (l) => seen.add(l.length));
    await t.tap(find.text('업데이트 확인'));
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(FilledButton, '업데이트'));
    await t.pumpAndSettle();
    await t.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('업데이트')));
    await t.pumpAndSettle();
    expect(seen, [1, 0]);
  });
}
