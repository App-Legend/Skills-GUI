import 'package:flutter/material.dart';

import '../../../ui/skill_badges.dart';

const _sub = Color(0xFF3A4658);
const _green = Color(0xFF067647);
const _red = Color(0xFFB42318);

/// 랭킹 항목 한 줄. 값만 받아 그린다.
///
/// [showChange] 가 true 이면 [change] 를 +/− 로 표시한다 (핫 뷰용).
/// [change] 가 null 이면 변화량 자리에 '-' 를 보인다.
class RankingListTile extends StatelessWidget {
  const RankingListTile({
    super.key,
    required this.rank,
    required this.name,
    required this.source,
    required this.installs,
    this.change,
    this.showChange = false,
    this.installed = false,
  });

  final int rank;
  final String name;
  final String source;
  final int installs;
  final int? change;
  final bool showChange;

  /// 내 스킬에 같은 이름이 있으면 "설치됨" 배지를 붙인다.
  final bool installed;

  /// 1234567 -> 1,234,567
  static String formatCount(int value) {
    final digits = value.abs().toString();
    final buffer = StringBuffer(value < 0 ? '-' : '');
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }

  /// 양수는 '+n', 음수는 '−n', 0 은 '0', 없으면 '-'.
  static String formatChange(int? change) {
    if (change == null) return '-';
    if (change > 0) return '+${formatCount(change)}';
    if (change < 0) return '−${formatCount(-change)}';
    return '0';
  }

  Color get _changeColor {
    final value = change;
    if (value == null || value == 0) return _sub;
    return value > 0 ? _green : _red;
  }

  @override
  Widget build(BuildContext context) => Padding(
    key: const Key('ranking-tile'),
    padding: const EdgeInsets.only(bottom: 12),
    child: Material(
      color: const Color(0xDBFFFFFF), // 흰색 0.86
      borderRadius: BorderRadius.circular(22),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            SizedBox(
              width: 48,
              child: Text(
                '$rank',
                key: const Key('ranking-tile-rank'),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: rank <= 3 ? const Color(0xFF0064D1) : _sub,
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          name,
                          key: const Key('ranking-tile-name'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      ),
                      if (installed) ...[
                        const SizedBox(width: 8),
                        const SkillBadge(
                          '설치됨',
                          key: Key('ranking-tile-installed'),
                          bg: Color(0x1F067647),
                          fg: _green,
                        ),
                      ],
                    ],
                  ),
                  Text(
                    source,
                    key: const Key('ranking-tile-source'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: _sub),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '설치 ${formatCount(installs)}',
                  key: const Key('ranking-tile-installs'),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                if (showChange)
                  Text(
                    formatChange(change),
                    key: const Key('ranking-tile-change'),
                    style: TextStyle(
                      fontSize: 12,
                      color: _changeColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
