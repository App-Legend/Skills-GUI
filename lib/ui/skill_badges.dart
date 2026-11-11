import 'package:flutter/material.dart';

import '../features/scan/agent.dart';
import '../features/scan/skill.dart';

/// 에이전트 이름. 여럿이 함께 읽으면 개수로 줄인다.
String agentTag(Skill s) => s.agents.length == 1
    ? s.agents.single.label
    : '에이전트 ${s.agents.length}개 공용';

String sourceTag(Skill s) {
  // Claude Code 하나만 쓰는 스킬은 예전처럼 범위만 쓴다.
  final prefix = s.agents.length == 1 && s.agents.single == Agent.claude
      ? ''
      : '${agentTag(s)} ';
  return switch (s.source) {
    SkillSource.global => '$prefix전역',
    SkillSource.project => '$prefix프로젝트',
    SkillSource.synced => '동기화',
    SkillSource.plugin => s.plugin ?? '플러그인',
  };
}

/// 카드용: 플러그인은 버전까지.
String cardTag(Skill s) => s.pluginVersion == null
    ? sourceTag(s)
    : '${sourceTag(s)} ${s.pluginVersion}';

class SkillBadge extends StatelessWidget {
  final String text;
  final Color bg;
  final Color fg;

  const SkillBadge(
    this.text, {
    super.key,
    this.bg = const Color(0x1F0064D1),
    this.fg = const Color(0xFF004A9C),
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(fontSize: 12, color: fg),
    ),
  );
}
