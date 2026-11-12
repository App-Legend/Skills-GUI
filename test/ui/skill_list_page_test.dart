import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skill_gui/features/skill_analysis/skill_analysis.dart';
import 'package:skill_gui/features/skill_analysis/skill_analysis_cache.dart';
import 'package:skill_gui/features/skill_analysis/skill_analysis_client.dart';
import 'package:skill_gui/features/skill_analysis/skill_analysis_store.dart';
import 'package:skill_gui/features/scan/agent.dart';
import 'package:skill_gui/features/scan/skill.dart';
import 'package:skill_gui/features/usage/skill_usage.dart';
import 'package:skill_gui/ui/app_checkbox.dart';
import 'package:skill_gui/ui/glass.dart';
import 'package:skill_gui/ui/skill_list_page.dart';

const _skills = [
  Skill(name: 'a', description: 'da', source: SkillSource.global, path: '/a'),
  Skill(
    name: 'b',
    description: 'db',
    source: SkillSource.plugin,
    plugin: 'p@m',
    pluginEnabled: true,
    projectPath: '/w/app',
    path: '/b',
  ),
  Skill(
    name: 'c',
    source: SkillSource.global,
    path: '/c',
    problem: SkillProblem(ProblemKind.noPermission, '읽을 수 없음, 권한 없음'),
  ),
  Skill(
    name: 'd',
    description: 'dd',
    source: SkillSource.plugin,
    plugin: 'q@m',
    pluginEnabled: false,
    path: '/d',
  ),
  Skill(name: 'e', source: SkillSource.synced, path: '/e'),
];

Future<void> _pump(
  WidgetTester t, {
  List<String> notices = const [],
  Future<void> Function()? onRescan,
  bool reduce = false,
  List<Skill> skills = _skills,
  SkillUsage? usage,
}) async {
  t.view.physicalSize = const Size(1280, 820);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  Widget page = MaterialApp(
    home: SkillListPage(
      result: ScanResult(skills: skills, notices: notices),
      onRescan: onRescan ?? () async {},
      onOpen: (_) {},
      usage: usage,
    ),
  );
  if (reduce) page = ReduceTransparency(value: true, child: page);
  await t.pumpWidget(page);
}

void main() {
  testWidgets('카드와 태그', (t) async {
    await _pump(t);
    for (final n in ['a', 'b', 'c', 'd', 'e']) {
      expect(find.text(n), findsOneWidget);
    }
    expect(find.text('내 스킬'), findsOneWidget);
    expect(find.text('/w/app'), findsOneWidget);
    expect(find.text('읽을 수 없음, 권한 없음'), findsOneWidget);
    expect(find.text('전역'), findsNWidgets(3)); // 필터 + 카드 a, c
    expect(find.text('p@m'), findsOneWidget);
    expect(find.text('동기화'), findsOneWidget);
  });

  testWidgets('필터', (t) async {
    await _pump(t);
    await t.tap(find.widgetWithText(InkWell, '플러그인'));
    await t.pump();
    expect(find.text('b'), findsOneWidget);
    expect(find.text('d'), findsOneWidget);
    expect(find.text('a'), findsNothing);
    await t.tap(find.text('꺼짐').first);
    await t.pump();
    expect(find.text('b'), findsNothing);
    expect(find.text('d'), findsOneWidget);
    expect(find.text('꺼짐'), findsNWidgets(2)); // 필터 + 배지
  });

  testWidgets('미사용 후보: 30일 안에 쓴 스킬은 빠지고 확인 기간을 알려 줍니다', (t) async {
    await _pump(
      t,
      usage: SkillUsage(
        since: {Agent.claude: DateTime(2026, 9, 30)},
        lastUsed: {
          Agent.claude: {'a': DateTime.now()},
        },
      ),
    );
    await t.tap(find.text('미사용 후보'));
    await t.pump();
    expect(find.text('a'), findsNothing);
    expect(find.text('b'), findsOneWidget);
    expect(find.textContaining('Claude Code 2026-09-30부터'), findsOneWidget);
  });

  testWidgets('미사용 후보: 기록을 읽는 중이면 비워 두고 알려 줍니다', (t) async {
    await _pump(t);
    await t.tap(find.text('미사용 후보'));
    await t.pump();
    expect(find.text('사용 기록을 읽는 중입니다'), findsOneWidget);
    expect(find.text('a'), findsNothing);
  });

  testWidgets('다시 스캔과 notices', (t) async {
    var n = 0;
    await _pump(t, notices: ['안내 문구'], onRescan: () async => n++);
    expect(find.text('안내 문구'), findsOneWidget);
    await t.tap(find.text('다시 스캔'));
    expect(n, 1);
  });

  testWidgets('투명도 줄이기', (t) async {
    await _pump(t);
    expect(find.byType(BackdropFilter), findsWidgets);
    await _pump(t, reduce: true);
    expect(find.byType(BackdropFilter), findsNothing);
  });

  testWidgets('긴 이름과 긴 플러그인 id는 넘치지 않습니다', (t) async {
    t.view.physicalSize = const Size(1280, 820);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        home: SkillListPage(
          result: ScanResult(
            skills: [
              Skill(
                name: 'n' * 80,
                description: 'd',
                source: SkillSource.plugin,
                plugin: '${'p' * 30}@${'m' * 29}',
                pluginEnabled: false,
                path: '/x',
              ),
            ],
          ),
          onRescan: () async {},
          onOpen: (_) {},
        ),
      ),
    );
    expect(t.takeException(), isNull);
    expect(find.text('꺼짐'), findsNWidgets(2));
  });

  testWidgets('에이전트 필터: 그 에이전트가 읽는 스킬만 보입니다', (t) async {
    await _pump(t);
    await t.tap(find.text('Codex'));
    await t.pump();
    // 테스트 스킬은 모두 Claude Code 것이라 Codex에는 없다.
    expect(find.text('해당하는 스킬이 없습니다'), findsOneWidget);
    expect(find.text('a'), findsNothing);
    await t.tap(find.text('Claude Code'));
    await t.pump();
    expect(find.text('a'), findsOneWidget);
  });

  testWidgets('선택된 필터가 접근성에 알려집니다', (t) async {
    await _pump(t);
    final h = t.ensureSemantics();
    Matcher node(String label, bool selected) => matchesSemantics(
      label: label,
      isButton: true,
      isSelected: selected,
      hasSelectedState: true,
      hasTapAction: true,
      hasFocusAction: true,
      isFocusable: true,
    );
    expect(t.getSemantics(find.bySemanticsLabel('플러그인')), node('플러그인', false));
    expect(
      t.getSemantics(find.bySemanticsLabel('Codex')),
      node('Codex', false),
    );
    await t.tap(find.text('플러그인'));
    await t.pump();
    expect(t.getSemantics(find.bySemanticsLabel('플러그인')), node('플러그인', true));
    h.dispose();
  });

  testWidgets('플러그인 카드 태그에 버전', (t) async {
    await _pump(
      t,
      skills: const [
        Skill(
          name: 'v',
          source: SkillSource.plugin,
          plugin: 'p@m',
          pluginVersion: '1.0.0',
          path: '/v',
        ),
      ],
    );
    expect(find.text('p@m 1.0.0'), findsOneWidget);
  });

  testWidgets('빈 상태 문구', (t) async {
    await _pump(
      t,
      skills: const [Skill(name: 'a', source: SkillSource.global, path: '/a')],
    );
    await t.tap(find.text('꺼짐'));
    await t.pump();
    expect(find.text('해당하는 스킬이 없습니다'), findsOneWidget);
    await _pump(t, skills: const []);
    await t.pump();
    expect(find.text('스킬을 찾지 못했습니다'), findsOneWidget);
  });

  testWidgets('한국어 요약과 카테고리, 카테고리 필터', (t) async {
    final store = SkillAnalysisStore(
      client: SkillAnalysisApiClient(
        'https://relay.example.test',
        httpPost: (_, _) async => throw StateError('캐시만 써야 합니다'),
      ),
      cache: _MapCache({
        '/x': const SkillAnalysis(
          overview: '긴 개요',
          summary: '배포를 돕는 스킬',
          categories: ['devops', 'security'],
        ),
        '/y': const SkillAnalysis(overview: '테스트 개요', categories: ['testing']),
      }),
    );
    addTearDown(store.dispose);
    t.view.physicalSize = const Size(1280, 820);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        home: SkillListPage(
          result: const ScanResult(
            skills: [
              Skill(
                name: 'x',
                description: 'en x',
                source: SkillSource.global,
                path: '/x',
                skillMd: 'x',
              ),
              Skill(
                name: 'y',
                description: 'en y',
                source: SkillSource.global,
                path: '/y',
                skillMd: 'y',
              ),
            ],
          ),
          onRescan: () async {},
          onOpen: (_) {},
          analysisStore: store,
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('배포를 돕는 스킬'), findsOneWidget);
    expect(find.text('테스트 개요'), findsOneWidget);
    expect(find.text('en x'), findsNothing);
    expect(find.text('DevOps'), findsOneWidget);
    expect(find.text('보안'), findsOneWidget);

    await t.tap(find.byIcon(Icons.filter_list));
    await t.pump();
    expect(find.byType(AppCheckbox), findsNWidgets(61));
    await t.tap(find.bySemanticsLabel('테스트'));
    await t.pump();
    expect(find.text('x'), findsNothing);
    expect(find.text('y'), findsOneWidget);
    await t.tap(find.text('선택 해제'));
    await t.pump();
    expect(find.text('x'), findsOneWidget);
  });
}

class _MapCache implements SkillAnalysisCache {
  _MapCache(this.values);
  final Map<String, SkillAnalysis> values;

  @override
  Future<SkillAnalysis?> load(Skill skill) async => values[skill.path];

  @override
  Future<void> save(Skill skill, SkillAnalysis analysis) async {}
}
