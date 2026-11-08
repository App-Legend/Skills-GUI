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
      throw const FormatException('hasMore 는 true/false 여야 해요.');
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
      throw const FormatException('data 는 목록이어야 해요.');
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
      throw const FormatException('data 는 목록이어야 해요.');
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

Map<String, Object?> _asMap(Object? json, String label) {
  if (json is! Map<String, Object?>) {
    throw FormatException('$label 형식이 올바르지 않아요.');
  }
  return json;
}

String _string(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value is! String) {
    throw FormatException('$key 는 문자열이어야 해요.');
  }
  return value;
}

int _int(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value is! int) {
    throw FormatException('$key 는 정수여야 해요.');
  }
  return value;
}

String? _optString(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value == null) return null;
  if (value is! String) {
    throw FormatException('$key 는 문자열이어야 해요.');
  }
  return value;
}

int? _optInt(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value == null) return null;
  if (value is! int) {
    throw FormatException('$key 는 정수여야 해요.');
  }
  return value;
}
