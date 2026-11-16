import 'package:flutter/material.dart';

import '../../../ui/skill_badges.dart';

const _sub = Color(0xFF3A4658);
const _green = Color(0xFF067647);
const _red = Color(0xFFB42318);
const _star = Color(0xFF8A5A00);

/// 랭킹 항목 한 줄. 값만 받아 그린다.
///
/// [showChange] 가 true 이면 [change] 를 +/− 로 표시한다 (핫 뷰용).
/// [change] 가 null 이면 변화량 자리에 '-' 를 보인다.
/// [stars] 는 GitHub 저장소 스타 수. null 이면 스타 줄을 그리지 않는다.
/// [category] 가 있으면 이름 바로 옆에 카테고리 배지를 붙이고, 이름 아래에는 [summary](한국어 짧은 개요)를 한 줄로 보인다.
/// 설치 수와 스타 수는 오른쪽 정렬, [installed] 면 맨 오른쪽에 체크 표시를 둔다.
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
    this.stars,
    this.category,
    this.summary,
    this.onTap,
  });

  final int rank;
  final String name;

  /// 출처(저장소). 이름 아래에는 이제 개요를 보여서 화면에는 쓰지 않는다.
  final String source;
  final int installs;
  final int? change;
  final bool showChange;

  /// 내 스킬에 같은 이름이 있으면 맨 오른쪽에 체크 표시를 붙인다.
  final bool installed;

  final int? stars;
  final String? category;

  /// 한국어 짧은 개요. 분석 전이면 null.
  final String? summary;

  /// 누르면 상세로 간다. null 이면 누를 수 없다.
  final VoidCallback? onTap;

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
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
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
              // 왼쪽: 이름 · 카테고리, 그 아래 한 줄 개요.
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
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (category != null) ...[
                          const SizedBox(width: 8),
                          SkillBadge(
                            category!,
                            key: const Key('ranking-tile-category'),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      summary ?? '',
                      key: const Key('ranking-tile-summary'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: _sub),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // 오른쪽 정렬: 설치 수, 그 아래 스타 수(와 핫 변화량).
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '설치 ${formatCount(installs)}',
                    key: const Key('ranking-tile-installs'),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (stars != null)
                        Text(
                          '★ ${formatCount(stars!)}',
                          key: const Key('ranking-tile-stars'),
                          style: const TextStyle(fontSize: 12, color: _star),
                        ),
                      if (showChange) ...[
                        const SizedBox(width: 8),
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
                    ],
                  ),
                ],
              ),
              // 맨 오른쪽: 설치됨 체크. 자리를 늘 비워 둬서 숫자 줄이 어긋나지 않게 한다.
              const SizedBox(width: 12),
              SizedBox(
                width: 24,
                child: installed
                    ? const Tooltip(
                        message: '설치됨',
                        child: Icon(
                          Icons.check_circle_rounded,
                          key: Key('ranking-tile-installed'),
                          size: 22,
                          color: _green,
                        ),
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
