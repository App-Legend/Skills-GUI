import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:skill_gui/features/skill_delete/skill_deleter.dart';
import 'package:skill_gui/scan/skill.dart';

void main() {
  late Directory root;
  setUp(() async => root = await Directory.systemTemp.createTemp('skill-del-'));
  tearDown(() => root.delete(recursive: true));

  test('플러그인·동기화 스킬은 지울 수 없습니다', () {
    final plugin = planSkillDelete(
      const Skill(
        name: 'p',
        source: SkillSource.plugin,
        plugin: 'a@m',
        path: '/c/skills/p',
      ),
    );
    expect(plugin.canDelete, isFalse);
    expect(plugin.blockedReason, contains('/plugin uninstall a@m'));
    expect(
      planSkillDelete(
        const Skill(name: 's', source: SkillSource.synced, path: '/c/synced'),
      ).canDelete,
      isFalse,
    );
  });

  test('skills 폴더 밖이면 지우지 않습니다', () {
    final plan = planSkillDelete(
      const Skill(name: 'x', source: SkillSource.global, path: '/home/x'),
    );
    expect(plan.canDelete, isFalse);
  });

  test('전역 스킬 폴더를 통째로 지웁니다', () async {
    final dir = Directory('${root.path}/skills/alpha')
      ..createSync(recursive: true);
    File('${dir.path}/SKILL.md').writeAsStringSync('x');
    final plan = planSkillDelete(
      Skill(name: 'alpha', source: SkillSource.global, path: dir.path),
    );
    expect(plan.canDelete, isTrue);
    await deleteSkill(plan);
    expect(dir.existsSync(), isFalse);
  });

  test('링크는 링크만 지우고 원본은 남긴다', () async {
    final original = Directory('${root.path}/agents/beta')
      ..createSync(recursive: true);
    File('${original.path}/SKILL.md').writeAsStringSync('x');
    Directory('${root.path}/skills').createSync();
    final linkPath = '${root.path}/skills/beta';
    Link(linkPath).createSync(original.path);
    final plan = planSkillDelete(
      Skill(
        name: 'beta',
        source: SkillSource.global,
        path: linkPath,
        linkTarget: original.path,
      ),
    );
    expect(plan.isLink, isTrue);
    await deleteSkill(plan);
    expect(
      FileSystemEntity.typeSync(linkPath, followLinks: false),
      FileSystemEntityType.notFound,
    );
    expect(File('${original.path}/SKILL.md').existsSync(), isTrue);
  });
}
