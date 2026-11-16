import 'package:flutter/material.dart';

import '../skill_analysis.dart';
import 'collapsible_item.dart';

/// 한국어 분석 항목들. 내 스킬 상세와 랭킹 상세가 같이 쓴다.
/// 개요·이럴 때 사용·처리 방식·결과물, 접힌 포함된 구성·주의할 점.
class AnalysisSections extends StatelessWidget {
  const AnalysisSections(this.analysis, {super.key, this.overview = true});

  final SkillAnalysis analysis;

  /// false면 개요를 빼고 그린다(개요를 따로 보여 줄 때).
  final bool overview;

  @override
  Widget build(BuildContext context) {
    final a = analysis;
    final items = [
      if (overview) _item('개요', [a.overview]),
      _item('이럴 때 사용', a.whenToUse),
      _item('처리 방식', a.workflow),
      _item('결과물', a.outputs),
      _item('포함된 구성', [
        for (final c in a.contents) '${c.path}: ${c.role}',
      ], collapsible: true),
      _item('주의할 점', a.cautions, collapsible: true),
    ].whereType<Widget>().toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < items.length; i++)
          Padding(
            padding: EdgeInsets.only(top: i == 0 ? 0 : 12),
            child: items[i],
          ),
      ],
    );
  }

  static Widget? _item(
    String title,
    List<String> items, {
    bool collapsible = false,
  }) {
    final list = items.where((s) => s.trim().isNotEmpty).toList();
    if (list.isEmpty) return null;
    final body = list.length == 1
        ? Text(list.single)
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final item in list)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text('• $item'),
                ),
            ],
          );
    if (collapsible) return CollapsibleItem(title: title, child: body);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        body,
      ],
    );
  }
}
