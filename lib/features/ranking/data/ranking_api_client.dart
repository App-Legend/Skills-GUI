import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../models/ranking_models.dart';

/// HTTP 응답 중 클라이언트가 쓰는 부분.
class RankingHttpResponse {
  const RankingHttpResponse(this.statusCode, this.body);

  final int statusCode;
  final String body;
}

typedef RankingHttpGet = Future<RankingHttpResponse> Function(Uri uri);

/// 랭킹 요청 실패. 네트워크 오류는 statusCode 0 이다.
class RankingApiException implements Exception {
  const RankingApiException(this.statusCode, this.message);

  final int statusCode;
  final String message;

  @override
  String toString() => 'RankingApiException($statusCode): $message';
}

/// 기본 HTTP 구현. dart:io HttpClient 를 쓴다.
Future<RankingHttpResponse> defaultRankingHttpGet(Uri uri) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
  try {
    final request = await client.getUrl(uri);
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    final response = await request.close().timeout(const Duration(seconds: 20));
    final body = await response.transform(utf8.decoder).join();
    return RankingHttpResponse(response.statusCode, body);
  } finally {
    client.close(force: true);
  }
}

class RankingApiClient {
  RankingApiClient(this.baseUrl, {RankingHttpGet? httpGet})
    : _httpGet = httpGet ?? defaultRankingHttpGet;

  final String baseUrl;
  final RankingHttpGet _httpGet;

  /// 한 번에 스타를 물을 수 있는 저장소 수 (중계 서버 한도와 같다).
  static const int maxStarsRepos = 60;

  Uri _endpoint(String name, Map<String, String> query) {
    final base = Uri.parse(baseUrl.trim());
    final basePath = base.path.endsWith('/')
        ? base.path.substring(0, base.path.length - 1)
        : base.path;
    return base.replace(path: '$basePath/api/$name', queryParameters: query);
  }

  Uri buildUri(RankingView view, int page, int perPage) => _endpoint(
    'ranking',
    {'view': view.apiValue, 'page': '$page', 'per_page': '$perPage'},
  );

  Uri buildSearchUri(String query, int limit) =>
      _endpoint('search', {'q': query, 'limit': '$limit'});

  Uri buildStarsUri(Iterable<String> repos) =>
      _endpoint('stars', {'repos': repos.join(',')});

  Future<RankingPage> fetchPage(RankingView view, int page, int perPage) =>
      _getJson(buildUri(view, page, perPage), RankingPage.fromJson);

  /// skills.sh 검색. 검색어는 2자 이상이어야 한다.
  Future<SearchResult> search(String query, {int limit = 100}) =>
      _getJson(buildSearchUri(query.trim(), limit), SearchResult.fromJson);

  /// GitHub 저장소(owner/repo) 스타 수. 최대 [maxStarsRepos] 개.
  Future<StarsResult> fetchStars(Iterable<String> repos) =>
      _getJson(buildStarsUri(repos), StarsResult.fromJson);

  Uri buildDetailUri(String id) => _endpoint('skill', {'id': id});

  Uri buildAuditUri(String id) => _endpoint('audit', {'id': id});

  /// 스킬 상세와 파일 내용. [id] 는 `source/slug`.
  Future<SkillDetail> fetchDetail(String id) =>
      _getJson(buildDetailUri(id), SkillDetail.fromJson);

  /// 보안 점검 결과. 점검 기록이 없으면(404) 빈 목록.
  Future<List<SkillAudit>> fetchAudits(String id) async {
    try {
      return await _getJson(buildAuditUri(id), SkillAudit.listFromJson);
    } on RankingApiException catch (e) {
      if (e.statusCode == 404) return const [];
      rethrow;
    }
  }

  Future<T> _getJson<T>(Uri uri, T Function(Object?) parse) async {
    final RankingHttpResponse response;
    try {
      response = await _httpGet(uri);
    } on RankingApiException {
      rethrow;
    } on TimeoutException {
      throw const RankingApiException(0, '응답이 너무 늦다. 잠시 뒤 다시 시도하면 된다.');
    } on IOException {
      // 예외 원문(SocketException…)은 길고 읽기 어려워 주소만 알려 준다.
      throw RankingApiException(
        0,
        '중계 서버(${uri.host}${uri.hasPort ? ':${uri.port}' : ''})에 연결하지 못했다. '
        '인터넷 연결이나 서버가 켜져 있는지 확인이 필요하다.',
      );
    }

    final status = response.statusCode;
    if (status == 200) {
      try {
        return parse(jsonDecode(response.body));
      } on FormatException catch (e) {
        throw RankingApiException(status, '응답 형식이 올바르지 않다: ${e.message}');
      }
    }
    throw RankingApiException(status, _messageFor(status, response.body));
  }

  String _messageFor(int status, String body) {
    if (status == 429) return '요청이 너무 많다. 잠시 뒤 다시 시도하면 된다.';
    if (status == 503) return '서비스를 잠시 쓸 수 없다. 잠시 뒤 다시 시도하면 된다.';
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['error'] is String) {
        return decoded['error'] as String;
      }
    } on FormatException {
      // 본문이 JSON 이 아니면 기본 문구를 쓴다.
    }
    return '랭킹을 불러오지 못했다 (상태 $status).';
  }
}
