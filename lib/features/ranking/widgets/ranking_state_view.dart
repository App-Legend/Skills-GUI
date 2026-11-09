import 'package:flutter/material.dart';

import '../../../ui/glass.dart';

const _sub = Color(0xFF3A4658);
const _red = Color(0xFFB42318);

enum _RankingStateKind { loading, error, empty }

/// 로딩·오류·빈 상태를 그리는 뷰. 값만 받아 그린다.
class RankingStateView extends StatelessWidget {
  const RankingStateView.loading({super.key})
      : _kind = _RankingStateKind.loading,
        message = '불러오는 중이다',
        onRetry = null;

  const RankingStateView.error({super.key, required this.message, this.onRetry})
      : _kind = _RankingStateKind.error;

  const RankingStateView.empty({super.key, this.message = '표시할 스킬이 없다'})
      : _kind = _RankingStateKind.empty,
        onRetry = null;

  final _RankingStateKind _kind;
  final String message;

  /// 오류 상태에서만 쓰는 다시 시도 동작. null 이면 버튼을 숨긴다.
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final isError = _kind == _RankingStateKind.error;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_kind == _RankingStateKind.loading)
                const CircularProgressIndicator(key: Key('ranking-state-loading'))
              else
                SizedBox.shrink(
                  key: Key(isError ? 'ranking-state-error' : 'ranking-state-empty'),
                ),
              if (_kind == _RankingStateKind.loading) const SizedBox(height: 12),
              Text(
                message,
                key: const Key('ranking-state-message'),
                textAlign: TextAlign.center,
                style: TextStyle(color: isError ? _red : _sub),
              ),
              if (isError && onRetry != null) ...[
                const SizedBox(height: 12),
                GlassTap(
                  key: const Key('ranking-state-retry'),
                  onTap: onRetry!,
                  color: const Color(0xB3FFFFFF),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: const Text('다시 시도', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
