import 'dart:io';

import '../features/ranking/data/ranking_api_client.dart';
import '../features/ranking/install/app_install_records.dart';
import '../features/ranking/install/skill_installer.dart';
import '../features/ranking/models/ranking_models.dart';
import 'update_check.dart';

/// 앱의 설치 버튼으로 설치한 스킬의 업데이트 확인·실행.
/// skills.sh 최신 내용 해시를 설치 때 기록한 해시와 비교하고, 업데이트는 같은 설치기로 덮어쓴다.
class AppInstallUpdater implements SkillUpdateSource {
  AppInstallUpdater({required this.installer, required this.fetchDetail});

  final SkillInstaller installer;
  final Future<SkillDetail> Function(String id) fetchDetail;

  @override
  UpdateKind get kind => UpdateKind.app;

  @override
  Future<({List<PluginUpdate> found, List<String> errors})> check() async {
    final home = installer.home;
    if (home == null) return (found: <PluginUpdate>[], errors: <String>[]);
    final records = await AppInstallRecords.forHome(home).load();
    final results = await Future.wait(records.map(_checkOne));
    return (
      found: [for (final r in results) ?r.$1],
      errors: [for (final r in results) ?r.$2],
    );
  }

  Future<(PluginUpdate?, String?)> _checkOne(AppInstallRecord r) async {
    try {
      // 지운 스킬은 확인하지 않는다.
      if (!await installer.exists(r.agent, r.slug)) return (null, null);
      final latest = await fetchDetail(r.id);
      if (!await _changed(r, latest)) return (null, null);
      return (
        PluginUpdate(
          id: r.id,
          scope: 'user',
          current: '',
          latest: null,
          skillCount: 1,
          state: UpdateState.needed,
          kind: UpdateKind.app,
          agent: r.agent,
        ),
        null,
      );
    } on Object catch (e) {
      final why = e is RankingApiException
          ? e.message
          : e is SkillInstallException
          ? e.message
          : '$e';
      return (null, '${r.slug} (${r.agent.label}): 확인하지 못했습니다 ($why)');
    }
  }

  /// 해시가 둘 다 있으면 해시로, 아니면 받은 파일과 설치된 파일 내용을 비교한다.
  Future<bool> _changed(AppInstallRecord r, SkillDetail latest) async {
    final old = r.hash, now = latest.hash;
    if (old != null && now != null) return old != now;
    final dir = installer.targetPath(r.agent, r.slug);
    for (final f in latest.files) {
      final contents = f.contents;
      if (contents == null) continue; // 그림 같은 파일은 설치 때도 건너뛰었다.
      final local = File(
        '$dir${Platform.pathSeparator}${f.path.replaceAll('/', Platform.pathSeparator)}',
      );
      if (!await local.exists() || await local.readAsString() != contents) {
        return true;
      }
    }
    return false;
  }

  @override
  Future<String?> update(PluginUpdate u) async {
    final agent = u.agent;
    if (agent == null) return '설치한 에이전트를 알 수 없습니다';
    try {
      await installer.install(await fetchDetail(u.id), agent, overwrite: true);
      return null;
    } on RankingApiException catch (e) {
      return '최신 파일을 받지 못했습니다: ${e.message}';
    } on SkillInstallException catch (e) {
      return e.message;
    }
  }
}
