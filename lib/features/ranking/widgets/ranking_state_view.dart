import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

enum _RankingStateKind { loading, error, empty }

/// 로딩·오류·빈 상태를 그리는 뷰. 값만 받아 그린다.
/// 반투명 유리 느낌은 BackdropFilter 로 표현한다.
class RankingStateView extends StatelessWidget {
  const RankingStateView.loading({super.key})
      : _kind = _RankingStateKind.loading,
        message = '불러오는 중이에요.',
        onRetry = null;

  const RankingStateView.error({super.key, required this.message, this.onRetry})
      : _kind = _RankingStateKind.error;

  const RankingStateView.empty({super.key, this.message = '표시할 스킬이 없어요.'})
      : _kind = _RankingStateKind.empty,
        onRetry = null;

  final _RankingStateKind _kind;
  final String message;

  /// 오류 상태에서만 쓰는 다시 시도 동작. null 이면 버튼을 숨긴다.
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isError = _kind == _RankingStateKind.error;

    final Widget icon = switch (_kind) {
      _RankingStateKind.loading => const SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            key: Key('ranking-state-loading'),
            strokeWidth: 3,
          ),
        ),
      _RankingStateKind.error => Icon(
          Icons.error_outline,
          key: const Key('ranking-state-error'),
          color: scheme.error,
          size: 32,
        ),
      _RankingStateKind.empty => Icon(
          Icons.inbox_outlined,
          key: const Key('ranking-state-empty'),
          color: scheme.onSurfaceVariant,
          size: 32,
        ),
    };

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 360),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: scheme.surface.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: 0.6),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  icon,
                  const SizedBox(height: 12),
                  Text(
                    message,
                    key: const Key('ranking-state-message'),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: isError ? scheme.error : null,
                    ),
                  ),
                  if (isError && onRetry != null) ...[
                    const SizedBox(height: 12),
                    OutlinedButton(
                      key: const Key('ranking-state-retry'),
                      onPressed: onRetry,
                      child: const Text('다시 시도'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
