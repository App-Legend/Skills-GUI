import 'dart:convert';
import 'dart:io';

import '../scan/agent.dart';
import '../scan/skill.dart';

/// 스킬을 지우지 않고 끄고 켠다. 에이전트의 공식 설정만 쓴다.
/// - Claude Code: 설정 파일의 `skillOverrides` (https://code.claude.com/docs/en/skills)
/// - Codex: `~/.codex/config.toml`의 `[[skills.config]]` `enabled = false`
class SkillToggle {
  SkillToggle({String? home})
    : home =
          home ??
          Platform.environment['USERPROFILE'] ??
          Platform.environment['HOME'];

  /// 홈 폴더. 찾지 못하면 null 이고 끄고 켤 수 없다.
  final String? home;

  String get _sep => Platform.pathSeparator;

  /// 끌 수 없는 이유. null이면 끌 수 있다.
  String? blockedReason(Skill s) {
    if (s.source == SkillSource.plugin) {
      return '플러그인 스킬은 Claude Code의 /plugin 에서 플러그인째 끕니다.';
    }
    if (s.source == SkillSource.synced) return '동기화 폴더의 스킬은 앱에서 끌 수 없습니다.';
    if (home == null) return '홈 폴더를 찾지 못했습니다.';
    if (!_claude(s) && !_codex(s)) return 'Claude Code·Codex 스킬만 끌 수 있습니다.';
    return null;
  }

  bool _claude(Skill s) => s.agents.contains(Agent.claude);
  bool _codex(Skill s) => s.agents.contains(Agent.codex);

  /// 전역 스킬은 사용자 설정, 프로젝트 스킬은 그 프로젝트의 개인 설정(커밋 안 됨)에 쓴다.
  File _claudeSettings(Skill s) => File(
    s.source == SkillSource.project && s.projectPath != null
        ? [s.projectPath, '.claude', 'settings.local.json'].join(_sep)
        : [home, '.claude', 'settings.json'].join(_sep),
  );

  File get _codexConfig => File([home, '.codex', 'config.toml'].join(_sep));

  String _skillMd(Skill s) =>
      '${s.path}$_sep'
      'SKILL.md';

  /// 어느 한 에이전트에서라도 꺼져 있으면 true.
  Future<bool> isOff(Skill s) async {
    if (blockedReason(s) != null) return false;
    if (_claude(s)) {
      final overrides = (await _readJson(_claudeSettings(s)))['skillOverrides'];
      if (overrides is Map && overrides[s.name] == 'off') return true;
    }
    if (_codex(s) && await _codexConfig.exists()) {
      return codexDisabled(await _codexConfig.readAsString(), _skillMd(s));
    }
    return false;
  }

  /// [off]면 끄고 아니면 켠다. 파일의 다른 설정은 그대로 둔다.
  Future<void> set(Skill s, {required bool off}) async {
    if (blockedReason(s) case final why?) throw StateError(why);
    if (_claude(s)) {
      final file = _claudeSettings(s);
      final json = await _readJson(file);
      final overrides = Map<String, dynamic>.from(
        json['skillOverrides'] as Map? ?? const {},
      );
      if (off) {
        overrides[s.name] = 'off';
      } else {
        overrides.remove(s.name);
      }
      if (overrides.isEmpty) {
        json.remove('skillOverrides');
      } else {
        json['skillOverrides'] = overrides;
      }
      await _write(
        file,
        '${const JsonEncoder.withIndent('  ').convert(json)}\n',
      );
    }
    if (_codex(s)) {
      final file = _codexConfig;
      final text = await file.exists() ? await file.readAsString() : '';
      await _write(file, withCodexDisabled(text, _skillMd(s), off: off));
    }
  }

  /// 읽지 못하는 설정 파일은 덮어쓰지 않도록 예외를 그대로 올린다.
  static Future<Map<String, dynamic>> _readJson(File f) async {
    if (!await f.exists()) return {};
    final text = await f.readAsString();
    if (text.trim().isEmpty) return {};
    final v = jsonDecode(text);
    if (v is! Map<String, dynamic>) {
      throw FormatException('설정 파일 형식이 예상과 다릅니다', f.path);
    }
    return v;
  }

  /// 임시 파일에 다 쓴 뒤 바꿔 끼워, 중간에 실패해도 설정 파일이 반쯤 쓰이지 않게 한다.
  static Future<void> _write(File f, String text) async {
    await f.parent.create(recursive: true);
    final temp = File('${f.path}.skill-gui-tmp');
    await temp.writeAsString(text, flush: true);
    await temp.rename(f.path);
  }
}

final _pathLine = RegExp(
  r'''^\s*path\s*=\s*(?:"((?:[^"\\]|\\.)*)"|'([^']*)')''',
);
final _disabledLine = RegExp(r'^\s*enabled\s*=\s*false\b');

String? _pathIn(String line) {
  final m = _pathLine.firstMatch(line);
  if (m == null) return null;
  // 큰따옴표 문자열의 이스케이프는 JSON과 같다고 보고 푼다.
  return m.group(2) ?? jsonDecode('"${m.group(1)}"') as String;
}

/// `[[skills.config]]` 블록들. 다음 `[`로 시작하는 줄 앞까지가 한 블록이다.
Iterable<(int, int)> _blocks(List<String> lines) sync* {
  for (var i = 0; i < lines.length; i++) {
    if (lines[i].trim() != '[[skills.config]]') continue;
    var j = i + 1;
    while (j < lines.length && !lines[j].trimLeft().startsWith('[')) {
      j++;
    }
    yield (i, j);
  }
}

/// [skillMd] 경로가 꺼져 있는지. 같은 스킬에 여러 블록이면 마지막이 이긴다.
// shortcut: path = 로 쓴 블록만 본다. name = 블록은 무시한다. 손으로 name을 쓰는 사람이 생기면 추가.
bool codexDisabled(String toml, String skillMd) {
  final lines = toml.split('\n');
  bool? off;
  for (final (a, b) in _blocks(lines)) {
    final block = lines.sublist(a, b);
    if (block.any((l) => _pathIn(l) == skillMd)) {
      off = block.any(_disabledLine.hasMatch);
    }
  }
  return off ?? false;
}

/// [skillMd]의 블록을 모두 지우고, [off]면 끄는 블록 하나를 끝에 붙인다.
String withCodexDisabled(String toml, String skillMd, {required bool off}) {
  final lines = toml.split('\n');
  final drop = <int>{
    for (final (a, b) in _blocks(lines))
      if (lines.sublist(a, b).any((l) => _pathIn(l) == skillMd))
        for (var i = a; i < b; i++) i,
  };
  var out = [
    for (var i = 0; i < lines.length; i++)
      if (!drop.contains(i)) lines[i],
  ].join('\n').trimRight();
  if (off) {
    out +=
        '${out.isEmpty ? '' : '\n\n'}[[skills.config]]\n'
        'path = ${jsonEncode(skillMd)}\nenabled = false';
  }
  return out.isEmpty ? '' : '$out\n';
}
