import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import '../scan/agent.dart';
import '../scan/skill.dart';

/// 세션 로그에서 읽은 에이전트별 스킬 마지막 사용 시각.
/// Claude Code와 Codex만 읽는다. 다른 에이전트는 로그 형식을 실제로 확인하지 못했다.
class SkillUsage {
  static const staleAfter = Duration(days: 30);

  /// 에이전트 → 스킬 키(이름·폴더명·"플러그인:이름") → 마지막 사용 시각.
  final Map<Agent, Map<String, DateTime>> lastUsed;

  /// 에이전트 → 가장 오래된 로그 시각. 없는 에이전트는 판단할 수 없다.
  final Map<Agent, DateTime> since;

  const SkillUsage({this.lastUsed = const {}, this.since = const {}});

  /// 로그를 읽은 에이전트 중 가장 최근 사용. 없으면 null.
  DateTime? lastUsedOf(Skill s) {
    DateTime? last;
    for (final a in s.agents.where(since.containsKey)) {
      final used = lastUsed[a] ?? const {};
      for (final k in _keys(s)) {
        final t = used[k];
        if (t != null && (last == null || t.isAfter(last))) last = t;
      }
    }
    return last;
  }

  /// true 미사용 후보, false 최근에 씀, null 판단 불가(로그를 못 읽는 에이전트만 읽는 스킬).
  bool? isStale(Skill s, DateTime now) {
    if (!s.agents.any(since.containsKey)) return null;
    final last = lastUsedOf(s);
    return last == null || now.difference(last) >= staleAfter;
  }

  static Iterable<String> _keys(Skill s) sync* {
    final folder = s.path.split(RegExp(r'[/\\]')).last;
    yield s.name;
    yield folder;
    if (s.plugin case final p?) {
      final plugin = p.split('@').first;
      yield '$plugin:${s.name}';
      yield '$plugin:$folder';
    }
  }
}

/// `home` 아래 Claude Code·Codex 세션 로그를 읽는다. 로그가 커서 다른 isolate에서 돈다.
Future<SkillUsage> readSkillUsage(String home) => Isolate.run(() async {
  final lastUsed = <Agent, Map<String, DateTime>>{};
  final since = <Agent, DateTime>{};
  for (final (agent, dir, marker, extract) in [
    (Agent.claude, '$home/.claude/projects', _claudeMarker, _claudeSkills),
    (Agent.codex, '$home/.codex/sessions', _codexMarker, _codexSkills),
  ]) {
    final (used, first) = await _readLogs(Directory(dir), marker, extract);
    if (first == null) continue;
    lastUsed[agent] = used;
    since[agent] = first;
  }
  return SkillUsage(lastUsed: lastUsed, since: since);
});

final _timestamp = RegExp(r'"timestamp":"([^"]+)"');
final _claudeMarker = RegExp(r'"name":"Skill"|<command-name>');
final _codexMarker = RegExp(r'SKILL\.md');
final _command = RegExp(r'<command-name>/([^<\s]+)</command-name>');
final _skillMd = RegExp(r'''([^/\s"'\\]+)/SKILL\.md''');

Future<(Map<String, DateTime>, DateTime?)> _readLogs(
  Directory dir,
  RegExp marker,
  Iterable<String> Function(Map<String, dynamic>) extract,
) async {
  final used = <String, DateTime>{};
  DateTime? since;
  if (!await dir.exists()) return (used, since);
  await for (final f in dir.list(recursive: true, followLinks: false)) {
    if (f is! File || !f.path.endsWith('.jsonl')) continue;
    var first = true;
    try {
      await for (final line
          in f
              .openRead()
              .transform(utf8.decoder)
              .transform(const LineSplitter())) {
        if (first) {
          final t = DateTime.tryParse(
            _timestamp.firstMatch(line)?.group(1) ?? '',
          );
          if (t != null) {
            first = false;
            if (since == null || t.isBefore(since)) since = t;
          }
        }
        if (!marker.hasMatch(line)) continue;
        final Object? j;
        try {
          j = jsonDecode(line);
        } on FormatException {
          continue;
        }
        if (j is! Map<String, dynamic>) continue;
        final t = DateTime.tryParse(j['timestamp'] as String? ?? '');
        if (t == null) continue;
        for (final k in extract(j)) {
          if (used[k]?.isAfter(t) != true) used[k] = t;
        }
      }
    } on FileSystemException {
      continue; // 읽지 못한 파일은 건너뛴다.
    }
  }
  return (used, since);
}

/// Skill 도구 호출과 사용자가 직접 친 `/스킬명`.
Iterable<String> _claudeSkills(Map<String, dynamic> j) sync* {
  final message = j['message'];
  if (message is! Map) return;
  final content = message['content'];
  if (content is String && j['type'] == 'user') {
    for (final m in _command.allMatches(content)) {
      yield m.group(1)!;
    }
  } else if (content is List) {
    for (final c in content) {
      if (c is Map && c['type'] == 'tool_use' && c['name'] == 'Skill') {
        final input = c['input'];
        if (input is Map && input['skill'] is String) yield input['skill'];
      }
    }
  }
}

/// Codex는 스킬을 쓸 때 `SKILL.md`를 명령으로 읽는다. 프롬프트의 스킬 목록은 세지 않는다.
Iterable<String> _codexSkills(Map<String, dynamic> j) sync* {
  final p = j['payload'];
  if (j['type'] != 'response_item' || p is! Map) return;
  if (p['type'] != 'function_call' && p['type'] != 'custom_tool_call') return;
  final args = p['arguments'] ?? p['input'];
  if (args is! String) return;
  for (final m in _skillMd.allMatches(args)) {
    yield m.group(1)!;
  }
}
