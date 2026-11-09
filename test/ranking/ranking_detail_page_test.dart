import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skill_gui/features/ranking/data/ranking_api_client.dart';
import 'package:skill_gui/features/ranking/install/install_history.dart';
import 'package:skill_gui/features/ranking/install/skill_installer.dart';
import 'package:skill_gui/features/ranking/models/ranking_models.dart';
import 'package:skill_gui/features/ranking/ranking_detail_page.dart';
import 'package:skill_gui/features/ranking/ranking_screen.dart';

import 'terminal_panel_test.dart' show FakeRunner;

// 테스트용 가짜 데이터. 실제 skills.sh 수치가 아니다.
const _item = SkillRankItem(
  id: 'fake/repo/fake-skill',
  slug: 'fake-skill',
  name: 'fake-skill',
  source: 'fake/repo',
  installs: 1234,
  sourceType: 'github',
  installUrl: 'https://github.com/fake/repo',
  url: 'https://example.test',
);

final _detailBody = jsonEncode({
  'id': 'fake/repo/fake-skill',
  'source': 'fake/repo',
  'slug': 'fake-skill',
  'installs': 1234,
  'hash': 'x',
  'files': [
    {'path': 'SKILL.md', 'contents': '---\nname: fake-skill\n---\n가짜 본문'},
    {'path': 'docs/a.md', 'contents': '문서'},
  ],
});

RankingApiClient _client({
  int auditStatus = 200,
  List<Map<String, Object?>> audits = const [
    {'provider': '가짜 점검', 'slug': 'x', 'status': 'pass', 'summary': '문제 없음'},
  ],
  List<Uri>? log,
}) => RankingApiClient(
  'https://relay.example.test',
  httpGet: (uri) async {
    log?.add(uri);
    if (uri.path.endsWith('/api/skill')) {
      return RankingHttpResponse(200, _detailBody);
    }
    if (uri.path.endsWith('/api/audit')) {
      return auditStatus == 200
          ? RankingHttpResponse(200, jsonEncode({'audits': audits}))
          : RankingHttpResponse(auditStatus, jsonEncode({'error': '없음'}));
    }
    if (uri.path.endsWith('/api/stars')) {
      return RankingHttpResponse(200, '{"stars": {}, "limited": false}');
    }
    return RankingHttpResponse(
      200,
      jsonEncode({
        'data': [
          {
            'id': _item.id,
            'slug': _item.slug,
            'name': _item.name,
            'source': _item.source,
            'installs': _item.installs,
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

/// 누른 뒤 실제 파일 입출력(폴더 확인)이 끝나도록 잠깐 기다린다.
Future<void> _tapWithIo(WidgetTester tester, Finder finder) async {
  await tester.runAsync(() async {
    await tester.tap(finder);
    await tester.pump();
    await Future<void>.delayed(const Duration(milliseconds: 300));
  });
  await tester.pumpAndSettle();
}

void main() {
  late Directory home;
  setUp(() => home = Directory.systemTemp.createTempSync('detail-test'));
  tearDown(() => home.deleteSync(recursive: true));

  Future<void> pumpDetail(
    WidgetTester tester, {
    RankingApiClient? client,
    VoidCallback? onBack,
    VoidCallback? onInstalled,
    FakeRunner? runner,
    InstallHistory? history,
    bool installed = false,
  }) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RankingDetailPage(
            item: _item,
            client: client ?? _client(),
            installer: SkillInstaller(home: home.path),
            onBack: onBack ?? () {},
            onInstalled: onInstalled,
            runner: runner ?? FakeRunner(),
            history: history,
            installed: installed,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('SKILL.md·파일 목록·보안 점검을 보여 준다', (tester) async {
    final log = <Uri>[];
    await pumpDetail(tester, client: _client(log: log));
    expect(
      log.firstWhere((u) => u.path.endsWith('/api/skill')).queryParameters,
      {'id': 'fake/repo/fake-skill'},
    );
    expect(find.textContaining('가짜 본문'), findsOneWidget);
    expect(find.text('docs/a.md'), findsOneWidget);
    expect(find.text('가짜 점검'), findsOneWidget);
    expect(find.text('통과'), findsOneWidget);
  });

  testWidgets('점검 기록이 없으면(404) 없다고 알린다', (tester) async {
    await pumpDetail(tester, client: _client(auditStatus: 404));
    expect(find.text('아직 보안 점검 기록이 없습니다.'), findsOneWidget);
  });

  testWidgets('직접 설치를 누르면 운영체제별 CLI 명령이 보이고 복사된다', (tester) async {
    final copied = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied.add((call.arguments as Map)['text'] as String);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await pumpDetail(tester);
    expect(find.byKey(const Key('ranking-guide-card')), findsNothing);

    await tester.tap(find.byKey(const Key('ranking-direct-install')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ranking-os-windows')));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'npx.cmd skills add fake/repo `\n  --skill fake-skill `\n  -a claude-code -g',
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('ranking-os-macos')));
    await tester.tap(find.byKey(const Key('ranking-target-codex')));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'npx skills add fake/repo \\\n  --skill fake-skill \\\n  -a codex -g',
      ),
      findsOneWidget,
    );

    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('ranking-command-macos')),
        matching: find.byKey(const Key('command-copy')),
      ),
    );
    await tester.pump();
    expect(copied, ['npx skills add fake/repo --skill fake-skill -a codex -g']);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('설치 버튼은 확인을 받고 Claude Code 폴더에 쓴다', (tester) async {
    var installed = 0;
    await pumpDetail(tester, onInstalled: () => installed++);

    await _tapWithIo(tester, find.byKey(const Key('ranking-install')));
    expect(find.text('스킬을 설치할까요?'), findsOneWidget);

    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('ranking-install-confirm')));
      await tester.pump();
      // 파일 쓰기는 실제 입출력이라 잠깐 기다린다.
      await Future<void>.delayed(const Duration(milliseconds: 500));
    });
    await tester.pumpAndSettle();

    final skillMd = File(
      [
        home.path,
        '.claude',
        'skills',
        'fake-skill',
        'SKILL.md',
      ].join(Platform.pathSeparator),
    );
    expect(skillMd.existsSync(), isTrue);
    expect(installed, 1);
    expect(find.byKey(const Key('ranking-install-message')), findsOneWidget);
    expect(find.byKey(const Key('ranking-detail-installed')), findsOneWidget);
  });

  testWidgets('설치 확인에서 취소하면 아무것도 쓰지 않는다', (tester) async {
    await pumpDetail(tester);
    await _tapWithIo(tester, find.byKey(const Key('ranking-install')));
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(Directory('${home.path}/.claude').existsSync(), isFalse);
  });

  testWidgets('지금 운영체제 명령의 실행 버튼이 터미널에서 설치 명령을 돌린다', (tester) async {
    final runner = FakeRunner();
    final history = InstallHistory();
    var installed = 0;
    await pumpDetail(
      tester,
      runner: runner,
      history: history,
      onInstalled: () => installed++,
    );
    await tester.tap(find.byKey(const Key('ranking-direct-install')));
    await tester.pumpAndSettle();

    final host = Platform.isWindows ? 'windows' : 'macos';
    final other = Platform.isWindows ? 'macos' : 'windows';
    await tester.tap(find.byKey(Key('ranking-os-$other')));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(Key('ranking-command-$other')),
        matching: find.byKey(const Key('command-run')),
      ),
      findsNothing,
    );

    await tester.tap(find.byKey(Key('ranking-os-$host')));
    await tester.pumpAndSettle();
    final runButton = find.descendant(
      of: find.byKey(Key('ranking-command-$host')),
      matching: find.byKey(const Key('command-run')),
    );
    await tester.ensureVisible(runButton);
    await tester.tap(runButton);
    await tester.pump();
    final npx = Platform.isWindows ? 'npx.cmd' : 'npx';
    expect(runner.started, [
      '$npx skills add fake/repo --skill fake-skill -a claude-code -g',
    ]);

    expect(history.records.single.status, InstallStatus.running);
    expect(history.records.single.method, InstallMethod.cli);

    runner.commands.single.finish(0);
    await tester.pumpAndSettle();
    expect(history.records.single.status, InstallStatus.done);
    expect(installed, 1);
    expect(find.byKey(const Key('ranking-detail-installed')), findsOneWidget);
  });

  testWidgets('이미 설치된 스킬은 그 설치할 곳에서 설치 버튼을 숨긴다', (tester) async {
    await pumpDetail(tester, installed: true);
    expect(find.byKey(const Key('ranking-already-installed')), findsOneWidget);
    expect(find.byKey(const Key('ranking-install')), findsNothing);
    expect(find.byKey(const Key('ranking-direct-install')), findsNothing);

    // 내 스킬 스캔은 Claude Code 만 보므로 Codex 에는 설치할 수 있다.
    await tester.tap(find.byKey(const Key('ranking-target-codex')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ranking-install')), findsOneWidget);
  });

  testWidgets('설치할 곳에 같은 이름 폴더가 있으면 설치된 것으로 본다', (tester) async {
    Directory(
      [
        home.path,
        '.agents',
        'skills',
        'fake-skill',
      ].join(Platform.pathSeparator),
    ).createSync(recursive: true);
    await tester.runAsync(() async {
      await pumpDetail(tester);
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();
    // Claude Code 에는 없으므로 버튼이 보인다.
    expect(find.byKey(const Key('ranking-install')), findsOneWidget);
    await tester.tap(find.byKey(const Key('ranking-target-codex')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ranking-already-installed')), findsOneWidget);
  });

  testWidgets('뒤로 버튼과 Esc 가 onBack 을 부른다', (tester) async {
    var back = 0;
    await pumpDetail(tester, onBack: () => back++);
    await tester.tap(find.byKey(const Key('ranking-detail-back')));
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    expect(back, 2);
  });

  testWidgets('랭킹 타일을 누르면 상세로 가고 뒤로 오면 목록이다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: RankingScreen(client: _client())),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('fake-skill'));
    await tester.pumpAndSettle();
    expect(find.byType(RankingDetailPage), findsOneWidget);

    await tester.tap(find.byKey(const Key('ranking-detail-back')));
    await tester.pumpAndSettle();
    expect(find.byType(RankingDetailPage), findsNothing);
    expect(find.text('fake-skill'), findsOneWidget);
  });
}
