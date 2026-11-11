import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skill_gui/features/ranking/widgets/ranking_list_tile.dart';
import 'package:skill_gui/features/ranking/widgets/ranking_state_view.dart';

// 테스트용 가짜 데이터: 아래 이름·수치는 모두 동작 확인용 임의 값이다.
Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

Color? _changeColor(WidgetTester tester) => tester
    .widget<Text>(find.byKey(const Key('ranking-tile-change')))
    .style
    ?.color;

void main() {
  group('RankingListTile', () {
    testWidgets('순위·이름·짧은 개요·installs 를 보여 주고 source 는 숨긴다', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const RankingListTile(
            rank: 3,
            name: 'fake-skill',
            source: 'fake/source',
            installs: 1234,
            summary: '가짜 짧은 개요',
          ),
        ),
      );

      expect(find.text('3'), findsOneWidget);
      expect(find.text('fake-skill'), findsOneWidget);
      expect(find.text('가짜 짧은 개요'), findsOneWidget);
      expect(
        tester
            .widget<Text>(find.byKey(const Key('ranking-tile-summary')))
            .maxLines,
        1,
      );
      expect(find.text('fake/source'), findsNothing);
      expect(find.text('설치 1,234'), findsOneWidget);
      expect(find.byKey(const Key('ranking-tile-change')), findsNothing);
      expect(find.byKey(const Key('ranking-tile-installed')), findsNothing);
    });

    testWidgets('stars 가 있으면 ★ 스타 수를, 없으면 아무것도 보이지 않습니다', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const RankingListTile(
            rank: 1,
            name: 'a',
            source: 's',
            installs: 1,
            stars: 318029,
          ),
        ),
      );
      expect(find.text('★ 318,029'), findsOneWidget);

      await tester.pumpWidget(
        _wrap(
          const RankingListTile(rank: 1, name: 'a', source: 's', installs: 1),
        ),
      );
      expect(find.byKey(const Key('ranking-tile-stars')), findsNothing);
    });

    testWidgets('category 가 있으면 카테고리 배지를 붙입니다', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const RankingListTile(
            rank: 1,
            name: 'a',
            source: 's',
            installs: 1,
            category: '백엔드',
          ),
        ),
      );
      expect(find.byKey(const Key('ranking-tile-category')), findsOneWidget);
      expect(find.text('백엔드'), findsOneWidget);
      // 오른쪽 설치 수 바로 왼쪽, 같은 줄에 있다.
      final badge = tester.getRect(find.text('백엔드'));
      final installs = tester.getRect(find.text('설치 1'));
      expect(badge.center.dy, closeTo(installs.center.dy, 4));
      expect(badge.right, lessThan(installs.left));
      final name = tester.getRect(find.text('a'));
      expect(badge.left, greaterThan(name.right));
      // 이름과 같은 줄에 있다.
      expect(badge.center.dy, closeTo(name.center.dy, 4));
    });

    testWidgets('installed 면 맨 오른쪽에 설치됨 체크를 붙입니다', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const RankingListTile(
            rank: 1,
            name: 'fake-skill',
            source: 'fake/source',
            installs: 1,
            installed: true,
          ),
        ),
      );
      expect(find.byKey(const Key('ranking-tile-installed')), findsOneWidget);
      expect(find.byTooltip('설치됨'), findsOneWidget);
      // 체크가 숫자보다 오른쪽에 있다.
      final check = tester.getCenter(
        find.byKey(const Key('ranking-tile-installed')),
      );
      final installs = tester.getCenter(
        find.byKey(const Key('ranking-tile-installs')),
      );
      expect(check.dx, greaterThan(installs.dx));
    });

    testWidgets('카테고리는 이름 바로 옆, 설치 수·스타 수는 오른쪽 끝을 맞춘다', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const RankingListTile(
            rank: 1,
            name: 'fake-skill',
            source: 'fake/source',
            installs: 1234567,
            stars: 12,
            category: '백엔드',
          ),
        ),
      );
      final name = tester.getRect(find.byKey(const Key('ranking-tile-name')));
      final badge = tester.getRect(
        find.byKey(const Key('ranking-tile-category')),
      );
      expect(badge.left - name.right, lessThan(16));
      final installs = tester.getRect(
        find.byKey(const Key('ranking-tile-installs')),
      );
      final stars = tester.getRect(find.byKey(const Key('ranking-tile-stars')));
      expect((installs.right - stars.right).abs(), lessThan(1));
    });

    testWidgets('showChange 가 false 면 change 가 있어도 숨긴다', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const RankingListTile(
            rank: 1,
            name: 'a',
            source: 'b',
            installs: 1,
            change: 5,
          ),
        ),
      );
      expect(find.byKey(const Key('ranking-tile-change')), findsNothing);
    });

    testWidgets('change 양수·음수·없음 표시가 다르다', (tester) async {
      Future<void> pump(int? change) => tester.pumpWidget(
        _wrap(
          RankingListTile(
            rank: 1,
            name: 'a',
            source: 'b',
            installs: 1,
            change: change,
            showChange: true,
          ),
        ),
      );

      await pump(12);
      expect(find.text('+12'), findsOneWidget);
      final positive = _changeColor(tester);

      await pump(-7);
      expect(find.text('−7'), findsOneWidget);
      final negative = _changeColor(tester);

      await pump(null);
      expect(find.text('-'), findsOneWidget);
      final none = _changeColor(tester);

      expect(positive, isNot(negative));
      expect(none, isNot(positive));
      expect(none, isNot(negative));
    });

    test('formatCount 는 천 단위 쉼표를 넣는다', () {
      expect(RankingListTile.formatCount(0), '0');
      expect(RankingListTile.formatCount(999), '999');
      expect(RankingListTile.formatCount(1000), '1,000');
      expect(RankingListTile.formatCount(1234567), '1,234,567');
    });
  });

  group('RankingStateView', () {
    testWidgets('로딩 상태', (tester) async {
      await tester.pumpWidget(_wrap(const RankingStateView.loading()));
      expect(find.byKey(const Key('ranking-state-loading')), findsOneWidget);
      expect(find.byKey(const Key('ranking-state-error')), findsNothing);
      expect(find.byKey(const Key('ranking-state-empty')), findsNothing);
    });

    testWidgets('오류 상태는 메시지를 숨기지 않고 보여 준다', (tester) async {
      var retried = 0;
      await tester.pumpWidget(
        _wrap(
          RankingStateView.error(
            message: '테스트용 오류 메시지',
            onRetry: () => retried++,
          ),
        ),
      );
      expect(find.byKey(const Key('ranking-state-error')), findsOneWidget);
      expect(find.text('테스트용 오류 메시지'), findsOneWidget);

      await tester.tap(find.byKey(const Key('ranking-state-retry')));
      expect(retried, 1);
    });

    testWidgets('onRetry 가 없으면 다시 시도 버튼이 없습니다', (tester) async {
      await tester.pumpWidget(
        _wrap(const RankingStateView.error(message: '오류')),
      );
      expect(find.byKey(const Key('ranking-state-retry')), findsNothing);
    });

    testWidgets('빈 상태', (tester) async {
      await tester.pumpWidget(_wrap(const RankingStateView.empty()));
      expect(find.byKey(const Key('ranking-state-empty')), findsOneWidget);
      expect(find.text('표시할 스킬이 없습니다'), findsOneWidget);
      expect(find.byKey(const Key('ranking-state-loading')), findsNothing);
    });
  });
}
