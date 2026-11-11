import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:skill_gui/features/skill_analysis/skill_analysis_client.dart';
import 'package:skill_gui/features/scan/skill.dart';

void main() {
  const skill = Skill(
    name: 'review-pr',
    description: 'Review pull requests.',
    source: SkillSource.global,
    path: '/skills/review-pr',
    skillMd: 'Use this skill to review pull requests.',
    files: ['SKILL.md', 'references/checklist.md'],
  );

  test('분석 요청은 SKILL.md와 파일 목록을 전송합니다', () async {
    Uri? requested;
    Map<String, dynamic>? sent;
    final client = SkillAnalysisApiClient(
      'https://relay.example.test/base/',
      httpPost: (uri, body) async {
        requested = uri;
        sent = body;
        return SkillAnalysisHttpResponse(
          200,
          jsonEncode({
            'analysis': {
              'overview': '풀 리퀘스트를 검토하는 스킬입니다.',
              'whenToUse': ['변경 사항을 검토할 때'],
            },
          }),
        );
      },
    );

    final analysis = await client.analyze(skill);

    expect(
      requested.toString(),
      'https://relay.example.test/base/api/skill-analysis',
    );
    expect(sent?['name'], 'review-pr');
    expect(sent?['skill_md'], skill.skillMd);
    expect(sent?['files'], skill.files);
    expect(analysis.overview, '풀 리퀘스트를 검토하는 스킬입니다.');
    expect(analysis.whenToUse, ['변경 사항을 검토할 때']);
  });

  test('분석 결과에 설명문이 없으면 실패합니다', () async {
    final client = SkillAnalysisApiClient(
      'https://relay.example.test',
      httpPost: (_, _) async =>
          const SkillAnalysisHttpResponse(200, '{"analysis": {}}'),
    );

    expect(client.analyze(skill), throwsA(isA<SkillAnalysisApiException>()));
  });
}
