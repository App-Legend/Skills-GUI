import 'package:flutter/material.dart';

import '../scan/skill.dart';

String sourceTag(Skill s) => switch (s.source) {
  SkillSource.global => '전역',
  SkillSource.synced => '동기화',
  SkillSource.plugin => s.plugin ?? '플러그인',
};

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
