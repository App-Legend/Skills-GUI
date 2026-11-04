enum SkillSource { global, synced, plugin }

enum ProblemKind {
  noSkillMd,
  badFrontmatter,
  noPermission,
  brokenLink,
  unreadable,
}

class SkillProblem {
  final ProblemKind kind;

  /// 화면에 그대로 쓰는 한국어 문구.
  final String message;

  const SkillProblem(this.kind, this.message);
}

class Skill {
  final String name;
  final String? description;
  final SkillSource source;

  /// "<이름>@<마켓>"
  final String? plugin;
  final String? pluginVersion;

  /// 플러그인만: true 켜짐, false 꺼짐, null 모름.
  final bool? pluginEnabled;

  /// 프로젝트 범위 플러그인만.
  final String? projectPath;
  final String path;
  final String? linkTarget;
  final String? skillMd;
  final List<String> files;
  final SkillProblem? problem;

  const Skill({
    required this.name,
    this.description,
    required this.source,
    this.plugin,
    this.pluginVersion,
    this.pluginEnabled,
    this.projectPath,
    required this.path,
    this.linkTarget,
    this.skillMd,
    this.files = const [],
    this.problem,
  });
}

class ScanResult {
  final List<Skill> skills;
  final List<String> notices;

  const ScanResult({this.skills = const [], this.notices = const []});
}
