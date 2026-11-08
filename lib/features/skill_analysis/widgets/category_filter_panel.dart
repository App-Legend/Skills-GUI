import 'package:flutter/material.dart';

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
            if (selected.isNotEmpty)
              TextButton(
                onPressed: () => onChanged({}),
                child: const Text('선택 해제'),
              ),
          ],
        ),
        Wrap(
          spacing: 4,
          children: [
            for (final c in skillCategories)
              _CategoryCheck(
                label: c.label,
                count: counts[c.slug] ?? 0,
                checked: selected.contains(c.slug),
                onChanged: (on) => onChanged(
                  on ? {...selected, c.slug} : ({...selected}..remove(c.slug)),
                ),
              ),
          ],
        ),
        if (pendingCount > 0)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '분석 중인 스킬 $pendingCount개는 끝나면 반영됩니다.',
              style: const TextStyle(fontSize: 12, color: _sub),
            ),
          ),
      ],
    );
  }
}

class _CategoryCheck extends StatelessWidget {
  const _CategoryCheck({
    required this.label,
    required this.count,
    required this.checked,
    required this.onChanged,
  });

  final String label;
  final int count;
  final bool checked;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Material(
    type: MaterialType.transparency,
    child: InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => onChanged(!checked),
      child: Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Checkbox(
              value: checked,
              onChanged: (v) => onChanged(v ?? false),
              visualDensity: VisualDensity.compact,
              semanticLabel: label,
            ),
            Text(label),
            const SizedBox(width: 4),
            Text(
              '$count',
              style: const TextStyle(
                fontSize: 12,
                color: CategoryFilterPanel._sub,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
