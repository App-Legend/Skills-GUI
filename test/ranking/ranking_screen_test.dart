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

RankingApiClient _client(
  RankingHttpResponse Function(Uri) respond,
  List<Uri> log,
) {
  return RankingApiClient('https://relay.example.test', httpGet: (uri) async {
    log.add(uri);
    return respond(uri);
  });
}

Future<void> _pump(WidgetTester tester, RankingApiClient? client) async {
  await tester.pumpWidget(MaterialApp(home: RankingScreen(client: client)));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('처음에 전체 보기 1페이지를 불러온다', (tester) async {
    final log = <Uri>[];
    await _pump(
      tester,
      _client((_) => RankingHttpResponse(
          200, _body(['가짜A', '가짜B'], page: 1, hasMore: false)), log),
    );
    expect(log.single.queryParameters['view'], 'all-time');
    expect(log.single.queryParameters['page'], '1');
    expect(find.text('가짜A'), findsOneWidget);
    expect(find.text('가짜B'), findsOneWidget);
    expect(find.byKey(const Key('ranking-tile-change')), findsNothing);
  });

  testWidgets('탭을 바꿀 때마다 해당 view 로 불러온다', (tester) async {
    final log = <Uri>[];
    await _pump(
      tester,
      _client((uri) => RankingHttpResponse(
          200,
          _body(['${uri.queryParameters['view']}-항목'],
              page: 1, hasMore: false)), log),
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
          _body(['가짜$page'], page: page, hasMore: page < 2),
        );
      }, log),
    );
    expect(find.text('가짜1'), findsOneWidget);

    await tester.tap(find.byKey(const Key('ranking-next-page')));
    await tester.pumpAndSettle();
    expect(log.last.queryParameters['page'], '2');
    expect(find.text('가짜1'), findsOneWidget);
    expect(find.text('가짜2'), findsOneWidget);
    expect(find.byKey(const Key('ranking-next-page')), findsNothing);
  });

  testWidgets('호출이 실패하면 오류 메시지를 그대로 보인다', (tester) async {
    await _pump(
      tester,
      _client((_) => RankingHttpResponse(502, jsonEncode({'error': '가짜 오류'})),
          <Uri>[]),
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
            200, _body(['가짜A'], page: 1, hasMore: false));
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
      _client((_) => RankingHttpResponse(
          200, _body([], page: 1, hasMore: false)), <Uri>[]),
    );
    expect(find.byKey(const Key('ranking-state-empty')), findsOneWidget);
  });

  testWidgets('다음 페이지 호출이 실패하면 기존 목록을 두고 오류를 보인다', (tester) async {
    await _pump(
      tester,
      _client((uri) {
        if (uri.queryParameters['page'] == '1') {
          return RankingHttpResponse(
              200, _body(['가짜A'], page: 1, hasMore: true));
        }
        return RankingHttpResponse(500, jsonEncode({'error': '가짜 오류'}));
      }, <Uri>[]),
    );
    await tester.tap(find.byKey(const Key('ranking-next-page')));
    await tester.pumpAndSettle();
    expect(find.text('가짜A'), findsOneWidget);
    expect(find.text('가짜 오류'), findsOneWidget);
  });

  testWidgets('서버 주소 설정이 없으면 설정 누락 오류를 보인다', (tester) async {
    // dart-define 없이 테스트를 돌릴 때만 해당한다.
    if (RankingConfig.isConfigured) return;
    await _pump(tester, null);
    expect(find.text(RankingConfig.missingMessage), findsOneWidget);
  });
}
