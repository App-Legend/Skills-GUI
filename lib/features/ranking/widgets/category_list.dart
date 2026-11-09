import 'package:flutter/material.dart';

import '../../../ui/glass.dart';
import '../category/skill_category.dart';

const _ink = Color(0xFF101828);
const _sub = Color(0xFF3A4658);
const _blue = Color(0xFF0064D1);

/// 랭킹 왼쪽의 분야 목록. 한 줄에 분야 이름과 지금 목록에서의 개수를 보인다.
///
/// [selected] 가 null 이면 "모든 분야" 가 선택된 것이다.
/// 개수가 0 인 분야는 흐리게 보이지만 누를 수는 있다.
class CategoryList extends StatelessWidget {
  const CategoryList({
    super.key,
    required this.counts,
    required this.total,
    required this.selected,
    required this.onSelect,
  });

  final Map<SkillCategory, int> counts;
  final int total;
  final SkillCategory? selected;
  final ValueChanged<SkillCategory?> onSelect;

  @override
  Widget build(BuildContext context) => GlassPanel(
    radius: 24,
    child: ListView(
      padding: const EdgeInsets.all(8),
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(12, 4, 12, 8),
          child: Text(
            '분야',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _sub,
            ),
          ),
        ),
        _row(
          key: const Key('ranking-category-all'),
          label: '모든 분야',
          count: total,
          isSelected: selected == null,
          onTap: () => onSelect(null),
        ),
        const Divider(height: 12, indent: 12, endIndent: 12),
        for (final category in SkillCategory.values)
          _row(
            key: Key('ranking-category-${category.name}'),
            label: category.label,
            count: counts[category] ?? 0,
            isSelected: selected == category,
            onTap: () => onSelect(category),
          ),
      ],
    ),
  );

  Widget _row({
    required Key key,
    required String label,
    required int count,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final dim = count == 0 && !isSelected;
    return Semantics(
      key: key,
      selected: isSelected,
      button: true,
      child: Material(
        color: isSelected ? const Color(0xE6FFFFFF) : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 36),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: dim ? _sub.withValues(alpha: 0.55) : _ink,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? _blue
                          : (dim ? _sub.withValues(alpha: 0.55) : _sub),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
