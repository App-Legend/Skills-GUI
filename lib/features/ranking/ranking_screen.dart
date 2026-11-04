import 'package:flutter/material.dart';

import '../../ui/glass.dart';
import 'data/ranking_api_client.dart';
import 'models/ranking_models.dart';
import 'ranking_config.dart';
import 'widgets/ranking_list_tile.dart';
import 'widgets/ranking_state_view.dart';

/// 한 번에 불러오는 항목 수.
const int _perPage = 20;

const _ink = Color(0xFF101828);
const _sub = Color(0xFF3A4658);
const _red = Color(0xFFB42318);
const _blue = Color(0xFF0064D1);

const _tabs = <(RankingView, String)>[
  (RankingView.allTime, '전체'),
  (RankingView.trending, '트렌딩'),
  (RankingView.hot, '핫'),
];

/// 보기마다 아래에 붙는 설명.
const _notes = {
  RankingView.allTime: 'skills.sh 누적 설치 수 기준입니다.',
  RankingView.trending: 'skills.sh 최근 설치가 늘어난 순서입니다.',
  RankingView.hot: '최근 한 시간 설치 수를 어제 같은 시간과 비교합니다.',
};

/// 탭 하나(보기 하나)의 불러오기 상태.
class _ViewState {
  final List<SkillRankItem> items = [];

  /// 마지막으로 불러온 페이지. skills.sh 페이지는 0부터 시작하므로 처음엔 -1.
  int page = -1;
  bool hasMore = false;
  bool loading = false;
  bool loaded = false;
  String? error;
}

/// "랭킹" 탭. 전체·트렌딩·핫 보기와 더 보기를 맡는다.
///
/// [client] 가 없으면 `RANKING_API_BASE` 설정으로 만든다.
/// 설정도 없으면 설정 누락 오류를 보인다.
class RankingScreen extends StatefulWidget {
  const RankingScreen({super.key, this.client, this.installed = const {}});

  final RankingApiClient? client;

  /// 내 스킬 이름들. 랭킹 항목과 이름이 같으면 "설치됨"으로 표시한다.
  final Set<String> installed;

  @override
  State<RankingScreen> createState() => _RankingScreenState();
}

class _RankingScreenState extends State<RankingScreen> {
  late final RankingApiClient? _client;
  RankingView _view = RankingView.allTime;
  final Map<RankingView, _ViewState> _states = {
    for (final tab in _tabs) tab.$1: _ViewState(),
  };

  @override
  void initState() {
    super.initState();
    _client =
        widget.client ??
        (RankingConfig.isConfigured
            ? RankingApiClient(RankingConfig.apiBase)
            : null);
    if (_client != null) _load(_view);
  }

  void _select(RankingView view) {
    setState(() => _view = view);
    final state = _states[view]!;
    if (!state.loaded && !state.loading) _load(view);
  }

  /// 지금 보기를 처음부터 다시 불러온다.
  void _refresh() {
    if (_states[_view]!.loading) return;
    _states[_view] = _ViewState();
    _load(_view);
  }

  /// 다음 페이지(처음이면 0페이지)를 불러와 목록에 이어 붙인다.
  Future<void> _load(RankingView view) async {
    final client = _client;
    final state = _states[view]!;
    if (client == null || state.loading) return;
    setState(() {
      state.loading = true;
      state.error = null;
    });
    try {
      final result = await client.fetchPage(view, state.page + 1, _perPage);
      if (!mounted) return;
      setState(() {
        state.items.addAll(result.items);
        state.page = result.pagination.page;
        state.hasMore = result.pagination.hasMore;
        state.loaded = true;
        state.loading = false;
      });
    } on RankingApiException catch (e) {
      if (!mounted) return;
      setState(() {
        state.error = e.message;
        state.loading = false;
      });
    }
  }

  static Widget _chip(String label, bool selected, VoidCallback onTap) =>
      Semantics(
        selected: selected,
        button: true,
        child: GlassTap(
          onTap: onTap,
          color: selected ? const Color(0xB3FFFFFF) : null,
          child: Text(
            label,
            style: TextStyle(
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final loading = _states[_view]!.loading;
    return DefaultTextStyle(
      style: const TextStyle(color: _ink, fontSize: 14, height: 1.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GlassPanel(
            radius: 30,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  const Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(left: 12),
                      child: Text(
                        '랭킹',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  if (_client != null)
                    GlassTap(
                      key: const Key('ranking-refresh'),
                      onTap: loading ? () {} : _refresh,
                      color: _blue,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: loading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              '새로고침',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Wrap(
              spacing: 6,
              children: [
                for (final tab in _tabs)
                  _chip(tab.$2, tab.$1 == _view, () => _select(tab.$1)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 8),
            child: Text(
              _notes[_view]!,
              style: const TextStyle(fontSize: 12, color: _sub),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _body() {
    if (_client == null) {
      return const RankingStateView.error(
        message: RankingConfig.missingMessage,
      );
    }
    final view = _view;
    final state = _states[view]!;

    if (!state.loaded) {
      if (state.error != null) {
        return RankingStateView.error(
          message: state.error!,
          onRetry: () => _load(view),
        );
      }
      return const RankingStateView.loading();
    }
    if (state.items.isEmpty) return const RankingStateView.empty();

    return ListView(
      key: PageStorageKey<String>('ranking-list-${view.apiValue}'),
      children: [
        for (var i = 0; i < state.items.length; i++)
          RankingListTile(
            rank: i + 1,
            name: state.items[i].name,
            source: state.items[i].source,
            installs: state.items[i].installs,
            change: state.items[i].change,
            showChange: view == RankingView.hot,
            installed: widget.installed.contains(state.items[i].name),
          ),
        _footer(view, state),
      ],
    );
  }

  Widget _footer(RankingView view, _ViewState state) {
    if (state.loading) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 16),
      child: Column(
        children: [
          if (state.error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                state.error!,
                key: const Key('ranking-more-error'),
                textAlign: TextAlign.center,
                style: const TextStyle(color: _red),
              ),
            ),
          if (state.hasMore)
            GlassTap(
              key: const Key('ranking-next-page'),
              onTap: () => _load(view),
              color: const Color(0xB3FFFFFF),
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: const Text(
                '더 보기',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
    );
  }
}
