import 'dart:io';

import '../../scan/agent.dart';
import '../models/ranking_models.dart';
import 'app_install_records.dart';

/// 스킬을 설치할 에이전트. 폴더는 skills CLI(`npx skills add -g`)와 같은 곳을 쓴다.
/// 에이전트 목록은 스캔과 같은 표([Agent])를 쓴다.
typedef InstallTarget = Agent;

/// 설치를 막는 문제. [message] 를 그대로 화면에 보인다.
class SkillInstallException implements Exception {
  const SkillInstallException(this.message);

  final String message;

  @override
  String toString() => 'SkillInstallException: $message';
}

/// 설치 결과.
class SkillInstallResult {
  const SkillInstallResult({
    required this.directory,
    required this.written,
    required this.skipped,
  });

  final String directory;
  final int written;

  /// 내용이 없어 쓰지 못한 파일 경로들 (그림 같은 바이너리).
  final List<String> skipped;
}

final _segment = RegExp(r'^[A-Za-z0-9_.-]+$');

/// skills.sh 에서 받은 파일을 에이전트 스킬 폴더에 쓴다.
///
/// 파일 경로는 스킬 폴더 밖으로 나가지 못하게 검사한다.
/// 먼저 임시 폴더에 다 쓴 뒤 옮기므로, 중간에 실패해도 기존 스킬이 반쯤 망가지지 않는다.
class SkillInstaller {
  SkillInstaller({String? home})
    : home =
          home ??
          Platform.environment['USERPROFILE'] ??
          Platform.environment['HOME'];

  /// 홈 폴더. 찾지 못하면 null 이고 설치할 수 없다.
  final String? home;

  String get _sep => Platform.pathSeparator;

  /// [target] 에 [slug] 를 설치할 폴더 경로.
  String targetPath(InstallTarget target, String slug) {
    final base = home;
    if (base == null) {
      throw const SkillInstallException('홈 폴더를 찾지 못해 설치할 수 없습니다.');
    }
    if (!_segment.hasMatch(slug) || slug == '.' || slug == '..') {
      throw SkillInstallException('스킬 이름이 폴더 이름으로 쓸 수 없는 형식입니다: $slug');
    }
    return [base, ...target.homeParts, slug].join(_sep);
  }

  /// 이미 같은 이름의 스킬 폴더가 있는지.
  Future<bool> exists(InstallTarget target, String slug) =>
      Directory(targetPath(target, slug)).exists();

  /// [detail] 의 파일을 설치한다. 폴더가 이미 있으면 [overwrite] 가 true 일 때만 바꾼다.
  Future<SkillInstallResult> install(
    SkillDetail detail,
    InstallTarget target, {
    bool overwrite = false,
  }) async {
    final dest = Directory(targetPath(target, detail.slug));
    if (detail.skillMd == null) {
      throw const SkillInstallException('SKILL.md 가 없어 설치할 수 없습니다.');
    }
    if (await dest.exists() && !overwrite) {
      throw SkillInstallException(
        '${target.displayPath(detail.slug)} 에 같은 이름의 스킬이 이미 있습니다.',
      );
    }

    final files = <(List<String>, String)>[];
    final skipped = <String>[];
    for (final file in detail.files) {
      final parts = _safeParts(file.path);
      final contents = file.contents;
      if (contents == null) {
        skipped.add(file.path);
      } else {
        files.add((parts, contents));
      }
    }

    await dest.parent.create(recursive: true);
    final stamp = DateTime.now().microsecondsSinceEpoch;
    // 임시 폴더는 '.'으로 시작해 스캔에서 스킬로 잡히지 않게 한다.
    String hidden(String kind) =>
        [dest.parent.path, '.${detail.slug}.$kind-$stamp'].join(_sep);
    final temp = Directory(hidden('installing'));
    try {
      for (final (parts, contents) in files) {
        final out = File([temp.path, ...parts].join(_sep));
        await out.parent.create(recursive: true);
        await out.writeAsString(contents);
      }
      if (await dest.exists()) {
        final old = Directory(hidden('old'));
        await dest.rename(old.path);
        try {
          await temp.rename(dest.path);
        } on FileSystemException {
          // 새 폴더를 못 옮겼으면 옛 스킬을 제자리에 되돌린다.
          await old.rename(dest.path);
          rethrow;
        }
        // 교체는 끝났다. 옛 폴더를 못 지워도 숨김 폴더로 남을 뿐이라 실패로 보지 않는다.
        try {
          await old.delete(recursive: true);
        } on FileSystemException {
          // 무시
        }
      } else {
        await temp.rename(dest.path);
      }
    } on FileSystemException catch (e) {
      if (await temp.exists()) await temp.delete(recursive: true);
      throw SkillInstallException('파일을 쓰지 못했습니다: ${e.message} (${e.path})');
    }

    // 업데이트 확인용 기록. 실패해도 설치는 끝났으니 설치를 실패로 돌리지 않는다.
    try {
      await AppInstallRecords.forHome(home!).put(
        AppInstallRecord(
          id: detail.id,
          slug: detail.slug,
          agent: target,
          hash: detail.hash,
        ),
      );
    } on Object {
      // 기록이 없으면 이 스킬은 업데이트 목록에 안 나올 뿐이다.
    }

    return SkillInstallResult(
      directory: dest.path,
      written: files.length,
      skipped: skipped,
    );
  }

  /// `a/b.md` 를 [a, b.md] 로. 절대 경로·`..`·드라이브 문자는 거절한다.
  static List<String> _safeParts(String path) {
    final normalized = path.replaceAll('\\', '/');
    final parts = normalized.split('/').where((p) => p.isNotEmpty).toList();
    final bad =
        normalized.startsWith('/') ||
        parts.isEmpty ||
        parts.any((p) => p == '..' || p == '.' || p.contains(':'));
    if (bad) {
      throw SkillInstallException('안전하지 않은 파일 경로가 있어 설치를 멈췄습니다: $path');
    }
    return parts;
  }
}
