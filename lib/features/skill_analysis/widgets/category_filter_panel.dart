import 'package:flutter/material.dart';

import '../../../ui/app_checkbox.dart';
import '../skill_categories.dart';

/// 카테고리 체크박스 목록. 전체 카테고리를 사이트 순서로 보여 주고, 옆에 내 스킬 수를 붙인다.
class CategoryFilterPanel extends StatelessWidget {
  const CategoryFilterPanel({
    super.key,
    required this.counts,
    required this.selected,
    required this.onChanged,
    this.pendingCount = 0,
  });

  /// slug → 스킬 수.
  final Map<String, int> counts;
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;

  /// 아직 분석 중인 스킬 수.
  final int pendingCount;

  static const _sub = Color(0xFF3A4658);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                '카테고리',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            // 자리를 항상 차지해, 버튼이 나타나도 아래 목록이 움직이지 않는다.
            Visibility(
              visible: selected.isNotEmpty,
              maintainSize: true,
              maintainAnimation: true,
              maintainState: true,
              maintainSemantics: false,
              maintainInteractivity: false,
              child: TextButton(
                onPressed: () => onChanged({}),
                child: const Text('선택 해제'),
              ),
            ),
          ],
        ),
        Wrap(
          spacing: 4,
          children: [
            for (final c in skillCategories)
              AppCheckbox(
                label: c.label,
                value: selected.contains(c.slug),
                onChanged: (on) => onChanged(
                  on ? {...selected, c.slug} : ({...selected}..remove(c.slug)),
                ),
                trailing: Text(
                  '${counts[c.slug] ?? 0}',
                  style: const TextStyle(fontSize: 12, color: _sub),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
