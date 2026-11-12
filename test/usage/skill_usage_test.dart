import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:skill_gui/features/scan/agent.dart';
import 'package:skill_gui/features/scan/skill.dart';
import 'package:skill_gui/features/usage/skill_usage.dart';

void _write(String path, List<Map<String, dynamic>> lines) {
  File(path)
    ..createSync(recursive: true)
    ..writeAsStringSync(lines.map(jsonEncode).join('\n'));
}

void main() {
  late Directory home;
  setUp(() => home = Directory.systemTemp.createTempSync('usage'));
  tearDown(() => home.deleteSync(recursive: true));

  test('Claude 도구 호출·슬래시 명령과 Codex SKILL.md 읽기를 센다', () async {
    _write('${home.path}/.claude/projects/p/s.jsonl', [
      {'type': 'summary', 'timestamp': '2026-09-30T00:00:00Z'},
      {
        'type': 'assistant',
        'timestamp': '2026-10-01T00:00:00Z',
        'message': {
          'content': [
            {
              'type': 'tool_use',
              'name': 'Skill',
              'input': {'skill': 'sp:brain'},
            },
          ],
        },
      },
      {
        'type': 'user',
        'timestamp': '2026-10-05T00:00:00Z',
        'message': {'content': '<command-name>/mine</command-name>'},
      },
      {
        'type': 'assistant',
        'timestamp': '2026-10-09T00:00:00Z',
        'message': {
          'content': [
            // 도구 결과 안에 들어간 문자열은 세지 않는다.
            {'type': 'tool_result', 'content': '"name":"Skill" ghost'},
          ],
        },
      },
    ]);
    _write('${home.path}/.codex/sessions/2026/08/25/r.jsonl', [
      {
        'timestamp': '2026-08-25T00:00:00Z',
        'type': 'response_item',
        'payload': {
          'type': 'message',
          'content': 'skills/listed/SKILL.md', // 프롬프트 목록은 세지 않는다.
        },
      },
      {
        'timestamp': '2026-10-02T00:00:00Z',
        'type': 'response_item',
        'payload': {
          'type': 'custom_tool_call',
          'input': "exec({cmd:\"sed -n '1,240p' /h/.codex/skills/.system/img/SKILL.md\"})",
        },
      },
    ]);

    final u = await readSkillUsage(home.path);
    expect(u.since[Agent.claude], DateTime.utc(2026, 9, 30));
    expect(u.since[Agent.codex], DateTime.utc(2026, 8, 25));
    expect(u.lastUsed[Agent.claude], {
      'sp:brain': DateTime.utc(2026, 10, 1),
      'mine': DateTime.utc(2026, 10, 5),
    });
    expect(u.lastUsed[Agent.codex], {'img': DateTime.utc(2026, 10, 2)});
  });

  test('로그가 없으면 어느 에이전트도 판단하지 않는다', () async {
    final u = await readSkillUsage(home.path);
    expect(u.since, isEmpty);
  });

  group('isStale', () {
    final now = DateTime.utc(2026, 11, 12);
    final u = SkillUsage(
      since: {Agent.claude: DateTime.utc(2026, 9, 1)},
      lastUsed: {
        Agent.claude: {
          'recent': DateTime.utc(2026, 11, 1),
          'old': DateTime.utc(2026, 9, 2),
          'sp:brain': DateTime.utc(2026, 11, 1),
        },
      },
    );
    Skill skill(String name, {String? plugin, List<Agent>? agents}) => Skill(
      name: name,
      source: SkillSource.global,
      plugin: plugin,
      agents: agents ?? const [Agent.claude],
      path: '/x/$name',
    );

    test('30일 안에 쓰면 후보가 아니다', () {
      expect(u.isStale(skill('recent'), now), isFalse);
    });
    test('30일 넘었거나 기록이 없으면 후보다', () {
      expect(u.isStale(skill('old'), now), isTrue);
      expect(u.isStale(skill('never'), now), isTrue);
    });
    test('플러그인 스킬은 "플러그인:이름"으로 찾는다', () {
      expect(u.isStale(skill('brain', plugin: 'sp@market'), now), isFalse);
    });
    test('로그를 못 읽는 에이전트만 읽는 스킬은 판단하지 않는다', () {
      expect(u.isStale(skill('x', agents: const [Agent.cursor]), now), isNull);
    });
  });
}
