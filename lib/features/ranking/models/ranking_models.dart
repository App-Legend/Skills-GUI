/// 랭킹 보기 종류.
enum RankingView {
  allTime('all-time'),
  trending('trending'),
  hot('hot');

  const RankingView(this.apiValue);

  /// 중계 서버 `view` 쿼리에 쓰는 값.
  final String apiValue;
}

/// 랭킹 항목 하나.
class SkillRankItem {
  const SkillRankItem({
    required this.id,
    required this.slug,
    required this.name,
    required this.source,
    required this.installs,
    required this.sourceType,
    required this.installUrl,
    required this.url,
    this.installsYesterday,
    this.change,
  });

  final String id;
  final String slug;
  final String name;
  final String source;
  final int installs;
  final String sourceType;

  /// well-known 출처 스킬은 null 로 온다.
  final String? installUrl;
  final String url;
  final int? installsYesterday;
  final int? change;

  factory SkillRankItem.fromJson(Object? json) {
    final map = _asMap(json, '랭킹 항목');
    return SkillRankItem(
      id: _string(map, 'id'),
      slug: _string(map, 'slug'),
      name: _string(map, 'name'),
      source: _string(map, 'source'),
      installs: _int(map, 'installs'),
      sourceType: _string(map, 'sourceType'),
      installUrl: _optString(map, 'installUrl'),
      url: _string(map, 'url'),
      installsYesterday: _optInt(map, 'installsYesterday'),
      change: _optInt(map, 'change'),
    );
  }
}

/// 페이지 정보.
class RankingPagination {
  const RankingPagination({
    required this.page,
    required this.perPage,
    required this.total,
    required this.hasMore,
  });

  final int page;
  final int perPage;
  final int total;
  final bool hasMore;

  factory RankingPagination.fromJson(Object? json) {
    final map = _asMap(json, 'pagination');
    final hasMore = map['hasMore'];
    if (hasMore is! bool) {
      throw const FormatException('hasMore 는 true/false 여야 합니다.');
    }
    return RankingPagination(
      page: _int(map, 'page'),
      perPage: _int(map, 'perPage'),
      total: _int(map, 'total'),
      hasMore: hasMore,
    );
  }
}

/// 한 페이지 분량의 응답.
class RankingPage {
  const RankingPage({required this.items, required this.pagination});

  final List<SkillRankItem> items;
  final RankingPagination pagination;

  factory RankingPage.fromJson(Object? json) {
    final map = _asMap(json, '응답');
    final data = map['data'];
    if (data is! List) {
      throw const FormatException('data 는 목록이어야 합니다.');
    }
    return RankingPage(
      items: data.map(SkillRankItem.fromJson).toList(growable: false),
      pagination: RankingPagination.fromJson(map['pagination']),
    );
  }
}

/// 검색 응답. skills.sh 검색은 페이지 없이 최대 limit 개를 돌려준다.
class SearchResult {
  const SearchResult({required this.query, required this.items});

  final String query;
  final List<SkillRankItem> items;

  factory SearchResult.fromJson(Object? json) {
    final map = _asMap(json, '검색 응답');
    final data = map['data'];
    if (data is! List) {
      throw const FormatException('data 는 목록이어야 합니다.');
    }
    final query = map['query'];
    return SearchResult(
      query: query is String ? query : '',
      items: data.map(SkillRankItem.fromJson).toList(growable: false),
    );
  }
}

/// 스타 응답. 값이 null 이면 그 저장소는 조회하지 못한 것이다.
class StarsResult {
  const StarsResult({required this.stars, required this.limited});

  final Map<String, int?> stars;

  /// GitHub 요청 한도에 걸려 일부를 못 가져왔으면 true.
  final bool limited;

  factory StarsResult.fromJson(Object? json) {
    final map = _asMap(json, '스타 응답');
    final raw = _asMap(map['stars'], 'stars');
    return StarsResult(
      stars: {
        for (final entry in raw.entries)
          entry.key: entry.value is int ? entry.value as int : null,
      },
      limited: map['limited'] == true,
    );
  }
}

/// 스킬에 든 파일 하나. [contents] 가 null 이면 skills.sh 가 내용을 주지 않은 파일(그림 등)이다.
class SkillFile {
  const SkillFile({required this.path, required this.contents});

  final String path;
  final String? contents;

  factory SkillFile.fromJson(Object? json) {
    final map = _asMap(json, '파일');
    return SkillFile(
      path: _string(map, 'path'),
      contents: _optString(map, 'contents'),
    );
  }
}

/// 스킬 상세. skills.sh `/api/v1/skills/{source}/{slug}` 응답.
class SkillDetail {
  const SkillDetail({
    required this.id,
    required this.source,
    required this.slug,
    required this.installs,
    required this.files,
    this.hash,
  });

  final String id;
  final String source;
  final String slug;
  final int installs;
  final List<SkillFile> files;

  /// skills.sh가 주는 스킬 내용 해시. 내용이 바뀌면 달라진다. 없으면 null.
  final String? hash;

  /// SKILL.md 본문. 없으면 null.
  String? get skillMd {
    for (final file in files) {
      if (file.path.toLowerCase() == 'skill.md') return file.contents;
    }
    return null;
  }

  factory SkillDetail.fromJson(Object? json) {
    final map = _asMap(json, '상세 응답');
    final files = map['files'];
    return SkillDetail(
      id: _string(map, 'id'),
      source: _string(map, 'source'),
      slug: _string(map, 'slug'),
      installs: _int(map, 'installs'),
      hash: _optString(map, 'hash'),
      files: files is List
          ? files.map(SkillFile.fromJson).toList(growable: false)
          : const [],
    );
  }
}

/// 보안 점검 결과 하나.
class SkillAudit {
  const SkillAudit({
    required this.provider,
    required this.status,
    required this.summary,
    this.riskLevel,
  });

  final String provider;

  /// pass / warn / fail 등. skills.sh 가 준 값을 그대로 쓴다.
  final String status;
  final String summary;
  final String? riskLevel;

  bool get passed => status.toLowerCase() == 'pass';

  factory SkillAudit.fromJson(Object? json) {
    final map = _asMap(json, '점검 결과');
    final summary = map['summary'];
    return SkillAudit(
      provider: _string(map, 'provider'),
      status: _string(map, 'status'),
      summary: summary is String ? summary : '',
      riskLevel: _optString(map, 'riskLevel'),
    );
  }

  static List<SkillAudit> listFromJson(Object? json) {
    final audits = _asMap(json, '점검 응답')['audits'];
    if (audits is! List) throw const FormatException('audits 는 목록이어야 합니다.');
    return audits.map(SkillAudit.fromJson).toList(growable: false);
  }
}

Map<String, Object?> _asMap(Object? json, String label) {
  if (json is! Map<String, Object?>) {
    throw FormatException('$label 형식이 올바르지 않습니다.');
  }
  return json;
}

String _string(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value is! String) {
    throw FormatException('$key 는 문자열이어야 합니다.');
  }
  return value;
}

int _int(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value is! int) {
    throw FormatException('$key 는 정수여야 합니다.');
  }
  return value;
}

String? _optString(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value == null) return null;
  if (value is! String) {
    throw FormatException('$key 는 문자열이어야 합니다.');
  }
  return value;
}

int? _optInt(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value == null) return null;
  if (value is! int) {
    throw FormatException('$key 는 정수여야 합니다.');
  }
  return value;
}
