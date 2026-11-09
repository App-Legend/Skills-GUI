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
      expect(o.githubUrl, 'https://github.com/o/r');
      expect(o.commands, [
        '/plugin marketplace add o/r',
        '/plugin install local@mk',
      ]);
    });

    test('다른 저장소 하위 폴더', () async {
      final o = await resolveSkillOrigin(plugin('sub@mk'), claude);
      expect(o.githubUrl, 'https://github.com/x/y');
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

  test('npx skills 설치 기록에서 전역 스킬 출처를 찾는다', () async {
    final home = await Directory.systemTemp.createTemp('skill-lock-');
    addTearDown(() => home.delete(recursive: true));
    final claude = Directory('${home.path}/.claude')..createSync();
    Directory('${home.path}/.agents').createSync();
    File('${home.path}/.agents/.skill-lock.json').writeAsStringSync(
      jsonEncode({
        'version': 3,
        'skills': {
          'design-taste-frontend': {
            'source': 'leonxlnx/taste-skill',
            'sourceType': 'github',
            'skillPath': 'skills/taste-skill/SKILL.md',
          },
        },
      }),
    );
    final o = await resolveSkillOrigin(
      const Skill(
        name: 'design-taste-frontend',
        source: SkillSource.global,
        path: '/s/design-taste-frontend',
      ),
      claude,
    );
    expect(o.githubUrl, 'https://github.com/leonxlnx/taste-skill');
    expect(o.commands, [
      'npx skills add leonxlnx/taste-skill --skill design-taste-frontend -g -a claude-code',
    ]);
    expect(o.note, isNull);

    final none = await resolveSkillOrigin(
      const Skill(name: 'x', source: SkillSource.global, path: '/s/x'),
      claude,
    );
    expect(none.githubUrl, isNull);
    expect(none.note, isNotNull);
  });

  group('프로젝트 설치 기록(skills-lock.json)', () {
    late Directory home;
    late Directory claude;
    void writeLock(String dir, String name, String source) {
      File('$dir/skills-lock.json').writeAsStringSync(
        jsonEncode({
          'version': 1,
          'skills': {
            name: {'source': source, 'sourceType': 'github'},
          },
        }),
      );
    }

    setUp(() async {
      home = await Directory.systemTemp.createTemp('skill-proj-');
      claude = Directory('${home.path}/.claude')..createSync();
    });
    tearDown(() => home.delete(recursive: true));

    test('프로젝트 폴더에서 설치한 스킬은 -g 없이, 실행 폴더 안내', () async {
      final project = Directory('${home.path}/proj')..createSync();
      final skillDir = Directory('${project.path}/.agents/skills/taste')
        ..createSync(recursive: true);
      writeLock(project.path, 'taste', 'a/taste');
      final o = await resolveSkillOrigin(
        Skill(name: 'taste', source: SkillSource.global, path: skillDir.path),
        claude,
      );
      expect(o.githubUrl, 'https://github.com/a/taste');
      expect(o.commands, [
        'npx skills add a/taste --skill taste -a claude-code',
      ]);
      expect(o.note, contains(project.path));
    });

    test('홈에서 -g 없이 설치한 기록은 전역 명령으로 보여준다', () async {
      final skillDir = Directory('${claude.path}/skills/hall')
        ..createSync(recursive: true);
      writeLock(home.path, 'hall', 'n/hall');
      final o = await resolveSkillOrigin(
        Skill(name: 'hall', source: SkillSource.global, path: skillDir.path),
        claude,
      );
      expect(o.githubUrl, 'https://github.com/n/hall');
      expect(o.commands, [
        'npx skills add n/hall --skill hall -g -a claude-code',
      ]);
      expect(o.note, isNull);
    });
  });
}
