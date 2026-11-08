import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skill_gui/features/skill_analysis/skill_analysis.dart';
import 'package:skill_gui/features/skill_analysis/skill_analysis_cache.dart';
import 'package:skill_gui/features/skill_analysis/skill_analysis_client.dart';
import 'package:skill_gui/features/skill_analysis/skill_origin.dart';
import 'package:skill_gui/scan/skill.dart';
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
  githubUrl: 'https://github.com/o/r/tree/HEAD/skills/alpha',
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
    for (final x in [
      'alpha',
      '전역',
      '경로',
      '/home/.claude/skills/alpha',
      '알파 설명',
      '포함된 파일',
      'a.txt',
    ]) {
      expect(find.text(x), findsWidgets, reason: x);
    }
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
    for (final x in ['버전', '1.2.3', '실제 경로', '/real/v']) {
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

    expect(find.text('한국어 분석'), findsOneWidget);
    expect(find.text('이 스킬은'), findsOneWidget);
    expect(find.text('풀 리퀘스트 검토를 돕는 스킬입니다.'), findsOneWidget);
    expect(find.text('이럴 때 사용'), findsOneWidget);
    expect(find.text('결과'), findsOneWidget);
    expect(find.text('필요한 입력·준비'), findsNothing);
  });

  testWidgets('설치방법 복사, 원문 보기 버튼, 원문 섹션 없음', (t) async {
    await _pump(t, full);
    await t.pump();
    expect(find.text('설치방법'), findsOneWidget);
    expect(find.text('/plugin install p@m'), findsOneWidget);
    expect(find.byIcon(Icons.copy), findsNWidgets(2));
    expect(find.text('원문 보기'), findsOneWidget);
    expect(find.text('SKILL.md 원문'), findsNothing);
    final button = t.widget<OutlinedButton>(
      find.ancestor(
        of: find.text('원문 보기'),
        matching: find.byType(OutlinedButton),
      ),
    );
    expect(button.onPressed, isNotNull);
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
    expect(find.text('GitHub 주소를 찾지 못했습니다'), findsOneWidget);
    final button = t.widget<OutlinedButton>(
      find.ancestor(
        of: find.text('원문 보기'),
        matching: find.byType(OutlinedButton),
      ),
    );
    expect(button.onPressed, isNull);
    expect(find.text('설치방법'), findsNothing);
  });
}
