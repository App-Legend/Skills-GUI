import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:skill_gui/features/scan/agent.dart';
import 'package:skill_gui/features/scan/skill.dart';
import 'package:skill_gui/features/skill_toggle/skill_toggle.dart';

void main() {
  late Directory home;
  late SkillToggle toggle;
  setUp(() async {
    home = await Directory.systemTemp.createTemp('skill-toggle-');
    toggle = SkillToggle(home: home.path);
  });
  tearDown(() => home.delete(recursive: true));

  File claudeSettings() => File('${home.path}/.claude/settings.json');
  File codexConfig() => File('${home.path}/.codex/config.toml');

  test('Claude 전역 스킬은 skillOverrides에 쓰고, 다른 설정은 남긴다', () async {
    claudeSettings()
      ..createSync(recursive: true)
      ..writeAsStringSync(
        '{"model": "opus", "skillOverrides": {"other": "off"}}',
      );
    final s = Skill(
      name: 'alpha',
      source: SkillSource.global,
      path: '${home.path}/.claude/skills/alpha',
    );

    await toggle.set(s, off: true);
    expect(await toggle.isOff(s), isTrue);
    expect(jsonDecode(claudeSettings().readAsStringSync()), {
      'model': 'opus',
      'skillOverrides': {'other': 'off', 'alpha': 'off'},
    });

    await toggle.set(s, off: false);
    expect(await toggle.isOff(s), isFalse);
    expect(jsonDecode(claudeSettings().readAsStringSync()), {
      'model': 'opus',
      'skillOverrides': {'other': 'off'},
    });
  });

  test('프로젝트 스킬은 그 프로젝트의 settings.local.json에 쓴다', () async {
    final project = Directory('${home.path}/proj')..createSync();
    final s = Skill(
      name: 'beta',
      source: SkillSource.project,
      projectPath: project.path,
      path: '${project.path}/.claude/skills/beta',
    );
    await toggle.set(s, off: true);
    expect(
      File('${project.path}/.claude/settings.local.json').existsSync(),
      isTrue,
    );
    expect(claudeSettings().existsSync(), isFalse);
  });

  test('읽지 못하는 설정 파일은 덮어쓰지 않는다', () async {
    claudeSettings()
      ..createSync(recursive: true)
      ..writeAsStringSync('{ broken');
    final s = Skill(
      name: 'alpha',
      source: SkillSource.global,
      path: '/x/skills/alpha',
    );
    await expectLater(toggle.set(s, off: true), throwsFormatException);
    expect(claudeSettings().readAsStringSync(), '{ broken');
  });

  test('Codex 스킬은 config.toml에 끄는 블록을 붙이고, 켜면 그 블록만 지운다', () async {
    const before =
        'model = "o3"\n\n[[skills.config]]\npath = "/other/SKILL.md"\nenabled = false\n';
    codexConfig()
      ..createSync(recursive: true)
      ..writeAsStringSync(before);
    final s = Skill(
      name: 'gamma',
      source: SkillSource.global,
      agents: const [Agent.codex],
      path: '${home.path}/.agents/skills/gamma',
    );

    await toggle.set(s, off: true);
    expect(await toggle.isOff(s), isTrue);
    expect(codexConfig().readAsStringSync(), contains('enabled = false'));
    expect(claudeSettings().existsSync(), isFalse); // Claude 스킬이 아니면 건드리지 않는다

    await toggle.set(s, off: false);
    expect(await toggle.isOff(s), isFalse);
    expect(codexConfig().readAsStringSync(), before);
  });

  test('TOML: 같은 스킬 블록이 여럿이면 마지막이 이기고, 작은따옴표 경로도 읽는다', () {
    const toml =
        "[[skills.config]]\npath = '/a/SKILL.md'\nenabled = false\n\n"
        '[[skills.config]]\npath = "/a/SKILL.md"\nenabled = true\n';
    expect(codexDisabled(toml, '/a/SKILL.md'), isFalse);
    expect(withCodexDisabled(toml, '/a/SKILL.md', off: false), '');
  });

  test('플러그인·동기화 스킬은 끌 수 없다', () {
    expect(
      toggle.blockedReason(
        const Skill(name: 'p', source: SkillSource.plugin, path: '/p'),
      ),
      isNotNull,
    );
    expect(
      toggle.blockedReason(
        const Skill(name: 's', source: SkillSource.synced, path: '/s'),
      ),
      isNotNull,
    );
    expect(
      toggle.blockedReason(
        const Skill(
          name: 'c',
          source: SkillSource.global,
          agents: [Agent.cursor],
          path: '/c',
        ),
      ),
      isNotNull,
    );
  });
}
