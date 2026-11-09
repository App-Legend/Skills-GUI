import 'dart:async';
import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skill_gui/features/ranking/data/ranking_api_client.dart';
import 'package:skill_gui/features/ranking/install/install_history.dart';
import 'package:skill_gui/features/ranking/install/skill_installer.dart';
import 'package:skill_gui/features/ranking/models/ranking_models.dart';
import 'package:skill_gui/features/ranking/ranking_detail_page.dart';
import 'package:skill_gui/features/ranking/ranking_screen.dart';
import 'package:skill_gui/features/ranking/widgets/install_history_view.dart';
import 'package:skill_gui/scan/skill.dart';
import 'package:skill_gui/ui/app_shell.dart';

import 'terminal_panel_test.dart' show FakeRunner;

/// 테스트가 끝내라고 할 때까지 설치를 붙잡고 있는 가짜 설치기. 파일은 쓰지 않는다.
class _SlowInstaller extends SkillInstaller {
  _SlowInstaller() : super(home: '/fake-home');
  final gate = Completer<void>();
  bool fail = false;

  @override
  Future<bool> exists(InstallTarget target, String slug) async => false;

  @override
  Future<SkillInstallResult> install(
    SkillDetail detail,
    InstallTarget target, {
    bool overwrite = false,
  }) async {
    await gate.future;
    if (fail) throw const SkillInstallException('가짜 실패');
    return const SkillInstallResult(
      directory: '/fake-home/.claude/skills/fake-skill',
      written: 1,
      skipped: [],
    );
  }
}

// 테스트용 가짜 데이터. 실제 skills.sh 수치가 아니다.
RankingApiClient _client() => RankingApiClient(
  'https://relay.example.test',
  httpGet: (uri) async {
    if (uri.path.endsWith('/api/stars')) {
      return const RankingHttpResponse(200, '{"stars": {}, "limited": false}');
    }
    if (uri.path.endsWith('/api/skill')) {
      return RankingHttpResponse(
        200,
        jsonEncode({
          'id': 'fake/repo/fake-skill',
          'source': 'fake/repo',
          'slug': 'fake-skill',
          'installs': 1,
          'files': [
            {'path': 'SKILL.md', 'contents': '가짜 본문'},
          ],
        }),
      );
    }
    if (uri.path.endsWith('/api/audit')) {
      return const RankingHttpResponse(404, '{"error":"없음"}');
    }
    return RankingHttpResponse(
      200,
      jsonEncode({
        'data': [
          {
            'id': 'fake/repo/fake-skill',
            'slug': 'fake-skill',
            'name': 'fake-skill',
            'source': 'fake/repo',
            'installs': 1,
            'sourceType': 'github',
            'installUrl': null,
            'url': 'https://example.test',
          },
        ],
        'pagination': {'page': 0, 'perPage': 1, 'total': 1, 'hasMore': false},
      }),
    );
  },
);

void main() {
  group('InstallHistory', () {
    test('시작하면 설치 중, 끝내면 완료·실패로 바뀌고 최근 것이 먼저', () {
      final h = InstallHistory();
      final a = h.start(
        name: 'a',
        source: 's/a',
        target: 'Claude Code',
        method: InstallMethod.app,
      );
      final b = h.start(
        name: 'b',
        source: 's/b',
        target: 'Codex',
        method: InstallMethod.cli,
      );
      expect(h.runningCount, 2);
      expect(h.isRunning('a'), isTrue);
      expect(h.records.map((r) => r.name), ['b', 'a']);

      h.finish(a, ok: true);
      h.finish(b, ok: false, message: '종료 코드 1');
      expect(h.runningCount, 0);
      expect(a.status, InstallStatus.done);
      expect(b.status, InstallStatus.failed);
      expect(b.message, '종료 코드 1');
      expect(a.finishedAt, isNotNull);

      // 이미 끝난 기록은 다시 바뀌지 않는다.
      h.finish(a, ok: false);
      expect(a.status, InstallStatus.done);
    });

    test('끝난 기록만 지운다', () {
      final h = InstallHistory();
      final a = h.start(
        name: 'a',
        source: 's',
        target: 't',
        method: InstallMethod.app,
      );
      h.start(name: 'b', source: 's', target: 't', method: InstallMethod.app);
      h.finish(a, ok: true);
      h.clearFinished();
      expect(h.records.map((r) => r.name), ['b']);
    });
  });

  testWidgets('설치 중에 다른 탭에 가도 사이드바에 "설치 중"이 보이고, 끝나면 기록에 남는다', (t) async {
    t.view.physicalSize = const Size(1400, 1100);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final history = InstallHistory();
    final installer = _SlowInstaller();
    var rescans = 0;

    await t.pumpWidget(
      MaterialApp(
        home: AppShell(
          result: const ScanResult(
            skills: [
              Skill(name: 'alpha', source: SkillSource.global, path: '/a'),
            ],
          ),
          onRescan: () async {},
          installHistory: history,
          ranking: RankingScreen(
            client: _client(),
            installer: installer,
            history: history,
            onInstalled: () => rescans++,
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.text('랭킹'));
    await t.pumpAndSettle();
    await t.tap(find.text('fake-skill'));
    await t.pumpAndSettle();

    await t.tap(find.byKey(const Key('ranking-install')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('ranking-install-confirm')));
    await t.pump();

    expect(history.runningCount, 1);
    expect(find.byKey(const Key('sidebar-installing')), findsOneWidget);
    expect(find.byKey(const Key('install-history-panel')), findsOneWidget);

    // 다른 탭으로 가도 사이드바 표시는 남는다.
    await t.tap(find.text('내 스킬'));
    await t.pump();
    expect(find.byKey(const Key('sidebar-installing')), findsOneWidget);

    // 설치가 끝나면 표시가 사라지고 기록에는 완료로 남는다.
    installer.gate.complete();
    await t.pumpAndSettle();
    expect(find.byKey(const Key('sidebar-installing')), findsNothing);
    expect(history.records.single.status, InstallStatus.done);
    expect(history.records.single.method, InstallMethod.app);
    expect(rescans, 1);

    // 설치를 시작하면 오른쪽 사이드바가 열려 있고, 완료 기록이 보인다.
    expect(find.byKey(const Key('install-history-panel')), findsOneWidget);
    expect(find.byType(InstallHistoryView), findsOneWidget);
    expect(find.text('완료'), findsOneWidget);

    // 접기 → 오른쪽 끝의 접힌 탭(≪)으로 다시 편다. 다른 탭에서도 보인다.
    await t.tap(find.byKey(const Key('install-history-close')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('install-history-panel')), findsNothing);
    expect(find.byKey(const Key('install-history-rail')), findsOneWidget);
    await t.tap(find.text('내 스킬').first);
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('install-history-open')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('install-history-panel')), findsOneWidget);

    // 끝난 기록 지우기.
    await t.tap(find.byKey(const Key('install-history-clear')));
    await t.pumpAndSettle();
    expect(history.records, isEmpty);
  });

  testWidgets('설치가 실패하면 기록에 실패와 이유가 남는다', (t) async {
    t.view.physicalSize = const Size(1400, 1100);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final history = InstallHistory();
    final installer = _SlowInstaller()..fail = true;

    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RankingScreen(
            client: _client(),
            installer: installer,
            history: history,
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.text('fake-skill'));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('ranking-install')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('ranking-install-confirm')));
    await t.pump();
    installer.gate.complete();
    await t.pumpAndSettle();

    final record = history.records.single;
    expect(record.status, InstallStatus.failed);
    expect(record.message, '가짜 실패');
  });

  testWidgets('터미널 설치 중에 상세를 닫아도 오류 없이 실패 기록으로 남는다', (t) async {
    t.view.physicalSize = const Size(1400, 1100);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final history = InstallHistory();
    final runner = FakeRunner();
    const item = SkillRankItem(
      id: 'fake/repo/fake-skill',
      slug: 'fake-skill',
      name: 'fake-skill',
      source: 'fake/repo',
      installs: 1,
      sourceType: 'github',
      installUrl: null,
      url: 'https://example.test',
    );
    var open = true;
    late StateSetter setOuter;
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              setOuter = setState;
              return Row(
                children: [
                  // 기록을 듣는 다른 위젯 (사이드바·오른쪽 패널 흉내).
                  SizedBox(
                    width: 300,
                    child: InstallHistoryPanel(history: history),
                  ),
                  Expanded(
                    child: open
                        ? RankingDetailPage(
                            item: item,
                            client: _client(),
                            onBack: () {},
                            history: history,
                            runner: runner,
                          )
                        : const SizedBox(),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('ranking-direct-install')));
    await t.pumpAndSettle();
    final host = Platform.isWindows ? 'windows' : 'macos';
    final run = find.descendant(
      of: find.byKey(Key('ranking-command-$host')),
      matching: find.byKey(const Key('command-run')),
    );
    await t.ensureVisible(run);
    await t.tap(run);
    await t.pump();
    expect(history.records.single.status, InstallStatus.running);

    // 설치 중에 상세를 닫는다.
    setOuter(() => open = false);
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    expect(history.records.single.status, InstallStatus.failed);
    expect(history.records.single.message, '상세 화면을 닫아 중지했습니다');
    // 멈춘 명령의 남은 출력을 기다리는 2초 타이머가 끝나게 둔다.
    await t.pump(const Duration(seconds: 3));
  });
}
