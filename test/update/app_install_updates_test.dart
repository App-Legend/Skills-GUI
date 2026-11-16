import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:skill_gui/features/ranking/data/ranking_api_client.dart';
import 'package:skill_gui/features/ranking/install/app_install_records.dart';
import 'package:skill_gui/features/ranking/install/skill_installer.dart';
import 'package:skill_gui/features/ranking/models/ranking_models.dart';
import 'package:skill_gui/features/scan/agent.dart';
import 'package:skill_gui/features/update/app_install_updates.dart';
import 'package:skill_gui/features/update/update_check.dart';

// 테스트용 가짜 스킬. 실제 skills.sh 데이터가 아니다.
SkillDetail _detail(String body, {String? hash}) => SkillDetail(
  id: 'fake/repo/fake-skill',
  source: 'fake/repo',
  slug: 'fake-skill',
  installs: 1,
  hash: hash,
  files: [SkillFile(path: 'SKILL.md', contents: '---\nname: fake\n---\n$body')],
);

/// 확인 결과 스트림을 한 결과로 모은다.
Future<({List<PluginUpdate> found, List<String> errors})> _all(
  Stream<({List<PluginUpdate> found, List<String> errors})> s,
) async {
  final parts = await s.toList();
  return (
    found: [for (final p in parts) ...p.found],
    errors: [for (final p in parts) ...p.errors],
  );
}

void main() {
  late Directory home;
  late SkillInstaller installer;

  setUp(() {
    home = Directory.systemTemp.createTempSync('app-install-test');
    installer = SkillInstaller(home: home.path);
  });
  tearDown(() => home.deleteSync(recursive: true));

  test('앱으로 설치하면 기록이 남고, 같은 에이전트·이름은 하나로 바뀐다', () async {
    await installer.install(_detail('v1', hash: 'h1'), Agent.cursor);
    await installer.install(
      _detail('v2', hash: 'h2'),
      Agent.cursor,
      overwrite: true,
    );
    await installer.install(_detail('v2', hash: 'h2'), Agent.claude);

    final records = await AppInstallRecords.forHome(home.path).load();
    expect(records.map((r) => (r.agent, r.hash)), [
      (Agent.cursor, 'h2'),
      (Agent.claude, 'h2'),
    ]);
  });

  test('해시가 바뀐 스킬만 업데이트 목록에 나오고, 업데이트하면 내용이 바뀐다', () async {
    await installer.install(_detail('v1', hash: 'h1'), Agent.cursor);
    final latest = _detail('v2', hash: 'h2');
    final updater = AppInstallUpdater(
      installer: installer,
      fetchDetail: (_) async => latest,
    );

    final r = await _all(updater.check());
    expect(r.errors, isEmpty);
    final u = r.found.single;
    expect(
      (u.kind, u.agent, u.id),
      (UpdateKind.app, Agent.cursor, 'fake/repo/fake-skill'),
    );

    expect(await updater.update(u), isNull);
    final md = File(
      [
        installer.targetPath(Agent.cursor, 'fake-skill'),
        'SKILL.md',
      ].join(Platform.pathSeparator),
    ).readAsStringSync();
    expect(md, endsWith('v2'));

    // 업데이트 뒤에는 기록 해시도 바뀌어 다시 나오지 않는다.
    expect((await _all(updater.check())).found, isEmpty);
  });

  test('해시가 없으면 파일 내용으로 비교합니다', () async {
    await installer.install(_detail('v1'), Agent.claude);
    final same = AppInstallUpdater(
      installer: installer,
      fetchDetail: (_) async => _detail('v1'),
    );
    expect((await _all(same.check())).found, isEmpty);
    final changed = AppInstallUpdater(
      installer: installer,
      fetchDetail: (_) async => _detail('v2'),
    );
    expect((await _all(changed.check())).found, hasLength(1));
  });

  test('지운 스킬은 확인하지 않고, 받기 실패는 숨기지 않습니다', () async {
    await installer.install(_detail('v1', hash: 'h1'), Agent.claude);
    await installer.install(_detail('v1', hash: 'h1'), Agent.codex);
    Directory(installer.targetPath(Agent.codex, 'fake-skill'))
        .deleteSync(recursive: true);
    final updater = AppInstallUpdater(
      installer: installer,
      fetchDetail: (_) async => throw const RankingApiException(502, '서버 오류'),
    );
    final r = await _all(updater.check());
    expect(r.found, isEmpty);
    expect(r.errors.single, allOf(contains('Claude Code'), contains('서버 오류')));
  });
}
