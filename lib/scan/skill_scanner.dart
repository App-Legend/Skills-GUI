import 'dart:io';

import 'frontmatter.dart';
import 'skill.dart';

const _messages = {
  ProblemKind.noSkillMd: 'SKILL.md가 없습니다',
  ProblemKind.badFrontmatter: 'SKILL.md 머리말을 읽을 수 없습니다',
  ProblemKind.noPermission: '읽을 수 없음, 폴더 권한 필요',
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
}) async {
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
      linkTarget = raw.startsWith('/')
          ? raw
          : File(path).parent.uri.resolve(raw).toFilePath();
      if (!Directory(linkTarget).existsSync()) {
        return make(
          linkTarget: linkTarget,
          problem: _problem(ProblemKind.brokenLink),
        );
      }
    }
    final dir = Directory(linkTarget ?? path);
    final files = await _listFiles(dir);
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
    return make(linkTarget: linkTarget, problem: _fsProblem(e));
  }
}

/// `<claude>/skills/`의 전역 스킬과 synced 폴더를 읽는다.
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
