import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skill_gui/ui/glass.dart';
import 'package:skill_gui/ui/update_page.dart';
import 'package:skill_gui/features/update/claude_cli.dart';
import 'package:skill_gui/features/update/update_check.dart';

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

class _Source implements SkillUpdateSource {
  final Stream<({List<PluginUpdate> found, List<String> errors})> stream;

  _Source(this.stream);

  @override
  UpdateKind get kind => UpdateKind.skill;

  @override
  Stream<({List<PluginUpdate> found, List<String> errors})> check() => stream;

  @override
  Future<String?> update(PluginUpdate u) async => null;
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
          markets: (_) async => ['m'],
          onUpdated: onUpdated ?? () async {},
          onChecked: onChecked ?? (_) {},
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('열면 바로 쓰는 마켓만 새로 받고 목록을 보여준다', (t) async {
    final cli = _FakeCli();
    await _pump(t, cli);
    await t.pumpAndSettle();
    expect(cli.calls.single, ['plugin', 'marketplace', 'update', 'm']);
    expect(find.text('다시 조회'), findsOneWidget);
    expect(find.text('p@m'), findsOneWidget);
    expect(find.text('현재 버전 1.0 → 최신 버전 1.1'), findsOneWidget);
    expect(find.text('Claude Code 플러그인 · 스킬 3개'), findsOneWidget);
  });

  testWidgets('다시 조회하면 다시 받는다', (t) async {
    final cli = _FakeCli();
    await _pump(t, cli);
    await t.pumpAndSettle();
    await t.tap(find.text('다시 조회'));
    await t.pumpAndSettle();
    expect(cli.calls, hasLength(2));
  });

  testWidgets('마켓 갱신 실패는 이름과 이유를 보이고 목록은 보여준다', (t) async {
    await _pump(t, _FakeCli(answer: (_) => const CmdResult(1, '', 'offline')));
    await t.pumpAndSettle();
    expect(find.text('최신 정보를 받지 못했습니다: m(offline)'), findsOneWidget);
    expect(find.text('p@m'), findsOneWidget);
  });

  testWidgets('끝난 곳부터 보여주고 남은 곳은 확인 중 한 줄', (t) async {
    final slow = StreamController<({List<PluginUpdate> found, List<String> errors})>();
    t.view.physicalSize = const Size(1280, 820);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: UpdatePage(
            claudeDir: Directory.systemTemp,
            cli: _FakeCli(),
            check: (_) async => const [_needed],
            markets: (_) async => ['m'],
            onUpdated: () async {},
            onChecked: (_) {},
            sources: [_Source(slow.stream)],
          ),
        ),
      ),
    );
    await t.pump();
    await t.pump();
    expect(find.text('p@m'), findsOneWidget); // 플러그인 결과 먼저
    expect(find.text('나머지를 확인하는 중입니다'), findsOneWidget);
    slow.add((found: const [_unknown], errors: const []));
    await slow.close();
    await t.pumpAndSettle();
    expect(find.text('q@n'), findsOneWidget);
    expect(find.text('나머지를 확인하는 중입니다'), findsNothing);
  });

  testWidgets('확인 중 다시 눌러도 한 번만 실행', (t) async {
    final cli = _FakeCli()..gate = Completer<void>();
    await _pump(t, cli);
    await t.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget); // 버튼의 링
    expect(find.text('최신 정보를 받는 중입니다'), findsOneWidget); // 스켈레톤
    await t.tap(find.byType(GlassTap)); // 링이 돈다고 다시 눌러도
    await t.pump();
    cli.gate!.complete();
    await t.pumpAndSettle();
    expect(cli.calls, hasLength(1));
  });

  testWidgets('모두 최신', (t) async {
    await _pump(t, _FakeCli(), found: const []);
    await t.pumpAndSettle();
    expect(find.text('모두 최신입니다'), findsOneWidget);
  });

  testWidgets('확인할 수 없음 묶음', (t) async {
    await _pump(t, _FakeCli(), found: const [_needed, _unknown]);
    await t.pumpAndSettle();
    expect(find.text('확인할 수 없음'), findsOneWidget);
    expect(find.text('q@n'), findsOneWidget);
    expect(find.text('현재 버전 2.0 · 최신 버전 확인 불가'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '업데이트'), findsOneWidget);
  });

  testWidgets('업데이트는 확인 창 뒤에, 취소하면 실행 안 함', (t) async {
    final cli = _FakeCli();
    var updated = 0;
    await _pump(t, cli, onUpdated: () async => updated++);
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(FilledButton, '업데이트'));
    await t.pumpAndSettle();
    expect(
      find.text('p@m을(를) 1.0 → 1.1(으)로 업데이트합니다. Claude Code를 다시 시작해야 적용됩니다.'),
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
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(FilledButton, '업데이트'));
    await t.pumpAndSettle();
    await t.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('업데이트')));
    await t.pumpAndSettle();
    expect(find.textContaining('boom'), findsOneWidget);
  });

  testWidgets('claude 명령이 없으면 안내', (t) async {
    await _pump(t, _FakeCli(missing: true));
    await t.pumpAndSettle();
    expect(find.text('Claude Code 명령(claude)을 찾지 못했습니다'), findsOneWidget);
  });

  testWidgets('추가 확인이 필요한 플러그인은 직접 업데이트 안내', (t) async {
    final cli = _FakeCli(
      answer: (a) => a[1] == 'update'
          ? const CmdResult(2, '{"shownCommand":{"sha256":"x"}}', '')
          : const CmdResult(0, '', ''),
    );
    await _pump(t, cli);
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(FilledButton, '업데이트'));
    await t.pumpAndSettle();
    await t.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('업데이트')));
    await t.pumpAndSettle();
    expect(find.text('Claude Code에서 직접 업데이트해야 합니다'), findsOneWidget);
  });

  testWidgets('확인·업데이트 결과를 알린다', (t) async {
    final seen = <int>[];
    await _pump(t, _FakeCli(), onChecked: (l) => seen.add(l.length));
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(FilledButton, '업데이트'));
    await t.pumpAndSettle();
    await t.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('업데이트')));
    await t.pumpAndSettle();
    expect(seen, [1, 0]);
  });
}
