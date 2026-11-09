import 'package:flutter/material.dart';

import '../../../ui/skill_badges.dart';
import '../skill_categories.dart';

/// 카테고리 배지 한 줄. 넘치면 뒤쪽 배지가 줄어든다.
class CategoryBadges extends StatelessWidget {
  const CategoryBadges(this.slugs, {super.key});
  final List<String> slugs;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (final (i, slug) in slugs.indexed) ...[
        if (i > 0) const SizedBox(width: 4),
        Flexible(
          // 랭킹 카테고리 배지와 같은 파란색.
          child: SkillBadge(categoryLabel(slug)),
        ),
      ],
    ],
  );
}
