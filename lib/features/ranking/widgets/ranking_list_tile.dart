import 'package:flutter/material.dart';

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
  });

  final int rank;
  final String name;
  final String source;
  final int installs;
  final int? change;
  final bool showChange;

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

  Color _changeColor(ColorScheme scheme) {
    final value = change;
    if (value == null || value == 0) return scheme.onSurfaceVariant;
    return value > 0 ? Colors.green.shade700 : scheme.error;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      key: const Key('ranking-tile'),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            SizedBox(
              width: 40,
              child: Text(
                '$rank',
                key: const Key('ranking-tile-rank'),
                style: theme.textTheme.titleMedium,
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    key: const Key('ranking-tile-name'),
                    style: theme.textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    source,
                    key: const Key('ranking-tile-source'),
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '설치 ${formatCount(installs)}',
                  key: const Key('ranking-tile-installs'),
                  style: theme.textTheme.bodyMedium,
                ),
                if (showChange)
                  Text(
                    formatChange(change),
                    key: const Key('ranking-tile-change'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: _changeColor(scheme),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
