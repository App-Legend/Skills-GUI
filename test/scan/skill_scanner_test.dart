import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:skill_gui/scan/skill.dart';
import 'package:skill_gui/scan/skill_scanner.dart';

void main() {
  late Directory root;
  late Directory claude;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('scan_test');
    claude = await Directory('${root.path}/.claude').create();
  });
  tearDown(() => root.delete(recursive: true));

  Future<void> file(String rel, String content) async {
    final f = File('${claude.path}/$rel');
    await f.parent.create(recursive: true);
    await f.writeAsString(content);
  }

  Skill byName(ScanResult r, String n) =>
      r.skills.firstWhere((s) => s.name == n);

  test('globalSkill', () async {
    const md = '---\nname: a\ndescription: d\n---\nbody\n';
    await file('skills/a/SKILL.md', md);
    await file('skills/a/scripts/run.sh', 'x');
    final s = byName(await scanClaude(claude), 'a');
    expect(s.source, SkillSource.global);
    expect(s.description, 'd');
    expect(s.files, ['SKILL.md', 'scripts/run.sh']);
    expect(s.problem, isNull);
    expect(s.skillMd, md);
  });

  test('noSkillMd', () async {
    await Directory('${claude.path}/skills/b').create(recursive: true);
    final s = byName(await scanClaude(claude), 'b');
    expect(s.problem!.kind, ProblemKind.noSkillMd);
  });

  test('badFrontmatter', () async {
    await file('skills/e/SKILL.md', 'no header');
    final s = byName(await scanClaude(claude), 'e');
    expect(s.problem!.kind, ProblemKind.badFrontmatter);
    expect(s.skillMd, 'no header');
  });

  test('bomSkillMd', () async {
    await file('skills/bom/SKILL.md', '﻿---\nname: bom\ndescription: d\n---\n');
    final s = byName(await scanClaude(claude), 'bom');
    expect(s.problem, isNull);
    expect(s.description, 'd');
  });

  test('missing name uses folder name', () async {
    await file('skills/f/SKILL.md', '---\ndescription: d\n---\n');
    final s = byName(await scanClaude(claude), 'f');
    expect(s.problem, isNull);
  });

  test('linkedSkill', () async {
    final target = await Directory('${root.path}/elsewhere').create();
    await File('${target.path}/SKILL.md')
        .writeAsString('---\nname: c\ndescription: d\n---\n');
    await Directory('${claude.path}/skills').create(recursive: true);
    await Link('${claude.path}/skills/c').create(target.path);
    final s = byName(await scanClaude(claude), 'c');
    expect(s.problem, isNull);
    expect(s.linkTarget, target.path);
    expect(s.files, ['SKILL.md']);
  });

  test('brokenLink', () async {
    await Directory('${claude.path}/skills').create(recursive: true);
    final missing = '${root.path}/nope';
    await Link('${claude.path}/skills/d').create(missing);
    final s = byName(await scanClaude(claude), 'd');
    expect(s.problem!.kind, ProblemKind.brokenLink);
    expect(s.linkTarget, missing);
  });

  test('synced', () async {
    await file('skills/synced/acc1/docx/SKILL.md', 'x');
    final r = await scanClaude(claude);
    expect(r.skills, hasLength(1));
    final s = r.skills.single;
    expect(s.name, 'synced');
    expect(s.source, SkillSource.synced);
    expect(s.description, 'claude.ai에서 동기화된 스킬 폴더');
    expect(s.problem, isNull);
    expect(s.files, contains('acc1/docx/SKILL.md'));
  });

  test('noSkillsDir', () async {
    final r = await scanClaude(claude);
    expect(r.skills, isEmpty);
  });

  test('fileSkippedAtTopLevel', () async {
    await file('skills/.DS_Store', 'x');
    expect((await scanClaude(claude)).skills, isEmpty);
  });

  test('nonUtf8SkillMd', () async {
    await Directory('${claude.path}/skills/u').create(recursive: true);
    await File('${claude.path}/skills/u/SKILL.md')
        .writeAsBytes([0xff, 0xfe, 0x41]);
    final s = byName(await scanClaude(claude), 'u');
    expect(s.problem!.kind, ProblemKind.unreadable);
    expect(s.skillMd, isNull);
  });

  test('classifyFsError', () {
    FileSystemException e(int c) =>
        FileSystemException('x', 'p', OSError('', c));
    expect(classifyFsError(e(1)), ProblemKind.noPermission);
    expect(classifyFsError(e(13)), ProblemKind.noPermission);
    expect(classifyFsError(e(2)), ProblemKind.unreadable);
  });

  group('plugins', () {
    const md = '---\nname: x\ndescription: d\n---\n';
    String inst(String v) => '${claude.path}/plugins/cache/m/p/$v';
    Future<void> install(
      List<Map<String, Object?>> entries, {
      String id = 'p@m',
    }) => file(
      'plugins/installed_plugins.json',
      jsonEncode({
        'version': 2,
        'plugins': {id: entries},
      }),
    );
    Future<void> user({String v = '1.0.0', Map<String, Object?>? extra}) =>
        install([
          {'scope': 'user', 'installPath': inst(v), 'version': v, ...?extra},
        ]);
    Skill plug(ScanResult r) =>
        r.skills.firstWhere((s) => s.source == SkillSource.plugin);

    test('enabledPlugin', () async {
      await file('plugins/cache/m/p/1.0.0/skills/x/SKILL.md', md);
      await user();
      await file('settings.json', '{"enabledPlugins":{"p@m":true}}');
      final s = plug(await scanClaude(claude));
      expect(s.plugin, 'p@m');
      expect(s.pluginVersion, '1.0.0');
      expect(s.pluginEnabled, true);
    });

    test('disabledPlugin', () async {
      await file('plugins/cache/m/p/1.0.0/skills/x/SKILL.md', md);
      await user();
      await file('settings.json', '{"enabledPlugins":{"p@m":false}}');
      expect(plug(await scanClaude(claude)).pluginEnabled, false);
      await file('settings.json', '{"enabledPlugins":{}}');
      expect(plug(await scanClaude(claude)).pluginEnabled, false);
    });

    test('projectScope', () async {
      await file('plugins/cache/m/p/1.0.0/skills/x/SKILL.md', md);
      await install([
        {
          'scope': 'project',
          'projectPath': '/w/app',
          'installPath': inst('1.0.0'),
          'version': '1.0.0',
        },
      ]);
      await file('settings.json', '{"enabledPlugins":{"p@m":true}}');
      final s = plug(await scanClaude(claude));
      expect(s.projectPath, '/w/app');
      expect(s.pluginEnabled, isNull);
    });

    test('projectScopeNoPath', () async {
      await file('plugins/cache/m/p/1.0.0/skills/x/SKILL.md', md);
      await install([
        {'scope': 'project', 'installPath': inst('1.0.0'), 'version': '1.0.0'},
      ]);
      final s = plug(await scanClaude(claude));
      expect(s.projectPath, isNull);
      expect(s.pluginEnabled, isNull);
    });

    test('noSettings', () async {
      await file('plugins/cache/m/p/1.0.0/skills/x/SKILL.md', md);
      await user();
      final r = await scanClaude(claude);
      expect(plug(r).pluginEnabled, isNull);
      expect(r.notices, ['settings.json을 읽지 못해 플러그인 켜짐 여부를 알 수 없습니다']);
    });

    test('oldVersions', () async {
      await file('plugins/cache/m/p/0.9.0/skills/old/SKILL.md', md);
      await file('plugins/cache/m/p/1.0.0/skills/x/SKILL.md', md);
      await user();
      await file('settings.json', '{"enabledPlugins":{"p@m":true}}');
      final r = await scanClaude(claude);
      expect(r.skills.where((s) => s.name == 'old'), isEmpty);
      expect(r.notices, ['플러그인 옛 버전 폴더 1개가 남아 있습니다']);
    });

    test('noOldVersionsNoNotice', () async {
      await file('plugins/cache/m/p/1.0.0/skills/x/SKILL.md', md);
      await user();
      await file('settings.json', '{"enabledPlugins":{"p@m":true}}');
      expect((await scanClaude(claude)).notices, isEmpty);
    });

    test('noInstalledJson', () async {
      await file('skills/a/SKILL.md', md);
      final r = await scanClaude(claude);
      expect(r.skills.length, 1);
      expect(r.notices, isEmpty);
    });

    test('badInstalledJson', () async {
      await file('skills/a/SKILL.md', md);
      await file('plugins/installed_plugins.json', '{oops');
      var r = await scanClaude(claude);
      expect(r.skills.length, 1);
      expect(r.notices, ['installed_plugins.json을 읽지 못했습니다']);
      await file('plugins/installed_plugins.json', '{"plugins":[1]}');
      r = await scanClaude(claude);
      expect(r.notices, ['installed_plugins.json을 읽지 못했습니다']);
    });

    test('missingInstallPath', () async {
      await user();
      await file('settings.json', '{"enabledPlugins":{"p@m":true}}');
      final r = await scanClaude(claude);
      expect(r.notices, ['p@m 플러그인 폴더가 없습니다']);
    });

    test('pluginWithoutSkills', () async {
      await Directory(inst('1.0.0')).create(recursive: true);
      await user();
      await file('settings.json', '{"enabledPlugins":{"p@m":true}}');
      final r = await scanClaude(claude);
      expect(r.skills, isEmpty);
      expect(r.notices, isEmpty);
    });

    test('sameNameGlobalAndPlugin', () async {
      await file('skills/a/SKILL.md', md);
      await file('plugins/cache/m/p/1.0.0/skills/a/SKILL.md', md);
      await user();
      await file('settings.json', '{"enabledPlugins":{"p@m":true}}');
      final r = await scanClaude(claude);
      expect(r.skills.map((s) => s.source), [
        SkillSource.global,
        SkillSource.plugin,
      ]);
    });
  });
}
