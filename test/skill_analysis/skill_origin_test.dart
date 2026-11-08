import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:skill_gui/features/skill_analysis/skill_origin.dart';
import 'package:skill_gui/scan/skill.dart';

void main() {
  test('GitHub 저장소 주소 해석', () {
    expect(githubRepoOf('https://github.com/a/b.git'), 'a/b');
    expect(githubRepoOf('https://github.com/a/b'), 'a/b');
    expect(githubRepoOf('git@github.com:a/b.git'), 'a/b');
    expect(githubRepoOf('https://gitlab.com/a/b'), isNull);
  });

  test('전역 스킬은 주소 없이 설치 위치 안내', () async {
    final o = await resolveSkillOrigin(
      const Skill(name: 'a', source: SkillSource.global, path: '/s/alpha'),
      null,
    );
    expect(o.githubUrl, isNull);
    expect(o.note, isNotNull);
    expect(o.commands.single, endsWith('alpha'));
  });

  group('플러그인 스킬', () {
    late Directory claude;
    setUp(() async {
      claude = await Directory.systemTemp.createTemp('skill-origin-');
      final market = Directory('${claude.path}/m-loc/.claude-plugin')
        ..createSync(recursive: true);
      File('${market.path}/marketplace.json').writeAsStringSync(
        jsonEncode({
          'plugins': [
            {'name': 'local', 'source': './plugins/local'},
            {
              'name': 'sub',
              'source': {
                'source': 'git-subdir',
                'url': 'https://github.com/x/y.git',
                'path': 'plugins/sub',
                'ref': 'v1',
              },
            },
            {
              'name': 'other',
              'source': {'source': 'url', 'url': 'https://example.com/z.git'},
            },
          ],
        }),
      );
      Directory('${claude.path}/plugins').createSync();
      File('${claude.path}/plugins/known_marketplaces.json').writeAsStringSync(
        jsonEncode({
          'mk': {
            'source': {'source': 'github', 'repo': 'o/r'},
            'installLocation': '${claude.path}/m-loc',
          },
        }),
      );
    });
    tearDown(() => claude.delete(recursive: true));

    Skill plugin(String id) => Skill(
      name: 'n',
      source: SkillSource.plugin,
      plugin: id,
      path: '/cache/x/skills/do-it',
    );

    test('마켓 안 플러그인', () async {
      final o = await resolveSkillOrigin(plugin('local@mk'), claude);
      expect(
        o.githubUrl,
        'https://github.com/o/r/tree/HEAD/plugins/local/skills/do-it',
      );
      expect(o.commands, [
        '/plugin marketplace add o/r',
        '/plugin install local@mk',
      ]);
    });

    test('다른 저장소 하위 폴더', () async {
      final o = await resolveSkillOrigin(plugin('sub@mk'), claude);
      expect(
        o.githubUrl,
        'https://github.com/x/y/tree/v1/plugins/sub/skills/do-it',
      );
    });

    test('GitHub가 아니거나 모르는 마켓이면 주소 없음', () async {
      expect(
        (await resolveSkillOrigin(plugin('other@mk'), claude)).githubUrl,
        isNull,
      );
      final unknown = await resolveSkillOrigin(plugin('a@none'), claude);
      expect(unknown.githubUrl, isNull);
      expect(unknown.commands, ['/plugin install a@none']);
    });
  });
}
