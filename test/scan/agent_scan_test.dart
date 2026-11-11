import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:skill_gui/features/scan/agent.dart';
import 'package:skill_gui/features/scan/skill.dart';
import 'package:skill_gui/features/scan/skill_scanner.dart';

void main() {
  late Directory home;

  setUp(() async {
    home = await Directory.systemTemp.createTemp('agent_scan_test');
  });
  tearDown(() => home.delete(recursive: true));

  Future<void> skill(String dir) async {
    final f = File('${home.path}/$dir/SKILL.md');
    await f.parent.create(recursive: true);
    await f.writeAsString(
      '---\nname: ${dir.split('/').last}\ndescription: d\n---\n',
    );
  }

  Skill byName(ScanResult r, String n) =>
      r.skills.firstWhere((s) => s.name == n);

  test('에이전트마다 전역 폴더를 읽고 숨김 폴더는 뺀다', () async {
    await skill('.claude/skills/a');
    await skill('.cursor/skills/b');
    await skill('.agents/skills/c');
    await skill('.agents/skills/.system/x');
    await skill('.config/opencode/skills/d');
    await skill('.codeium/windsurf/skills/e');

    final r = await scanAllAgents(Directory('${home.path}/.claude'));

    expect(byName(r, 'a').agents, [Agent.claude]);
    expect(byName(r, 'b').agents, [Agent.cursor]);
    expect(byName(r, 'c').agents, [Agent.codex]);
    expect(byName(r, 'd').agents, [Agent.opencode]);
    expect(byName(r, 'e').agents, [Agent.windsurf]);
    expect(r.skills.where((s) => s.name == 'x'), isEmpty);
    expect(r.skills.every((s) => s.source == SkillSource.global), isTrue);
  });

  test('Claude·Codex가 기록한 프로젝트의 스킬을 읽는다', () async {
    final p1 = '${home.path}/work/p1';
    final p2 = "${home.path}/work/it's p2";
    await File('${home.path}/.claude.json').writeAsString(
      jsonEncode({
        'projects': {p1: {}, home.path: {}, '${home.path}/gone': {}},
      }),
    );
    await Directory('${home.path}/.codex').create();
    await File('${home.path}/.codex/config.toml').writeAsString(
      '[projects."$p2"]\ntrust_level = "trusted"\n[projects."$p1"]\n',
    );
    await skill('work/p1/.agents/skills/shared');
    await skill('work/p1/.windsurf/skills/ws');
    await skill("work/it's p2/.claude/skills/cl");

    // 정렬 순서: "'"가 "p"보다 앞선다.
    expect(await knownProjects(home.path), [p2, p1]);

    final r = await scanAllAgents(Directory('${home.path}/.claude'));
    final shared = byName(r, 'shared');
    expect(shared.source, SkillSource.project);
    expect(shared.projectPath, p1);
    expect(shared.agents, [
      Agent.codex,
      Agent.cursor,
      Agent.copilot,
      Agent.gemini,
      Agent.opencode,
    ]);
    expect(byName(r, 'ws').agents, [Agent.windsurf]);
    expect(byName(r, 'cl').agents, [Agent.claude]);
    expect(byName(r, 'cl').projectPath, p2);
  });

  test('홈 폴더가 프로젝트로 기록돼 있어도 전역 스킬이 두 번 나오지 않습니다', () async {
    await File('${home.path}/.claude.json').writeAsString(
      jsonEncode({
        'projects': {'${home.path}/': {}},
      }),
    );
    await skill('.claude/skills/a');
    final r = await scanAllAgents(Directory('${home.path}/.claude'));
    expect(r.skills.where((s) => s.name == 'a').length, 1);
  });
}
