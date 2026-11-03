import 'package:flutter/material.dart';

import 'data/ranking_api_client.dart';
import 'models/ranking_models.dart';
import 'ranking_config.dart';
import 'widgets/ranking_list_tile.dart';
import 'widgets/ranking_state_view.dart';

/// 한 번에 불러오는 항목 수.
const int _perPage = 20;

const _tabs = <(RankingView, String)>[
  (RankingView.allTime, '전체'),
  (RankingView.trending, '트렌딩'),
  (RankingView.hot, '핫'),
];

/// 탭 하나(보기 하나)의 불러오기 상태.
class _ViewState {
  final List<SkillRankItem> items = [];
  int page = 0;
  bool hasMore = false;
  bool loading = false;
  bool loaded = false;
  String? error;
}

/// 스킬 랭킹 화면. 전체·트렌딩·핫 탭과 다음 페이지 불러오기를 맡는다.
///
/// [client] 가 없으면 `RANKING_API_BASE` 설정으로 만든다.
/// 설정도 없으면 설정 누락 오류를 보인다.
class RankingScreen extends StatefulWidget {
  const RankingScreen({super.key, this.client});

  final RankingApiClient? client;

  @override
  State<RankingScreen> createState() => _RankingScreenState();
}

class _RankingScreenState extends State<RankingScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final RankingApiClient? _client;
  final Map<RankingView, _ViewState> _states = {
    for (final tab in _tabs) tab.$1: _ViewState(),
  };

  RankingView get _current => _tabs[_tabController.index].$1;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _client = widget.client ??
        (RankingConfig.isConfigured
            ? RankingApiClient(RankingConfig.apiBase)
            : null);
    if (_client != null) _load(_current);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _selectTab(int index) {
    setState(() {});
    final state = _states[_current]!;
    if (!state.loaded && !state.loading) _load(_current);
  }

  /// 다음 페이지(처음이면 1페이지)를 불러와 목록에 이어 붙인다.
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('스킬 랭킹'),
        bottom: TabBar(
          controller: _tabController,
          onTap: _selectTab,
          tabs: [for (final tab in _tabs) Tab(text: tab.$2)],
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_client == null) {
      return const RankingStateView.error(
        message: RankingConfig.missingMessage,
      );
    }
    final view = _current;
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
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        for (var i = 0; i < state.items.length; i++)
          RankingListTile(
            rank: i + 1,
            name: state.items[i].name,
            source: state.items[i].source,
            installs: state.items[i].installs,
            change: state.items[i].change,
            showChange: view == RankingView.hot,
          ),
        _buildFooter(view, state),
      ],
    );
  }

  Widget _buildFooter(RankingView view, _ViewState state) {
    if (state.loading) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          if (state.error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                state.error!,
                key: const Key('ranking-more-error'),
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          if (state.hasMore)
            OutlinedButton(
              key: const Key('ranking-next-page'),
              onPressed: () => _load(view),
              child: const Text('다음 페이지 불러오기'),
            ),
        ],
      ),
    );
  }
}
