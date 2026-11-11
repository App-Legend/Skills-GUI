import 'dart:io';

import '../scan/skill.dart';

/// 삭제 전에 보여주는 계획. [blockedReason]이 있으면 지울 수 없다.
class SkillDeletePlan {
  const SkillDeletePlan._({
    this.target,
    this.isLink = false,
    this.keptOriginal,
    this.blockedReason,
  });

  /// 지울 경로(폴더 또는 링크).
  final String? target;

  /// true면 링크만 지우고 원본은 남긴다.
  final bool isLink;

  /// 링크일 때 남는 원본 경로.
  final String? keptOriginal;

  /// 지울 수 없는 이유. 화면에 그대로 쓴다.
  final String? blockedReason;

  bool get canDelete => blockedReason == null;
}

/// 스킬 하나를 지우는 계획을 세운다. 파일은 건드리지 않는다.
SkillDeletePlan planSkillDelete(Skill s) {
  switch (s.source) {
    case SkillSource.synced:
      return const SkillDeletePlan._(blockedReason: '동기화 폴더는 앱에서 지울 수 없습니다.');
    case SkillSource.plugin:
      return SkillDeletePlan._(
        blockedReason:
            '플러그인에 들어 있는 스킬은 하나만 지울 수 없습니다. '
            'Claude Code에서 /plugin uninstall ${s.plugin ?? '<플러그인>'} 으로 플러그인을 지웁니다.',
      );
    case SkillSource.global:
    case SkillSource.project:
      break;
  }
  // 안전장치: `skills` 폴더 바로 아래 항목만 지운다.
  final parts = s.path.split(RegExp(r'[/\\]')).where((p) => p.isNotEmpty);
  if (parts.length < 2 || parts.elementAt(parts.length - 2) != 'skills') {
    return const SkillDeletePlan._(
      blockedReason: 'skills 폴더 밖에 있는 스킬이라 앱에서 지우지 않습니다.',
    );
  }
  final link = s.linkTarget;
  return SkillDeletePlan._(
    target: s.path,
    isLink: link != null,
    keptOriginal: link,
  );
}

/// 계획대로 지운다. 실패하면 [FileSystemException]을 던진다.
/// 링크는 링크만 지우고 원본은 남긴다.
Future<void> deleteSkill(SkillDeletePlan plan) async {
  final target = plan.target;
  if (!plan.canDelete || target == null) {
    throw StateError(plan.blockedReason ?? '지울 대상이 없습니다.');
  }
  final type = await FileSystemEntity.type(target, followLinks: false);
  switch (type) {
    case FileSystemEntityType.link:
      await Link(target).delete();
    case FileSystemEntityType.directory:
      if (plan.isLink) {
        // 스캔 때는 링크였는데 지금은 폴더면 원본일 수 있어 지우지 않는다.
        throw FileSystemException('링크가 아니라 폴더로 바뀌어 지우지 않았습니다', target);
      }
      await Directory(target).delete(recursive: true);
    case FileSystemEntityType.notFound:
      return; // 이미 없다.
    default:
      throw FileSystemException('스킬 폴더가 아닙니다', target);
  }
}
