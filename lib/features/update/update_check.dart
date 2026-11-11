import 'dart:convert';
import 'dart:io';

import '../scan/agent.dart';

enum UpdateState { needed, unknown }

/// plugin: Claude Code 플러그인, skill: skills CLI(`npx skills`)로 설치한 스킬,
/// app: 이 앱의 설치 버튼으로 설치한 스킬.
enum UpdateKind { plugin, skill, app }

/// 플러그인 말고 스킬 업데이트를 확인·실행하는 곳.
abstract class SkillUpdateSource {
  UpdateKind get kind;

  /// 업데이트가 있는 항목과, 확인하지 못한 곳의 이유.
  Future<({List<PluginUpdate> found, List<String> errors})> check();

  /// 성공하면 null, 실패하면 이유.
  Future<String?> update(PluginUpdate u);
}

class PluginUpdate {
  final String id;
  final String scope;
  final String current;
  final String? latest;
  final int skillCount;
  final UpdateState state;
  final UpdateKind kind;

  /// 프로젝트 스킬만: 그 프로젝트 폴더.
  final String? projectPath;

  /// 앱으로 설치한 스킬만: 설치한 에이전트.
  final Agent? agent;

  const PluginUpdate({
    required this.id,
    required this.scope,
    required this.current,
    required this.latest,
    required this.skillCount,
    required this.state,
    this.kind = UpdateKind.plugin,
    this.projectPath,
    this.agent,
  });

  /// 화면에서 항목을 구분하는 값. 같은 스킬이 여러 프로젝트·에이전트에 있을 수 있다.
  String get key =>
      '${kind.name}|${projectPath ?? ''}|${agent?.name ?? ''}|$id';
}

/// 같은 전역 스킬이 skills CLI와 앱 설치 기록 양쪽에서 나오면 CLI 항목만 남긴다.
/// 둘 다 같은 폴더를 덮어쓰므로 하나만 보여야 한다.
/// shortcut: CLI 항목에는 에이전트가 없어 이름만 비교한다. 다른 에이전트의 같은 이름 스킬도 숨겨지면 에이전트까지 비교한다.
List<PluginUpdate> withoutDuplicateApp(List<PluginUpdate> found) {
  final cliGlobal = {
    for (final p in found)
      if (p.kind == UpdateKind.skill && p.projectPath == null) p.id,
  };
  return [
    for (final p in found)
      if (p.kind != UpdateKind.app || !cliGlobal.contains(p.id.split('/').last))
        p,
  ];
}

String _sep(String p) => p.replaceAll('/', Platform.pathSeparator);

Future<Map<String, dynamic>?> _json(String path) async {
  try {
    final v = jsonDecode(await File(_sep(path)).readAsString());
    return v is Map<String, dynamic> ? v : null;
  } on Object {
    return null;
  }
}

String _short(String sha) => sha.length > 7 ? sha.substring(0, 7) : sha;

/// 마켓 복사본과 설치 기록을 비교해 업데이트가 필요하거나 확인할 수 없는 플러그인만 id 순으로 돌려준다.
/// 마켓 복사본은 `claude plugin marketplace update`로 미리 새로 받아 둔다.
Future<List<PluginUpdate>> checkUpdates(Directory claudeDir) async {
  final root = '${claudeDir.path}/plugins';
  final installed = (await _json('$root/installed_plugins.json'))?['plugins'];
  if (installed is! Map) return [];
  final out = <PluginUpdate>[];
  for (final MapEntry(:key, :value) in installed.entries) {
    if (key is! String || value is! List) continue;
    for (final e in value) {
      if (e is! Map) continue;
      final r = await _checkOne(root, key, e);
      if (r != null) out.add(r);
    }
  }
  out.sort((a, b) => a.id.compareTo(b.id));
  return out;
}

Future<PluginUpdate?> _checkOne(String root, String id, Map e) async {
  final at = id.lastIndexOf('@');
  final name = at < 0 ? id : id.substring(0, at);
  final market = at < 0 ? '' : id.substring(at + 1);
  final version = e['version'] is String ? e['version'] as String : '';
  final sha = e['gitCommitSha'] is String ? e['gitCommitSha'] as String : null;
  final installPath = e['installPath'] is String ? e['installPath'] as String : '';
  var skillCount = 0;
  try {
    skillCount = await Directory(_sep('$installPath/skills'))
        .list()
        .where((x) => x is Directory)
        .length;
  } on FileSystemException {
    // skills/ 없는 플러그인은 0개
  }

  PluginUpdate result(String current, String? latest, UpdateState state) =>
      PluginUpdate(
        id: id,
        scope: e['scope'] is String ? e['scope'] as String : 'user',
        current: current,
        latest: latest,
        skillCount: skillCount,
        state: state,
      );

  final marketDir = '$root/marketplaces/$market';
  final plugins = (await _json('$marketDir/.claude-plugin/marketplace.json'))?['plugins'];
  final entry = plugins is List
      ? plugins.whereType<Map>().where((p) => p['name'] == name).firstOrNull
      : null;
  if (entry == null) return result(version, null, UpdateState.unknown);

  final source = entry['source'];
  var latest = entry['version'] is String ? entry['version'] as String : null;
  if (latest == null && source is String) {
    final pj = await _json('$marketDir/$source/.claude-plugin/plugin.json');
    latest = pj?['version'] is String ? pj!['version'] as String : null;
  }
  if (latest != null) {
    return latest == version ? null : result(version, latest, UpdateState.needed);
  }
  // 버전이 없으면 커밋으로 비교한다.
  final latestSha = source is Map && source['sha'] is String ? source['sha'] as String : null;
  if (latestSha != null && sha != null) {
    return latestSha == sha
        ? null
        : result(_short(sha), _short(latestSha), UpdateState.needed);
  }
  return result(version, null, UpdateState.unknown);
}
