import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skill_gui/features/ranking/data/ranking_api_client.dart';
import 'package:skill_gui/features/ranking/ranking_config.dart';
import 'package:skill_gui/features/ranking/ranking_screen.dart';

// 테스트용 가짜 데이터. 실제 skills.sh 수치가 아니다.
String _body(List<String> names, {required int page, required bool hasMore}) {
  return jsonEncode({
    'data': [
      for (final name in names)
        {
          'id': 'id-$name',
          'slug': 'slug-$name',
          'name': name,
          'source': 'fake/$name',
          'installs': 1,
          'sourceType': 'github',
          'installUrl': 'https://example.test/install',
          'url': 'https://example.test/skill',
          'change': 5,
        },
    ],
    'pagination': {
      'page': page,
      'perPage': names.length,
      'total': 99,
      'hasMore': hasMore,
    },
  });
}

/// 랭킹·검색 요청은 [respond] 로 답하고 [log] 에 남긴다.
/// 스타 요청(/api/stars)은 저장소마다 1234 로 답하고 [starsLog] 에만 남긴다.
RankingApiClient _client(
  RankingHttpResponse Function(Uri) respond,
  List<Uri> log, {
  List<Uri>? starsLog,
}) {
  return RankingApiClient(
    'https://relay.example.test',
    httpGet: (uri) async {
      if (uri.path.endsWith('/api/stars')) {
        starsLog?.add(uri);
        final repos = uri.queryParameters['repos']!.split(',');
        return RankingHttpResponse(
          200,
          jsonEncode({
            'stars': {for (final r in repos) r: 1234},
            'limited': false,
          }),
        );
      }
      log.add(uri);
      return respond(uri);
    },
  );
}

Future<void> _pump(WidgetTester tester, RankingApiClient? client) async {
  await tester.pumpWidget(MaterialApp(home: RankingScreen(client: client)));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('처음에 전체 보기 0페이지를 불러온다', (tester) async {
    final log = <Uri>[];
    await _pump(
      tester,
      _client(
        (_) => RankingHttpResponse(
          200,
          _body(['가짜A', '가짜B'], page: 0, hasMore: false),
        ),
        log,
      ),
    );
    expect(log.single.queryParameters['view'], 'all-time');
    expect(log.single.queryParameters['page'], '0');
    expect(find.text('가짜A'), findsOneWidget);
    expect(find.text('가짜B'), findsOneWidget);
    expect(find.byKey(const Key('ranking-tile-change')), findsNothing);
  });

  testWidgets('탭을 바꿀 때마다 해당 view 로 불러온다', (tester) async {
    final log = <Uri>[];
    await _pump(
      tester,
      _client(
        (uri) => RankingHttpResponse(
          200,
          _body(['${uri.queryParameters['view']}-항목'], page: 1, hasMore: false),
        ),
        log,
      ),
    );
    await tester.tap(find.text('트렌딩'));
    await tester.pumpAndSettle();
    expect(log.last.queryParameters['view'], 'trending');
    expect(find.text('trending-항목'), findsOneWidget);

    await tester.tap(find.text('핫'));
    await tester.pumpAndSettle();
    expect(log.last.queryParameters['view'], 'hot');
    expect(find.text('hot-항목'), findsOneWidget);
    expect(find.byKey(const Key('ranking-tile-change')), findsOneWidget);
    expect(find.text('+5'), findsOneWidget);
  });

  testWidgets('다음 페이지 버튼이 page 를 1 올려 목록을 이어 붙인다', (tester) async {
    final log = <Uri>[];
    await _pump(
      tester,
      _client((uri) {
        final page = int.parse(uri.queryParameters['page']!);
        return RankingHttpResponse(
          200,
          _body(['가짜$page'], page: page, hasMore: page < 1),
        );
      }, log),
    );
    expect(find.text('가짜0'), findsOneWidget);

    await tester.tap(find.byKey(const Key('ranking-next-page')));
    await tester.pumpAndSettle();
    expect(log.last.queryParameters['page'], '1');
    expect(find.text('가짜0'), findsOneWidget);
    expect(find.text('가짜1'), findsOneWidget);
    expect(find.byKey(const Key('ranking-next-page')), findsNothing);
  });

  testWidgets('호출이 실패하면 오류 메시지를 그대로 보인다', (tester) async {
    await _pump(
      tester,
      _client(
        (_) => RankingHttpResponse(502, jsonEncode({'error': '가짜 오류'})),
        <Uri>[],
      ),
    );
    expect(find.text('가짜 오류'), findsOneWidget);
    expect(find.byKey(const Key('ranking-state-retry')), findsOneWidget);
  });

  testWidgets('오류 뒤 다시 시도하면 불러온다', (tester) async {
    var calls = 0;
    await _pump(
      tester,
      _client((_) {
        calls++;
        if (calls == 1) return const RankingHttpResponse(503, '');
        return RankingHttpResponse(
          200,
          _body(['가짜A'], page: 1, hasMore: false),
        );
      }, <Uri>[]),
    );
    expect(find.byKey(const Key('ranking-state-error')), findsOneWidget);
    await tester.tap(find.byKey(const Key('ranking-state-retry')));
    await tester.pumpAndSettle();
    expect(find.text('가짜A'), findsOneWidget);
  });

  testWidgets('목록이 비면 빈 상태를 보인다', (tester) async {
    await _pump(
      tester,
      _client(
        (_) => RankingHttpResponse(200, _body([], page: 1, hasMore: false)),
        <Uri>[],
      ),
    );
    expect(find.byKey(const Key('ranking-state-empty')), findsOneWidget);
  });

  testWidgets('다음 페이지 호출이 실패하면 기존 목록을 두고 오류를 보인다', (tester) async {
    await _pump(
      tester,
      _client((uri) {
        if (uri.queryParameters['page'] == '0') {
          return RankingHttpResponse(
            200,
            _body(['가짜A'], page: 0, hasMore: true),
          );
        }
        return RankingHttpResponse(500, jsonEncode({'error': '가짜 오류'}));
      }, <Uri>[]),
    );
    await tester.tap(find.byKey(const Key('ranking-next-page')));
    await tester.pumpAndSettle();
    expect(find.text('가짜A'), findsOneWidget);
    expect(find.text('가짜 오류'), findsOneWidget);
  });

  testWidgets('GitHub 저장소 스타 수를 가져와 타일에 보인다', (tester) async {
    final starsLog = <Uri>[];
    await _pump(
      tester,
      _client(
        (_) => RankingHttpResponse(
          200,
          _body(['skill-a', 'skill-b'], page: 0, hasMore: false),
        ),
        <Uri>[],
        starsLog: starsLog,
      ),
    );
    expect(starsLog, hasLength(1));
    expect(
      starsLog.single.queryParameters['repos']!.split(','),
      unorderedEquals(['fake/skill-a', 'fake/skill-b']),
    );
    expect(find.text('★ 1,234'), findsNWidgets(2));
  });

  testWidgets('검색창에 입력하면 검색 결과로 바뀌고 돌아갈 수 있다', (tester) async {
    final log = <Uri>[];
    await _pump(
      tester,
      _client((uri) {
        if (uri.path.endsWith('/api/search')) {
          return RankingHttpResponse(
            200,
            jsonEncode({
              'query': uri.queryParameters['q'],
              'data': jsonDecode(
                _body(['검색된-react'], page: 0, hasMore: false),
              )['data'],
            }),
          );
        }
        return RankingHttpResponse(
          200,
          _body(['랭킹-항목'], page: 0, hasMore: false),
        );
      }, log),
    );
    expect(find.text('랭킹-항목'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('ranking-search-field')),
      'react',
    );
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    final search = log.lastWhere((u) => u.path.endsWith('/api/search'));
    expect(search.queryParameters['q'], 'react');
    expect(find.text('검색된-react'), findsOneWidget);
    expect(find.text('랭킹-항목'), findsNothing);
    expect(find.text('"react" 검색 결과 1개'), findsOneWidget);

    await tester.tap(find.byKey(const Key('ranking-search-back')));
    await tester.pumpAndSettle();
    expect(find.text('랭킹-항목'), findsOneWidget);
    expect(find.text('검색된-react'), findsNothing);
  });

  testWidgets('검색어가 1자면 검색하지 않는다', (tester) async {
    final log = <Uri>[];
    await _pump(
      tester,
      _client(
        (_) =>
            RankingHttpResponse(200, _body(['가짜A'], page: 0, hasMore: false)),
        log,
      ),
    );
    await tester.enterText(find.byKey(const Key('ranking-search-field')), 'r');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(log.where((u) => u.path.endsWith('/api/search')), isEmpty);
    expect(find.text('가짜A'), findsOneWidget);
  });

  testWidgets('카테고리를 고르면 그 분야 스킬만 보이고 순위는 그대로다', (tester) async {
    await _pump(
      tester,
      _client(
        (_) => RankingHttpResponse(
          200,
          _body(
            ['react-tips', 'postgres-helper', 'docker-deploy'],
            page: 0,
            hasMore: false,
          ),
        ),
        <Uri>[],
      ),
    );
    expect(find.text('react-tips'), findsOneWidget);
    expect(find.text('postgres-helper'), findsOneWidget);

    await tester.tap(find.byKey(const Key('ranking-category-backend')));
    await tester.pumpAndSettle();
    expect(find.text('postgres-helper'), findsOneWidget);
    expect(find.text('react-tips'), findsNothing);
    expect(find.text('docker-deploy'), findsNothing);
    // 거르기 전 순위(2위)를 그대로 보인다.
    expect(
      tester.widget<Text>(find.byKey(const Key('ranking-tile-rank'))).data,
      '2',
    );

    await tester.tap(find.byKey(const Key('ranking-category-all')));
    await tester.pumpAndSettle();
    expect(find.text('react-tips'), findsOneWidget);
  });

  testWidgets('카테고리 결과가 적으면 다음 페이지를 자동으로 더 불러온다', (tester) async {
    final log = <Uri>[];
    await _pump(
      tester,
      _client((uri) {
        final page = int.parse(uri.queryParameters['page']!);
        final name = page == 0 ? 'react-tips' : 'postgres-$page';
        return RankingHttpResponse(
          200,
          _body([name], page: page, hasMore: page < 2),
        );
      }, log),
    );
    expect(log, hasLength(1));

    await tester.tap(find.byKey(const Key('ranking-category-backend')));
    await tester.pumpAndSettle();
    expect(log.map((u) => u.queryParameters['page']), ['0', '1', '2']);
    expect(find.text('postgres-1'), findsOneWidget);
    expect(find.text('postgres-2'), findsOneWidget);
  });

  testWidgets('서버 주소 설정이 없으면 설정 누락 오류를 보인다', (tester) async {
    // dart-define 없이 테스트를 돌릴 때만 해당한다.
    if (RankingConfig.isConfigured) return;
    await _pump(tester, null);
    expect(find.text(RankingConfig.missingMessage), findsOneWidget);
  });
}
