import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:skill_gui/scan/skill.dart';
import 'package:skill_gui/scan/skill_scanner.dart';

void main() {
  late Directory root;
  late Directory claude;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('scan_test');
    claude = await Directory('${root.path}/.claude').create();
  });
  tearDown(() => root.delete(recursive: true));

  Future<void> file(String rel, String content) async {
    final f = File('${claude.path}/$rel');
    await f.parent.create(recursive: true);
    await f.writeAsString(content);
  }

  Skill byName(ScanResult r, String n) =>
      r.skills.firstWhere((s) => s.name == n);

  test('globalSkill', () async {
    const md = '---\nname: a\ndescription: d\n---\nbody\n';
    await file('skills/a/SKILL.md', md);
    await file('skills/a/scripts/run.sh', 'x');
    final s = byName(await scanClaude(claude), 'a');
    expect(s.source, SkillSource.global);
    expect(s.description, 'd');
    expect(s.files, ['SKILL.md', 'scripts/run.sh']);
    expect(s.problem, isNull);
    expect(s.skillMd, md);
  });

  test('noSkillMd', () async {
    await Directory('${claude.path}/skills/b').create(recursive: true);
    final s = byName(await scanClaude(claude), 'b');
    expect(s.problem!.kind, ProblemKind.noSkillMd);
  });

  test('badFrontmatter', () async {
    await file('skills/e/SKILL.md', 'no header');
    final s = byName(await scanClaude(claude), 'e');
    expect(s.problem!.kind, ProblemKind.badFrontmatter);
    expect(s.skillMd, 'no header');
  });

  test('bomSkillMd', () async {
    await file('skills/bom/SKILL.md', '﻿---\nname: bom\ndescription: d\n---\n');
    final s = byName(await scanClaude(claude), 'bom');
    expect(s.problem, isNull);
    expect(s.description, 'd');
  });

  test('missing name uses folder name', () async {
    await file('skills/f/SKILL.md', '---\ndescription: d\n---\n');
    final s = byName(await scanClaude(claude), 'f');
    expect(s.problem, isNull);
  });

  test('linkedSkill', () async {
    final target = await Directory('${root.path}/elsewhere').create();
    await File('${target.path}/SKILL.md')
        .writeAsString('---\nname: c\ndescription: d\n---\n');
    await Directory('${claude.path}/skills').create(recursive: true);
    await Link('${claude.path}/skills/c').create(target.path);
    final s = byName(await scanClaude(claude), 'c');
    expect(s.problem, isNull);
    expect(s.linkTarget, target.path);
    expect(s.files, ['SKILL.md']);
  });

  test('brokenLink', () async {
    await Directory('${claude.path}/skills').create(recursive: true);
    final missing = '${root.path}/nope';
    await Link('${claude.path}/skills/d').create(missing);
    final s = byName(await scanClaude(claude), 'd');
    expect(s.problem!.kind, ProblemKind.brokenLink);
    expect(s.linkTarget, missing);
  });

  test('synced', () async {
    await file('skills/synced/acc1/docx/SKILL.md', 'x');
    final r = await scanClaude(claude);
    expect(r.skills, hasLength(1));
    final s = r.skills.single;
    expect(s.name, 'synced');
    expect(s.source, SkillSource.synced);
    expect(s.description, 'claude.ai에서 동기화된 스킬 폴더');
    expect(s.problem, isNull);
    expect(s.files, contains('acc1/docx/SKILL.md'));
  });

  test('noSkillsDir', () async {
    final r = await scanClaude(claude);
    expect(r.skills, isEmpty);
  });

  test('fileSkippedAtTopLevel', () async {
    await file('skills/.DS_Store', 'x');
    expect((await scanClaude(claude)).skills, isEmpty);
  });

  test('classifyFsError', () {
    FileSystemException e(int c) =>
        FileSystemException('x', 'p', OSError('', c));
    expect(classifyFsError(e(1)), ProblemKind.noPermission);
    expect(classifyFsError(e(13)), ProblemKind.noPermission);
    expect(classifyFsError(e(2)), ProblemKind.unreadable);
  });
}
