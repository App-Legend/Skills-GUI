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
    final response =
        await request.close().timeout(const Duration(seconds: 20));
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

  Uri buildUri(RankingView view, int page, int perPage) {
    final base = Uri.parse(baseUrl.trim());
    final basePath = base.path.endsWith('/')
        ? base.path.substring(0, base.path.length - 1)
        : base.path;
    return base.replace(
      path: '$basePath/api/ranking',
      queryParameters: {
        'view': view.apiValue,
        'page': '$page',
        'per_page': '$perPage',
      },
    );
  }

  Future<RankingPage> fetchPage(RankingView view, int page, int perPage) async {
    final RankingHttpResponse response;
    try {
      response = await _httpGet(buildUri(view, page, perPage));
    } on RankingApiException {
      rethrow;
    } on TimeoutException {
      throw const RankingApiException(0, '응답이 너무 늦어요. 잠시 뒤 다시 시도해 주세요.');
    } on IOException catch (e) {
      throw RankingApiException(0, '서버에 연결하지 못했어요: $e');
    }

    final status = response.statusCode;
    if (status == 200) {
      try {
        return RankingPage.fromJson(jsonDecode(response.body));
      } on FormatException catch (e) {
        throw RankingApiException(status, '응답 형식이 올바르지 않아요: ${e.message}');
      }
    }
    throw RankingApiException(status, _messageFor(status, response.body));
  }

  String _messageFor(int status, String body) {
    if (status == 429) return '요청이 너무 많아요. 잠시 뒤 다시 시도해 주세요.';
    if (status == 503) return '서비스를 잠시 쓸 수 없어요. 잠시 뒤 다시 시도해 주세요.';
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['error'] is String) {
        return decoded['error'] as String;
      }
    } on FormatException {
      // 본문이 JSON 이 아니면 기본 문구를 쓴다.
    }
    return '랭킹을 불러오지 못했어요 (상태 $status).';
  }
}
