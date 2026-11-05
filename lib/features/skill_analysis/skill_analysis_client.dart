import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../scan/skill.dart';
import 'skill_analysis.dart';

class SkillAnalysisApiException implements Exception {
  const SkillAnalysisApiException(this.message);
  final String message;
  @override
  String toString() => 'SkillAnalysisApiException($message)';
}

class SkillAnalysisHttpResponse {
  const SkillAnalysisHttpResponse(this.statusCode, this.body);
  final int statusCode;
  final String body;
}

typedef SkillAnalysisHttpPost = Future<SkillAnalysisHttpResponse> Function(
  Uri uri,
  Map<String, dynamic> body,
);

Future<SkillAnalysisHttpResponse> defaultSkillAnalysisHttpPost(
  Uri uri,
  Map<String, dynamic> body,
) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
  try {
    final request = await client.postUrl(uri);
    request.headers.contentType = ContentType.json;
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    request.write(jsonEncode(body));
    final response = await request.close().timeout(const Duration(seconds: 45));
    return SkillAnalysisHttpResponse(
      response.statusCode,
      await response.transform(utf8.decoder).join(),
    );
  } finally {
    client.close(force: true);
  }
}

class SkillAnalysisApiClient {
  SkillAnalysisApiClient(this.baseUrl, {SkillAnalysisHttpPost? httpPost})
    : _httpPost = httpPost ?? defaultSkillAnalysisHttpPost;
  final String baseUrl;
  final SkillAnalysisHttpPost _httpPost;

  Uri get uri {
    final base = Uri.parse(baseUrl.trim());
    final path = base.path.endsWith('/')
        ? base.path.substring(0, base.path.length - 1)
        : base.path;
    return base.replace(path: '$path/api/skill-analysis');
  }

  Future<SkillAnalysis> analyze(Skill skill) async {
    final skillMd = skill.skillMd;
    if (skillMd == null || skillMd.trim().isEmpty) {
      throw const SkillAnalysisApiException('분석할 SKILL.md 내용이 없습니다.');
    }
    final response = await _request({
      'name': skill.name,
      'description': skill.description,
      'skill_md': skillMd,
      'files': skill.files,
    });
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map || decoded['analysis'] is! Map) {
        throw const FormatException();
      }
      final analysis = SkillAnalysis.fromJson(
        Map<String, dynamic>.from(decoded['analysis'] as Map),
      );
      if (analysis.overview.isEmpty) {
        throw const FormatException();
      }
      return analysis;
    } on FormatException {
      throw const SkillAnalysisApiException('분석 결과 형식을 읽지 못했습니다.');
    }
  }

  Future<SkillAnalysisHttpResponse> _request(Map<String, dynamic> body) async {
    try {
      final response = await _httpPost(uri, body);
      if (response.statusCode == 200) {
        return response;
      }
      throw SkillAnalysisApiException(_messageFor(response));
    } on SkillAnalysisApiException {
      rethrow;
    } on TimeoutException {
      throw const SkillAnalysisApiException(
        '분석 응답이 늦어지고 있습니다. 잠시 후 다시 열어 주세요.',
      );
    } on IOException {
      throw const SkillAnalysisApiException('분석 서버에 연결하지 못했습니다.');
    }
  }

  String _messageFor(SkillAnalysisHttpResponse response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map && decoded['error'] is String) {
        return decoded['error'] as String;
      }
    } on FormatException {
      // JSON 오류 본문이 아니면 상태별 기본 문구를 쓴다.
    }
    return response.statusCode == 429
        ? '분석 요청이 많습니다. 잠시 후 다시 열어 주세요.'
        : '한국어 분석을 만들지 못했습니다.';
  }
}
