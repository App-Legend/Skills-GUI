import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skill_gui/features/ranking/data/ranking_api_client.dart';
import 'package:skill_gui/features/ranking/ranking_detail_page.dart';
import 'package:skill_gui/features/ranking/ranking_screen.dart';
import 'package:skill_gui/scan/skill.dart';
import 'package:skill_gui/ui/app_shell.dart';

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

/// main.dart 처럼 바깥에서 AppShell 을 다시 그릴 수 있게 감싼다 (다시 스캔 흉내).
class _Host extends StatefulWidget {
  const _Host({required this.client});
  final RankingApiClient client;
  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  int scans = 0;
  void rescan() => setState(() => scans++);

  @override
  Widget build(BuildContext context) => AppShell(
    result: ScanResult(
      skills: [
        Skill(name: 'alpha-$scans', source: SkillSource.global, path: '/a'),
      ],
    ),
    onRescan: () async => rescan(),
    ranking: RankingScreen(client: widget.client, onInstalled: rescan),
  );
}

void main() {
  Future<void> openDetail(WidgetTester t) async {
    t.view.physicalSize = const Size(1400, 1000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(MaterialApp(home: _Host(client: _client())));
    await t.pumpAndSettle();
    await t.tap(find.text('랭킹'));
    await t.pumpAndSettle();
    await t.tap(find.text('fake-skill'));
    await t.pumpAndSettle();
    expect(find.byType(RankingDetailPage), findsOneWidget);
  }

  testWidgets('다른 탭에 갔다 와도 랭킹 상세가 그대로다', (t) async {
    await openDetail(t);
    await t.tap(find.text('내 스킬'));
    await t.pumpAndSettle();
    await t.tap(find.text('랭킹'));
    await t.pumpAndSettle();
    expect(find.byType(RankingDetailPage), findsOneWidget);
  });

  testWidgets('다시 스캔(설치 완료 후)이 일어나도 랭킹 상세가 그대로다', (t) async {
    await openDetail(t);
    t.state<_HostState>(find.byType(_Host)).rescan();
    await t.pumpAndSettle();
    expect(find.byType(RankingDetailPage), findsOneWidget);
  });
}
