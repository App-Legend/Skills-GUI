import 'dart:convert';
import 'dart:io';

import 'frontmatter.dart';
import 'skill.dart';

const _messages = {
  ProblemKind.noSkillMd: 'SKILL.md가 없습니다',
  ProblemKind.badFrontmatter: 'SKILL.md 머리말을 읽을 수 없습니다',
  ProblemKind.noPermission: '읽을 수 없음, 권한 없음',
  ProblemKind.brokenLink: '링크가 가리키는 폴더가 없습니다',
};

SkillProblem _problem(ProblemKind kind, [String? detail]) =>
    SkillProblem(kind, _messages[kind] ?? '읽을 수 없습니다: $detail');

/// EPERM(1)·EACCES(13)은 권한 문제, 나머지는 읽기 실패.
ProblemKind classifyFsError(FileSystemException e) {
  final code = e.osError?.errorCode;
  return code == 1 || code == 13
      ? ProblemKind.noPermission
      : ProblemKind.unreadable;
}

SkillProblem _fsProblem(FileSystemException e) =>
    _problem(classifyFsError(e), e.osError?.message ?? e.message);

/// 링크 대상 경로. 상대 경로면 링크가 있는 폴더 기준. Uri를 쓰지 않아 Windows 경로도 안전하다.
/// shortcut: `..`는 정리하지 않는다. 파일 시스템이 처리하므로 표시만 길어진다.
String resolveLinkTarget(String linkPath, String raw) => File(raw).isAbsolute
    ? raw
    : '${File(linkPath).parent.path}${Platform.pathSeparator}$raw';

/// 링크 대상을 읽다 난 오류: 없음(ENOENT 2, Windows 3)은 끊긴 링크, 나머지는 일반 분류.
ProblemKind classifyLinkError(FileSystemException e) {
  final code = e.osError?.errorCode;
  return code == 2 || code == 3
      ? ProblemKind.brokenLink
      : classifyFsError(e);
}

String _baseName(String path) =>
    path.split(RegExp(r'[/\\]')).where((p) => p.isNotEmpty).last;

/// 폴더 아래 파일의 상대 경로(`/` 구분, 정렬).
Future<List<String>> _listFiles(Directory dir) async {
  final files = <String>[];
  await for (final e in dir.list(recursive: true, followLinks: false)) {
    if (e is File) {
      files.add(e.path.substring(dir.path.length + 1).replaceAll('\\', '/'));
    }
  }
  return files..sort();
}

/// 폴더 하나를 Skill로 읽는다. 예외를 밖으로 던지지 않는다.
Future<Skill> readSkillDir(
  String path, {
  required SkillSource source,
  String? plugin,
  String? pluginVersion,
  bool? pluginEnabled,
  String? projectPath,
  Future<List<String>> Function(Directory)? listFiles,
}) async {
  listFiles ??= _listFiles;
  final name = _baseName(path);
  Skill make({
    String? description,
    String? linkTarget,
    String? skillMd,
    List<String> files = const [],
    SkillProblem? problem,
    String? skillName,
  }) => Skill(
    name: skillName ?? name,
    description: description,
    source: source,
    plugin: plugin,
    pluginVersion: pluginVersion,
    pluginEnabled: pluginEnabled,
    projectPath: projectPath,
    path: path,
    linkTarget: linkTarget,
    skillMd: skillMd,
    files: files,
    problem: problem,
  );

  String? linkTarget;
  try {
    if (FileSystemEntity.typeSync(path, followLinks: false) ==
        FileSystemEntityType.link) {
      final raw = await Link(path).target();
      linkTarget = resolveLinkTarget(path, raw);
    }
    final dir = Directory(linkTarget ?? path);
    final files = await listFiles(dir);
    final md = File('${dir.path}/SKILL.md');
    if (!md.existsSync()) {
      return make(
        linkTarget: linkTarget,
        files: files,
        problem: _problem(ProblemKind.noSkillMd),
      );
    }
    final String text;
    try {
      text = await md.readAsString();
    } on FormatException catch (e) {
      return make(
        linkTarget: linkTarget,
        files: files,
        problem: _problem(ProblemKind.unreadable, e.message),
      );
    }
    try {
      final fm = parseFrontmatter(text.replaceFirst('﻿', ''));
      return make(
        skillName: fm.name,
        description: fm.description,
        linkTarget: linkTarget,
        skillMd: text,
        files: files,
      );
    } on FormatException {
      return make(
        linkTarget: linkTarget,
        skillMd: text,
        files: files,
        problem: _problem(ProblemKind.badFrontmatter),
      );
    }
  } on FileSystemException catch (e) {
    // 샌드박스 밖 대상은 existsSync가 false라서, 실제 오류로 구분한다.
    final kind = linkTarget == null ? classifyFsError(e) : classifyLinkError(e);
    return make(
      linkTarget: linkTarget,
      problem: _problem(kind, e.osError?.message ?? e.message),
    );
  } on Object catch (e) {
    return make(linkTarget: linkTarget, problem: _problem(ProblemKind.unreadable, '$e'));
  }
}

/// 전역 스킬, synced 폴더, 플러그인 스킬을 읽는다.
Future<ScanResult> scanClaude(Directory claudeDir) async {
  final skills = <Skill>[];
  final notices = <String>[];

  final skillsDir = Directory('${claudeDir.path}/skills');
  if (skillsDir.existsSync()) {
    try {
      await for (final e in skillsDir.list(followLinks: false)) {
        final name = _baseName(e.path);
        final isDir =
            e is Directory ||
            (e is Link && FileSystemEntity.isDirectorySync(e.path)) ||
            (e is Link && !File(e.path).existsSync());
        if (!isDir) continue;
        if (name == 'synced') {
          skills.add(await _readSynced(e.path));
        } else {
          skills.add(await readSkillDir(e.path, source: SkillSource.global));
        }
      }
    } on FileSystemException catch (e) {
      notices.add(_fsProblem(e).message);
    }
  }
  skills.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  skills.addAll(await _scanPlugins(claudeDir, notices));
  return ScanResult(skills: skills, notices: notices);
}

Future<Skill> _readSynced(String path) async {
  var files = <String>[];
  SkillProblem? problem;
  try {
    files = await _listFiles(Directory(path));
  } on FileSystemException catch (e) {
    problem = _fsProblem(e);
  }
  return Skill(
    name: 'synced',
    description: 'claude.ai에서 동기화된 스킬 폴더',
    source: SkillSource.synced,
    path: path,
    files: files,
    problem: problem,
  );
}

/// `installed_plugins.json`의 모든 항목을 읽는다. 예외를 밖으로 던지지 않는다.
Future<List<Skill>> _scanPlugins(
  Directory claudeDir,
  List<String> notices,
) async {
  const badJson = 'installed_plugins.json을 읽지 못했습니다';
  const badEntry = 'installed_plugins.json 항목을 읽지 못했습니다';
  final out = <Skill>[];
  final installed = File('${claudeDir.path}/plugins/installed_plugins.json');
  if (!installed.existsSync()) return out;
  try {
    final plugins =
        (jsonDecode(await installed.readAsString())
                as Map<String, dynamic>)['plugins']
            as Map<String, dynamic>;

    // null이면 settings.json을 못 읽은 것.
    Map<String, dynamic>? enabled;
    try {
      final j = jsonDecode(
        await File('${claudeDir.path}/settings.json').readAsString(),
      ) as Map<String, dynamic>;
      enabled = (j['enabledPlugins'] as Map<String, dynamic>?) ?? {};
    } on Object {
      enabled = null;
    }

    final oldDirs = <String>{};
    // 설치된 모든 항목의 폴더명(부모 폴더별). 이들은 옛 버전이 아니다.
    final installedBases = <String, Set<String>>{};
    for (final list in plugins.values) {
      if (list is! List) continue;
      for (final raw in list) {
        final p = raw is Map ? raw['installPath'] : null;
        if (p is String) {
          installedBases
              .putIfAbsent(Directory(p).parent.path, () => {})
              .add(_baseName(p));
        }
      }
    }
    var settingsNotice = false;
    for (final id in plugins.keys.toList()..sort()) {
      final List<dynamic> list;
      try {
        list = plugins[id] as List<dynamic>;
      } on Object {
        notices.add('$id: $badEntry');
        continue;
      }
      for (final raw in list) {
        try {
          final entry = raw as Map<String, dynamic>;
          final installPath = entry['installPath'] as String;
          final isProject = entry['scope'] == 'project';
          final bool? on = isProject || enabled == null
              ? null
              : enabled[id] == true;
          if (!isProject && enabled == null) settingsNotice = true;

          final dir = Directory(installPath);
          if (!dir.existsSync()) {
            notices.add('$id: 플러그인 폴더가 없습니다');
            continue;
          }
          // 같은 플러그인 폴더를 쓰는 항목이 여럿이어도 한 번만 센다.
          final keep = installedBases[dir.parent.path] ?? {_baseName(installPath)};
          try {
            await for (final sib in dir.parent.list(followLinks: false)) {
              if (sib is Directory && !keep.contains(_baseName(sib.path))) {
                oldDirs.add(sib.path);
              }
            }
            final skillsDir = Directory('$installPath/skills');
            if (!skillsDir.existsSync()) continue;
            await for (final e in skillsDir.list(followLinks: false)) {
              if (e is! Directory && e is! Link) continue;
              out.add(
                await readSkillDir(
                  e.path,
                  source: SkillSource.plugin,
                  plugin: id,
                  pluginVersion: entry['version'] as String?,
                  pluginEnabled: on,
                  projectPath: entry['projectPath'] as String?,
                ),
              );
            }
          } on FileSystemException catch (e) {
            notices.add('$id: ${_fsProblem(e).message}');
          }
        } on Object {
          // 항목 하나가 깨져도 나머지는 계속 읽는다.
          notices.add('$id: $badEntry');
        }
      }
    }
    if (settingsNotice) {
      notices.add('settings.json을 읽지 못해 플러그인 켜짐 여부를 알 수 없습니다');
    }
    if (oldDirs.isNotEmpty) {
      notices.add('플러그인 옛 버전 폴더 ${oldDirs.length}개가 남아 있습니다');
    }
  } on Object {
    // 최상위 형식 불일치·읽기 실패.
    notices.add(badJson);
  }
  out.sort((a, b) {
    final c = a.plugin!.compareTo(b.plugin!);
    return c != 0 ? c : a.name.toLowerCase().compareTo(b.name.toLowerCase());
  });
  return out;
}
