import 'package:flutter_test/flutter_test.dart';
import 'package:skill_gui/features/ranking/models/ranking_models.dart';

// 테스트용 가짜 데이터. 실제 skills.sh 수치가 아니다.
Map<String, Object?> fakeItem({Object? installs = 1, Object? change}) => {
  'id': 'fake-id',
  'slug': 'fake-slug',
  'name': '가짜 스킬',
  'source': 'fake/source',
  'installs': installs,
  'sourceType': 'github',
  'installUrl': 'https://example.test/install',
  'url': 'https://example.test/skill',
  'change': ?change,
};

Map<String, Object?> fakePagination() => {
  'page': 1,
  'perPage': 2,
  'total': 5,
  'hasMore': true,
};

void main() {
  test('RankingView apiValue', () {
    expect(RankingView.allTime.apiValue, 'all-time');
    expect(RankingView.trending.apiValue, 'trending');
    expect(RankingView.hot.apiValue, 'hot');
  });

  test('정상 응답을 파싱합니다', () {
    final page = RankingPage.fromJson({
      'data': [fakeItem(change: -3), fakeItem()],
      'pagination': fakePagination(),
    });
    expect(page.items, hasLength(2));
    expect(page.items[0].name, '가짜 스킬');
    expect(page.items[0].change, -3);
    expect(page.items[1].change, isNull);
    expect(page.items[1].installsYesterday, isNull);
    expect(page.pagination.perPage, 2);
    expect(page.pagination.hasMore, isTrue);
  });

  test('installUrl 이 null 인 항목도 파싱합니다 (well-known 출처)', () {
    final item = SkillRankItem.fromJson({...fakeItem(), 'installUrl': null});
    expect(item.installUrl, isNull);
  });

  test('형식이 틀리면 FormatException', () {
    expect(() => RankingPage.fromJson('문자열'), throwsFormatException);
    expect(
      () => RankingPage.fromJson({'data': 1, 'pagination': fakePagination()}),
      throwsFormatException,
    );
    expect(
      () => RankingPage.fromJson({
        'data': [fakeItem(installs: '많음')],
        'pagination': fakePagination(),
      }),
      throwsFormatException,
    );
    expect(
      () => RankingPage.fromJson({'data': [], 'pagination': null}),
      throwsFormatException,
    );
    expect(
      () => RankingPage.fromJson({
        'data': [fakeItem(change: 'x')],
        'pagination': fakePagination(),
      }),
      throwsFormatException,
    );
  });
}
