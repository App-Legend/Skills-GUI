import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:skill_gui/features/update/update_check.dart';

late Directory claude;

void _write(String rel, Object json) {
  final f = File('${claude.path}/$rel');
  f.parent.createSync(recursive: true);
  f.writeAsStringSync(json is String ? json : jsonEncode(json));
}

/// 설치 기록 한 건과 그 installPath를 만든다.
void _install(String id, String version, {String? sha, int skills = 0}) {
  final name = id.split('@').first;
  final market = id.split('@').last;
  final path = '${claude.path}/plugins/cache/$market/$name/$version';
  for (var i = 0; i < skills; i++) {
    Directory('$path/skills/s$i').createSync(recursive: true);
  }
  Directory(path).createSync(recursive: true);
  final f = File('${claude.path}/plugins/installed_plugins.json');
  final data = f.existsSync()
      ? jsonDecode(f.readAsStringSync()) as Map<String, dynamic>
      : <String, dynamic>{'version': 2, 'plugins': <String, dynamic>{}};
  (data['plugins'] as Map<String, dynamic>)[id] = [
    {
      'scope': 'user',
      'installPath': path,
      'version': version,
      'gitCommitSha': ?sha,
    },
  ];
  f.parent.createSync(recursive: true);
  f.writeAsStringSync(jsonEncode(data));
}

void _market(String market, List<Map<String, Object?>> plugins) =>
    _write('plugins/marketplaces/$market/.claude-plugin/marketplace.json', {
      'name': market,
      'plugins': plugins,
    });

void main() {
  setUp(() => claude = Directory.systemTemp.createTempSync('upd'));
  tearDown(() => claude.deleteSync(recursive: true));

  test('versionFromMarketJson', () async {
    _install('p@m', '1.0');
    _market('m', [
      {'name': 'p', 'version': '1.1', 'source': './'},
    ]);
    final r = await checkUpdates(claude);
    expect(r, hasLength(1));
    expect(r.single.id, 'p@m');
    expect(r.single.current, '1.0');
    expect(r.single.latest, '1.1');
    expect(r.single.state, UpdateState.needed);
    expect(r.single.scope, 'user');
  });

  test('versionFromPluginJson', () async {
    _install('p@m', '1.0');
    _market('m', [
      {'name': 'p', 'source': './plugins/p'},
    ]);
    _write('plugins/marketplaces/m/plugins/p/.claude-plugin/plugin.json', {
      'version': '2.0',
    });
    final r = await checkUpdates(claude);
    expect(r.single.latest, '2.0');
  });

  test('sameVersionHidden', () async {
    _install('p@m', '1.0');
    _market('m', [
      {'name': 'p', 'version': '1.0', 'source': './'},
    ]);
    expect(await checkUpdates(claude), isEmpty);
  });

  test('shaCompare', () async {
    _install('p@m', '1.0', sha: '1111111999');
    _market('m', [
      {
        'name': 'p',
        'source': {'source': 'url', 'url': 'x', 'sha': 'abcdef1234'},
      },
    ]);
    final r = await checkUpdates(claude);
    expect(r.single.state, UpdateState.needed);
    expect(r.single.current, '1111111');
    expect(r.single.latest, 'abcdef1');
  });

  test('noMarket', () async {
    _install('p@m', '1.0');
    final r = await checkUpdates(claude);
    expect(r.single.state, UpdateState.unknown);
    expect(r.single.latest, isNull);
  });

  test('badJson', () async {
    _install('p@m', '1.0');
    _install('q@n', '1.0');
    _write('plugins/marketplaces/m/.claude-plugin/marketplace.json', '{oops');
    _market('n', [
      {'name': 'q', 'version': '2.0', 'source': './'},
    ]);
    final r = await checkUpdates(claude);
    expect(r.map((e) => e.id), ['p@m', 'q@n']);
    expect(r.first.state, UpdateState.unknown);
    expect(r.last.state, UpdateState.needed);
  });

  test('skillCount', () async {
    _install('p@m', '1.0', skills: 2);
    _market('m', [
      {'name': 'p', 'version': '1.1', 'source': './'},
    ]);
    expect((await checkUpdates(claude)).single.skillCount, 2);
  });

  test('noInstalledJson', () async {
    expect(await checkUpdates(claude), isEmpty);
  });

  test('같은 전역 스킬이 CLI와 앱 설치 기록에 다 있으면 CLI 항목만 남긴다', () {
    PluginUpdate u(String id, UpdateKind kind, {String? project}) => PluginUpdate(
      id: id,
      scope: 'user',
      current: '',
      latest: null,
      skillCount: 1,
      state: UpdateState.needed,
      kind: kind,
      projectPath: project,
    );
    final out = withoutDuplicateApp([
      u('foo', UpdateKind.skill),
      u('owner/repo/foo', UpdateKind.app),
      u('owner/repo/bar', UpdateKind.app),
      u('baz', UpdateKind.skill, project: '/p'),
      u('owner/repo/baz', UpdateKind.app),
    ]);
    expect(out.map((p) => p.id), [
      'foo',
      'owner/repo/bar',
      'baz',
      'owner/repo/baz',
    ]);
  });
}
