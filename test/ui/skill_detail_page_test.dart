import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skill_gui/features/skill_analysis/skill_analysis.dart';
import 'package:skill_gui/features/skill_analysis/skill_analysis_cache.dart';
import 'package:skill_gui/features/skill_analysis/skill_analysis_client.dart';
import 'package:skill_gui/features/skill_analysis/skill_origin.dart';
import 'package:skill_gui/features/skill_delete/skill_deleter.dart';
import 'package:skill_gui/scan/skill.dart';
import 'package:skill_gui/ui/glass.dart';
import 'package:skill_gui/ui/skill_detail_page.dart';

class _MemoryCache implements SkillAnalysisCache {
  SkillAnalysis? value;

  @override
  Future<SkillAnalysis?> load(Skill skill) async => value;

  @override
  Future<void> save(Skill skill, SkillAnalysis analysis) async {
    value = analysis;
  }
}

Future<void> _pump(WidgetTester t, Skill s) async {
  t.view.physicalSize = const Size(1200, 900);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    MaterialApp(
      home: SkillDetailPage(
        skill: s,
        analysisCache: _readyCache(),
        resolveOrigin: _origin,
      ),
    ),
  );
}

Future<SkillOrigin> _origin(Skill _) async => const SkillOrigin(
  githubUrl: 'https://github.com/o/r',
  commands: ['/plugin marketplace add o/r', '/plugin install p@m'],
);

SkillAnalysisCache _readyCache() =>
    _MemoryCache()..value = const SkillAnalysis(overview: '캐시된 분석입니다.');

void main() {
  const full = Skill(
    name: 'alpha',
    description: '알파 설명',
    source: SkillSource.global,
    path: '/home/.claude/skills/alpha',
    skillMd: '# 원문 본문',
    files: ['SKILL.md', 'a.txt'],
  );

  testWidgets('기본 정보 표시', (t) async {
    await _pump(t, full);
    for (final x in ['alpha', '전역', '/home/.claude/skills/alpha']) {
      expect(find.text(x), findsWidgets, reason: x);
    }
    // 포함된 파일 목록은 너무 길어 보여 주지 않는다.
    expect(find.text('포함된 파일'), findsNothing);
    expect(find.text('a.txt'), findsNothing);
  });

  const denied = Skill(
    name: 'c',
    source: SkillSource.global,
    path: '/home/.claude/skills/c',
    linkTarget: '/x/y/c',
    problem: SkillProblem(ProblemKind.noPermission, '읽을 수 없음, 권한 없음'),
  );

  testWidgets('원문 대신 문제 메시지', (t) async {
    await _pump(t, denied);
    expect(find.text('읽을 수 없음, 권한 없음'), findsOneWidget);
    expect(find.text('한국어 분석'), findsNothing);
  });

  testWidgets('꺼진 프로젝트 플러그인 스킬', (t) async {
    await _pump(
      t,
      const Skill(
        name: 'd',
        source: SkillSource.plugin,
        plugin: 'p@m',
        pluginEnabled: false,
        projectPath: '/w/app',
        path: '/d',
        skillMd: 'x',
      ),
    );
    expect(find.text('꺼짐'), findsOneWidget);
    expect(find.text('/w/app'), findsOneWidget);
  });

  testWidgets('뒤로 가기', (t) async {
    await t.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (c) => TextButton(
            onPressed: () => Navigator.push(
              c,
              MaterialPageRoute(
                builder: (_) =>
                    SkillDetailPage(skill: full, analysisCache: _readyCache()),
              ),
            ),
            child: const Text('go'),
          ),
        ),
      ),
    );
    await t.tap(find.text('go'));
    await t.pumpAndSettle();
    await t.tap(find.text('내 스킬'));
    await t.pumpAndSettle();
    expect(find.text('go'), findsOneWidget);
  });

  testWidgets('뒤로 버튼에 화살표, Esc로도 뒤로', (t) async {
    await t.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (c) => TextButton(
            onPressed: () => Navigator.push(
              c,
              MaterialPageRoute(
                builder: (_) =>
                    SkillDetailPage(skill: full, analysisCache: _readyCache()),
              ),
            ),
            child: const Text('go'),
          ),
        ),
      ),
    );
    await t.tap(find.text('go'));
    await t.pumpAndSettle();
    expect(find.byIcon(Icons.chevron_left), findsOneWidget);
    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    await t.pumpAndSettle();
    expect(find.text('go'), findsOneWidget);
  });

  testWidgets('버전과 실제 경로 행', (t) async {
    await _pump(
      t,
      const Skill(
        name: 'v',
        source: SkillSource.plugin,
        plugin: 'p@m',
        pluginVersion: '1.2.3',
        path: '/a/v',
        linkTarget: '/real/v',
      ),
    );
    for (final x in ['버전 1.2.3', '실제 경로: /real/v', '/a/v']) {
      expect(find.text(x), findsOneWidget, reason: x);
    }
  });

  testWidgets('상세 진입 시 한국어 분석을 표시한다', (t) async {
    final client = SkillAnalysisApiClient(
      'https://relay.example.test',
      httpPost: (_, _) async => const SkillAnalysisHttpResponse(
        200,
        '{"analysis":{"overview":"풀 리퀘스트 검토를 돕는 스킬입니다.","whenToUse":["변경 사항을 검토할 때"],"outputs":["검토 결과"]}}',
      ),
    );
    await t.pumpWidget(
      MaterialApp(
        home: SkillDetailPage(
          skill: full,
          analysisClient: client,
          analysisCache: _MemoryCache(),
        ),
      ),
    );
    await t.pumpAndSettle();

    expect(find.text('한국어 분석'), findsNothing);
    expect(find.text('알파 설명'), findsNothing);
    expect(find.text('개요'), findsOneWidget);
    expect(find.text('풀 리퀘스트 검토를 돕는 스킬입니다.'), findsOneWidget);
    expect(find.text('이럴 때 사용'), findsOneWidget);
    expect(find.text('결과물'), findsOneWidget);
    expect(find.text('필요한 입력·준비'), findsNothing);
  });

  testWidgets('설치방법 복사, 원문 보기 버튼, 원문 섹션 없음', (t) async {
    await _pump(t, full);
    await t.pump();
    expect(find.text('설치방법'), findsOneWidget);
    expect(find.text('/plugin install p@m'), findsOneWidget);
    expect(find.byIcon(Icons.copy), findsNWidgets(2));
    expect(find.text('GitHub로 가기'), findsOneWidget);
    expect(find.text('SKILL.md 원문'), findsNothing);
    IgnorePointer gate() => t.widget<IgnorePointer>(
      find
          .ancestor(
            of: find.text('GitHub로 가기'),
            matching: find.byType(IgnorePointer),
          )
          .first,
    );
    expect(gate().ignoring, isFalse);
    // 이름과 같은 줄에 있다.
    expect(
      t.getCenter(find.text('GitHub로 가기')).dy,
      closeTo(t.getCenter(find.text('alpha')).dy, 12),
    );
    // 맨 오른쪽 버튼(삭제)의 오른쪽 여백이 이름의 왼쪽 여백과 같다.
    final panel = t.getRect(find.byType(GlassPanel).last);
    final name = t.getRect(find.text('alpha'));
    Rect chip(String label) => t.getRect(
      find.ancestor(of: find.text(label), matching: find.byType(GlassTap)),
    );
    final button = chip('삭제');
    expect(chip('GitHub로 가기').right, lessThan(button.left));
    expect(panel.right - button.right, closeTo(name.left - panel.left, 1));
  });

  testWidgets('GitHub 주소를 모르면 원문 보기 비활성', (t) async {
    t.view.physicalSize = const Size(1200, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        home: SkillDetailPage(
          skill: full,
          analysisCache: _readyCache(),
          resolveOrigin: (_) async => const SkillOrigin(),
        ),
      ),
    );
    await t.pump();
    expect(find.text('GitHub 주소를 찾지 못했다'), findsOneWidget);
    final gate = t.widget<IgnorePointer>(
      find
          .ancestor(
            of: find.text('GitHub로 가기'),
            matching: find.byType(IgnorePointer),
          )
          .first,
    );
    expect(gate.ignoring, isTrue);
    expect(find.text('설치방법'), findsNothing);
  });

  testWidgets('포함된 구성·주의할 점은 접혀 있고 특이사항은 숨긴다', (t) async {
    t.view.physicalSize = const Size(1200, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        home: SkillDetailPage(
          skill: full,
          analysisCache: _MemoryCache()
            ..value = const SkillAnalysis(
              overview: '개요 본문',
              categories: ['git'],
              requirements: ['준비 본문'],
              contents: [SkillAnalysisContent(path: 'a.txt', role: '구성 본문')],
              cautions: ['주의 본문'],
              additionalSections: [
                SkillAnalysisSection(title: '특이사항', content: '특이 본문'),
              ],
            ),
          resolveOrigin: _origin,
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('Git'), findsOneWidget);
    expect(find.text('필요한 입력·준비'), findsNothing);
    expect(find.text('특이사항'), findsNothing);
    expect(find.text('a.txt: 구성 본문'), findsNothing);
    expect(find.text('주의 본문'), findsNothing);
    await t.tap(find.text('포함된 구성'));
    await t.tap(find.text('주의할 점'));
    await t.pump();
    expect(find.text('a.txt: 구성 본문'), findsOneWidget);
    expect(find.text('주의 본문'), findsOneWidget);
  });
  testWidgets('삭제: 경로 확인 후 지우고 다시 스캔', (t) async {
    t.view.physicalSize = const Size(1200, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    SkillDeletePlan? deleted;
    var rescans = 0;
    await t.pumpWidget(
      MaterialApp(
        home: SkillDetailPage(
          skill: full,
          analysisCache: _readyCache(),
          resolveOrigin: _origin,
          deleter: (p) async => deleted = p,
          onDeleted: () async => rescans++,
        ),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.text('삭제'));
    await t.pumpAndSettle();
    expect(find.text('alpha 삭제'), findsOneWidget);
    expect(find.text('/home/.claude/skills/alpha'), findsWidgets);
    await t.tap(find.text('취소'));
    await t.pumpAndSettle();
    expect(deleted, isNull);

    await t.tap(find.text('삭제'));
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(GlassTap, '삭제').last);
    await t.pumpAndSettle();
    expect(deleted?.target, '/home/.claude/skills/alpha');
    expect(rescans, 1);
  });

  testWidgets('플러그인 스킬은 삭제 대신 안내', (t) async {
    var called = false;
    t.view.physicalSize = const Size(1200, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        home: SkillDetailPage(
          skill: const Skill(
            name: 'p',
            source: SkillSource.plugin,
            plugin: 'p@m',
            path: '/c/x/skills/p',
          ),
          analysisCache: _readyCache(),
          resolveOrigin: _origin,
          deleter: (_) async => called = true,
        ),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.text('삭제'));
    await t.pumpAndSettle();
    expect(find.textContaining('/plugin uninstall p@m'), findsOneWidget);
    await t.tap(find.text('닫기'));
    await t.pumpAndSettle();
    expect(called, isFalse);
  });
}
