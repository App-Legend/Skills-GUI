import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:skill_gui/features/skill_analysis/skill_analysis.dart';
import 'package:skill_gui/features/skill_analysis/skill_analysis_cache.dart';
import 'package:skill_gui/features/skill_analysis/skill_analysis_client.dart';
import 'package:skill_gui/features/skill_analysis/skill_analysis_store.dart';
import 'package:skill_gui/scan/skill.dart';

class _Cache implements SkillAnalysisCache {
  final saved = <String, SkillAnalysis>{};
  @override
  Future<SkillAnalysis?> load(Skill skill) async => saved[skill.path];
  @override
  Future<void> save(Skill skill, SkillAnalysis analysis) async =>
      saved[skill.path] = analysis;
}

Skill _skill(String name, {String md = 'body'}) =>
    Skill(name: name, source: SkillSource.global, path: '/$name', skillMd: md);

void main() {
  test('동시에 정해진 수만 요청하고, 결과를 캐시에 저장합니다', () async {
    var running = 0;
    var peak = 0;
    var calls = 0;
    final cache = _Cache();
    final store = SkillAnalysisStore(
      concurrency: 2,
      cache: cache,
      client: SkillAnalysisApiClient(
        'https://relay.example.test',
        httpPost: (_, body) async {
          calls++;
          running++;
          peak = running > peak ? running : peak;
          await Future<void>.delayed(const Duration(milliseconds: 10));
          running--;
          return SkillAnalysisHttpResponse(
            200,
            '{"analysis":{"overview":"${body['name']} 개요",'
            '"categories":["devops","없는값"]}}',
          );
        },
      ),
    );
    addTearDown(store.dispose);
    final skills = [
      for (final n in ['a', 'b', 'c', 'd']) _skill(n),
    ];
    final done = Completer<void>();
    store.addListener(() {
      if (skills.every((s) => store.analysisOf(s) != null) &&
          !done.isCompleted) {
        done.complete();
      }
    });
    store.request([...skills, ...skills]);
    await done.future;

    expect(calls, 4);
    expect(peak, 2);
    expect(store.analysisOf(skills[0])?.categories, ['devops']);
    expect(cache.saved.length, 4);

    // 다시 요청해도 서버를 부르지 않는다.
    store.request(skills);
    expect(calls, 4);
  });

  test('문제가 있거나 원문이 없는 스킬은 분석하지 않습니다', () {
    expect(
      SkillAnalysisStore.canAnalyze(
        const Skill(name: 'a', source: SkillSource.synced, path: '/a'),
      ),
      isFalse,
    );
    expect(SkillAnalysisStore.canAnalyze(_skill('b', md: '  ')), isFalse);
  });
}
