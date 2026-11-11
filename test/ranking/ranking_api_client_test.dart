import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:skill_gui/features/ranking/data/ranking_api_client.dart';
import 'package:skill_gui/features/ranking/models/ranking_models.dart';

// 테스트용 가짜 데이터. 실제 skills.sh 수치가 아니다.
final _okBody = jsonEncode({
  'data': [
    {
      'id': 'fake-id',
      'slug': 'fake-slug',
      'name': '가짜 스킬',
      'source': 'fake/source',
      'installs': 1,
      'sourceType': 'github',
      'installUrl': 'https://example.test/install',
      'url': 'https://example.test/skill',
    },
  ],
  'pagination': {'page': 2, 'perPage': 1, 'total': 3, 'hasMore': true},
});

final _errorBody = jsonEncode({'error': '가짜 오류'});

RankingApiClient clientWith(
  RankingHttpResponse Function(Uri) respond, {
  List<Uri>? log,
  String base = 'https://relay.example.test',
}) {
  return RankingApiClient(
    base,
    httpGet: (uri) async {
      log?.add(uri);
      return respond(uri);
    },
  );
}

void main() {
  test('200 응답을 파싱합니다', () async {
    final client = clientWith((_) => RankingHttpResponse(200, _okBody));
    final page = await client.fetchPage(RankingView.allTime, 2, 1);
    expect(page.items.single.name, '가짜 스킬');
    expect(page.pagination.page, 2);
  });

  test('쿼리 파라미터를 구성합니다', () async {
    final log = <Uri>[];
    final client = clientWith(
      (_) => RankingHttpResponse(200, _okBody),
      log: log,
    );
    await client.fetchPage(RankingView.hot, 3, 50);
    final uri = log.single;
    expect(uri.host, 'relay.example.test');
    expect(uri.path, '/api/ranking');
    expect(uri.queryParameters, {'view': 'hot', 'page': '3', 'per_page': '50'});
  });

  test('기준 주소 끝의 슬래시를 처리합니다', () {
    final client = clientWith(
      (_) => RankingHttpResponse(200, _okBody),
      base: 'https://relay.example.test/',
    );
    expect(client.buildUri(RankingView.trending, 1, 10).path, '/api/ranking');
  });

  for (final status in [400, 429, 503, 502, 500]) {
    test('상태 $status 는 RankingApiException', () async {
      final client = clientWith((_) => RankingHttpResponse(status, _errorBody));
      await expectLater(
        client.fetchPage(RankingView.allTime, 1, 10),
        throwsA(
          isA<RankingApiException>()
              .having((e) => e.statusCode, 'statusCode', status)
              .having((e) => e.message, 'message', isNotEmpty),
        ),
      );
    });
  }

  test('그 외 실패는 본문의 error 문구를 쓴다', () async {
    final client = clientWith((_) => RankingHttpResponse(502, _errorBody));
    await expectLater(
      client.fetchPage(RankingView.allTime, 1, 10),
      throwsA(
        isA<RankingApiException>().having((e) => e.message, 'message', '가짜 오류'),
      ),
    );
  });

  test('200 이어도 본문 형식이 틀리면 RankingApiException', () async {
    final client = clientWith((_) => const RankingHttpResponse(200, '[]'));
    await expectLater(
      client.fetchPage(RankingView.allTime, 1, 10),
      throwsA(isA<RankingApiException>()),
    );
    final broken = clientWith(
      (_) => const RankingHttpResponse(200, 'not json'),
    );
    await expectLater(
      broken.fetchPage(RankingView.allTime, 1, 10),
      throwsA(isA<RankingApiException>()),
    );
  });

  test('네트워크 오류는 statusCode 0 의 RankingApiException', () async {
    final client = RankingApiClient(
      'https://relay.example.test',
      httpGet: (_) async => throw const SocketException('가짜 연결 실패'),
    );
    await expectLater(
      client.fetchPage(RankingView.allTime, 1, 10),
      throwsA(
        isA<RankingApiException>().having((e) => e.statusCode, 'statusCode', 0),
      ),
    );
  });

  test('검색은 /api/search 에 q·limit 를 보내고 결과를 파싱합니다', () async {
    final log = <Uri>[];
    final client = clientWith(
      (_) => RankingHttpResponse(
        200,
        jsonEncode({'query': 'react', 'data': jsonDecode(_okBody)['data']}),
      ),
      log: log,
    );
    final result = await client.search('  react  ', limit: 30);
    expect(log.single.path, '/api/search');
    expect(log.single.queryParameters, {'q': 'react', 'limit': '30'});
    expect(result.query, 'react');
    expect(result.items.single.name, '가짜 스킬');
  });

  test('스타는 /api/stars 에 repos 를 쉼표로 묶어 보낸다', () async {
    final log = <Uri>[];
    final client = clientWith(
      (_) => RankingHttpResponse(
        200,
        jsonEncode({
          'stars': {'a/b': 12, 'c/d': null},
          'limited': true,
        }),
      ),
      log: log,
    );
    final result = await client.fetchStars(['a/b', 'c/d']);
    expect(log.single.path, '/api/stars');
    expect(log.single.queryParameters['repos'], 'a/b,c/d');
    expect(result.stars, {'a/b': 12, 'c/d': null});
    expect(result.limited, isTrue);
  });

  test('검색 실패는 본문의 error 문구를 쓴다', () async {
    final client = clientWith((_) => RankingHttpResponse(400, _errorBody));
    await expectLater(
      client.search('ab'),
      throwsA(
        isA<RankingApiException>().having((e) => e.message, 'message', '가짜 오류'),
      ),
    );
  });
}
