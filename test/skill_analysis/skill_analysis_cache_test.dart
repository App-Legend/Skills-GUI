import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:skill_gui/features/skill_analysis/skill_analysis.dart';
import 'package:skill_gui/features/skill_analysis/skill_analysis_cache.dart';
import 'package:skill_gui/features/scan/skill.dart';

void main() {
  const skill = Skill(
    name: 'alpha',
    source: SkillSource.global,
    path: '/skills/alpha',
    skillMd: 'alpha body',
  );

  test('원문이 같은 스킬의 분석을 다시 읽는다', () async {
    final directory = await Directory.systemTemp.createTemp(
      'skill-analysis-test-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final cache = FileSkillAnalysisCache(directory: directory);
    const analysis = SkillAnalysis(
      overview: '알파 스킬을 설명합니다.',
      categories: ['git'],
    );

    await cache.save(skill, analysis);

    expect((await cache.load(skill))?.overview, analysis.overview);
  });

  test('원문이 달라지면 기존 분석을 쓰지 않습니다', () async {
    final directory = await Directory.systemTemp.createTemp(
      'skill-analysis-test-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final cache = FileSkillAnalysisCache(directory: directory);
    await cache.save(skill, const SkillAnalysis(overview: '알파 스킬을 설명합니다.'));
    const changed = Skill(
      name: 'alpha',
      source: SkillSource.global,
      path: '/skills/alpha',
      skillMd: 'changed body',
    );

    expect(await cache.load(changed), isNull);
  });

  test('카테고리가 없던 이전 형식 캐시는 다시 분석합니다', () async {
    final directory = await Directory.systemTemp.createTemp(
      'skill-analysis-test-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final cache = FileSkillAnalysisCache(directory: directory);
    await cache.save(
      skill,
      const SkillAnalysis(overview: '개요', categories: ['git']),
    );
    expect((await cache.load(skill))?.categories, ['git']);
    final file = directory.listSync().whereType<File>().single;
    file.writeAsStringSync('{"analysis":{"overview":"이전 형식"}}');
    expect(await cache.load(skill), isNull);
  });

  test('카테고리가 빈 결과는 다시 분석합니다', () async {
    final directory = await Directory.systemTemp.createTemp(
      'skill-analysis-test-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final cache = FileSkillAnalysisCache(directory: directory);
    await cache.save(skill, const SkillAnalysis(overview: '개요'));
    expect(await cache.load(skill), isNull);
  });
}
