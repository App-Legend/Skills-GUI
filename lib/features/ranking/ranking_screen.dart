import 'dart:async';

import 'package:flutter/material.dart';

import '../../ui/glass.dart';
import 'category/skill_category.dart';
import 'data/ranking_api_client.dart';
import 'install/install_history.dart';
import 'install/skill_installer.dart';
import 'models/ranking_models.dart';
import 'ranking_config.dart';
import 'ranking_detail_page.dart';
import 'widgets/category_list.dart';
import 'widgets/ranking_list_tile.dart';
import 'widgets/ranking_state_view.dart';

/// 한 번에 불러오는 랭킹 항목 수. 카테고리로 거를 때도 충분히 남도록 넉넉히 받는다.
const int _perPage = 100;

/// 카테고리를 고르면 이만큼 보일 때까지 다음 페이지를 자동으로 더 불러온다.
const int _categoryFillTarget = 20;

/// 자동으로 더 불러오는 최대 페이지 수 (100 × 5 = 500개).
const int _categoryFillMaxPages = 5;

/// 검색 결과 최대 개수.
const int _searchLimit = 100;

/// 입력을 멈추고 이만큼 지나면 검색한다.
const Duration _searchDelay = Duration(milliseconds: 400);

const _ink = Color(0xFF101828);
const _sub = Color(0xFF3A4658);
const _red = Color(0xFFB42318);
const _blue = Color(0xFF0064D1);

/// 랭킹 탭. 스타 탭은 skills.sh 에 없는 순서라, 누적 설치 목록을 받아 스타 순으로 다시 정렬한다.
enum _Tab {
  allTime(RankingView.allTime, '전체'),
  trending(RankingView.trending, '트렌딩'),
  stars(RankingView.allTime, '스타');

  const _Tab(this.view, this.label);

  /// 이 탭이 불러오는 skills.sh 보기.
  final RankingView view;
  final String label;
}

/// 스타 탭이 다시 정렬할 누적 설치 상위 범위 (100 × 3 = 300개). 더 보기로 늘릴 수 있다.
const int _starsPoolPages = 3;

/// 탭마다 아래에 붙는 설명.
const _notes = {
  _Tab.allTime: 'skills.sh 누적 설치 수 기준입니다.',
  _Tab.trending: 'skills.sh 최근 설치가 늘어난 순서입니다.',
  _Tab.stars: '누적 설치 상위 스킬을 GitHub 저장소 스타 수 순으로 다시 줄 세웠습니다. 같은 저장소의 스킬은 스타가 같고, GitHub 저장소가 아닌 스킬은 뒤에 둡니다.',
};

const _categoryNote = '카테고리는 스킬 이름과 저장소 이름으로 나눈 것이라 정확하지 않을 수 있습니다.';

final _repoPattern = RegExp(r'^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$');

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

/// 검색 상태. [query] 가 null 이면 검색 중이 아니다.
class _SearchState {
  String? query;
  List<SkillRankItem> items = const [];
  bool loading = false;
  String? error;

  /// 늦게 도착한 옛 응답을 버리기 위한 요청 번호.
  int serial = 0;
}

/// "랭킹" 탭. 위쪽 검색창, 전체·트렌딩·스타 보기, 카테고리 칩, GitHub 스타 수를 맡는다.
///
/// [client] 가 없으면 `RANKING_API_BASE` 설정으로 만든다.
/// 설정도 없으면 설정 누락 오류를 보인다.
class RankingScreen extends StatefulWidget {
  const RankingScreen({
    super.key,
    this.client,
    this.installed = const {},
    this.installer,
    this.onInstalled,
    this.history,
  });

  final RankingApiClient? client;

  /// 상세 화면에서 쓰는 설치기. 없으면 기본 설치기(홈 폴더)를 쓴다.
  final SkillInstaller? installer;

  /// 상세 화면에서 설치를 마친 뒤 부른다.
  final VoidCallback? onInstalled;

  /// 설치 기록. 앱 전체에서 하나를 같이 쓴다 (사이드바 "설치 중" 표시용).
  final InstallHistory? history;

  /// 내 스킬 이름들. 랭킹 항목과 이름이 같으면 "설치됨"으로 표시한다.
  final Set<String> installed;

  @override
  State<RankingScreen> createState() => _RankingScreenState();
}

class _RankingScreenState extends State<RankingScreen> {
  late final RankingApiClient? _client;
  _Tab _tab = _Tab.allTime;
  RankingView get _view => _tab.view;
  final Map<RankingView, _ViewState> _states = {
    for (final tab in _Tab.values) tab.view: _ViewState(),
  };

  /// null 이면 모든 카테고리.
  SkillCategory? _category;

  final TextEditingController _searchText = TextEditingController();
  final _SearchState _search = _SearchState();
  Timer? _searchTimer;

  /// 저장소(owner/repo) → 스타 수. 값이 null 이면 조회했지만 못 가져온 것.
  final Map<String, int?> _stars = {};
  final Set<String> _starsPending = {};
  bool _starsLimited = false;

  final Map<String, List<SkillCategory>> _categoryCache = {};

  /// 열어 둔 상세. null 이면 목록을 보인다.
  SkillRankItem? _detail;

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

  @override
  void dispose() {
    _searchTimer?.cancel();
    _searchText.dispose();
    super.dispose();
  }

  bool get _searching => _search.query != null;

  List<SkillCategory> _categoriesOf(SkillRankItem item) =>
      _categoryCache.putIfAbsent(
        item.id,
        () => categorize(name: item.name, slug: item.slug, source: item.source),
      );

  // ---- 랭킹 보기 ----

  void _select(_Tab tab) {
    setState(() => _tab = tab);
    final state = _states[_view]!;
    if (!state.loaded && !state.loading) {
      _load(_view);
    } else {
      _fillCategory();
      _fillStars();
    }
  }

  /// 스타 탭은 정렬할 범위가 넓어야 의미가 있어 처음에 [_starsPoolPages] 페이지까지 불러온다.
  void _fillStars() {
    if (_tab != _Tab.stars || _searching) return;
    final state = _states[_view]!;
    if (!state.loaded || state.loading || !state.hasMore) return;
    if (state.error != null || state.page + 1 >= _starsPoolPages) return;
    _load(_view);
  }

  /// 스타 많은 순, 같으면 설치 많은 순. 스타를 모르는 스킬은 뒤로.
  List<SkillRankItem> _byStars(List<SkillRankItem> items) {
    int starsOf(SkillRankItem item) => _stars[item.source] ?? -1;
    return [...items]..sort((a, b) {
      final byStars = starsOf(b).compareTo(starsOf(a));
      return byStars != 0 ? byStars : b.installs.compareTo(a.installs);
    });
  }

  void _selectCategory(SkillCategory? category) {
    setState(() => _category = category);
    _fillCategory();
  }

  /// 지금 보기(검색 중이면 검색)를 처음부터 다시 불러온다.
  void _refresh() {
    if (_searching) {
      _runSearch(_search.query!);
      return;
    }
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
      if (!mounted || _states[view] != state) return;
      setState(() {
        state.items.addAll(result.items);
        state.page = result.pagination.page;
        state.hasMore = result.pagination.hasMore;
        state.loaded = true;
        state.loading = false;
      });
      _loadStars(result.items);
      _fillCategory();
      _fillStars();
    } on RankingApiException catch (e) {
      if (!mounted || _states[view] != state) return;
      setState(() {
        state.error = e.message;
        state.loading = false;
      });
    }
  }

  /// 카테고리로 거른 결과가 너무 적으면 다음 페이지를 자동으로 더 불러온다.
  void _fillCategory() {
    final category = _category;
    if (category == null || _searching) return;
    final state = _states[_view]!;
    if (!state.loaded || state.loading || !state.hasMore) return;
    if (state.error != null || state.page + 1 >= _categoryFillMaxPages) return;
    final shown = state.items
        .where((item) => _categoriesOf(item).contains(category))
        .length;
    if (shown < _categoryFillTarget) _load(_view);
  }

  // ---- 검색 ----

  void _onSearchChanged(String text) {
    _searchTimer?.cancel();
    final query = text.trim();
    if (query.isEmpty) {
      _clearSearch(keepText: true);
      return;
    }
    if (query.length < 2) return;
    _searchTimer = Timer(_searchDelay, () => _runSearch(query));
  }

  void _onSearchSubmitted(String text) {
    _searchTimer?.cancel();
    final query = text.trim();
    if (query.length >= 2) _runSearch(query);
  }

  void _clearSearch({bool keepText = false}) {
    _searchTimer?.cancel();
    if (!keepText) _searchText.clear();
    setState(() {
      _search
        ..query = null
        ..items = const []
        ..loading = false
        ..error = null
        ..serial += 1;
    });
    _fillCategory();
  }

  Future<void> _runSearch(String query) async {
    final client = _client;
    if (client == null) return;
    final serial = ++_search.serial;
    setState(() {
      _search
        ..query = query
        ..loading = true
        ..error = null;
    });
    try {
      final result = await client.search(query, limit: _searchLimit);
      if (!mounted || serial != _search.serial) return;
      setState(() {
        _search
          ..items = result.items
          ..loading = false;
      });
      _loadStars(result.items);
    } on RankingApiException catch (e) {
      if (!mounted || serial != _search.serial) return;
      setState(() {
        _search
          ..items = const []
          ..error = e.message
          ..loading = false;
      });
    }
  }

  // ---- GitHub 스타 ----

  /// 아직 모르는 GitHub 저장소의 스타 수를 묶어서 가져온다. 실패해도 목록은 그대로 둔다.
  Future<void> _loadStars(List<SkillRankItem> items) async {
    final client = _client;
    if (client == null) return;
    final repos = <String>{
      for (final item in items)
        if (item.sourceType == 'github' &&
            _repoPattern.hasMatch(item.source) &&
            !_stars.containsKey(item.source) &&
            !_starsPending.contains(item.source))
          item.source,
    }.toList();
    if (repos.isEmpty) return;
    _starsPending.addAll(repos);

    for (var i = 0; i < repos.length; i += RankingApiClient.maxStarsRepos) {
      final end = (i + RankingApiClient.maxStarsRepos).clamp(0, repos.length);
      final batch = repos.sublist(i, end);
      try {
        final result = await client.fetchStars(batch);
        if (!mounted) return;
        setState(() {
          for (final repo in batch) {
            final value = result.stars[repo];
            // 한도에 걸려 비어 온 저장소는 다음에 다시 물을 수 있게 남겨 두지 않는다.
            if (value != null || !result.limited) _stars[repo] = value;
          }
          if (result.limited) _starsLimited = true;
        });
      } on RankingApiException {
        // 스타는 덧붙이는 정보라 실패를 화면에 띄우지 않는다.
      } finally {
        _starsPending.removeAll(batch);
      }
    }
  }

  // ---- 화면 ----

  static Widget _chip(
    String label,
    bool selected,
    VoidCallback onTap, {
    Key? key,
  }) => Semantics(
    selected: selected,
    button: true,
    child: GlassTap(
      key: key,
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

  /// 지금 화면에 깔린 목록 (검색 결과 또는 랭킹 보기).
  List<SkillRankItem> get _baseItems =>
      _searching ? _search.items : _states[_view]!.items;

  @override
  Widget build(BuildContext context) {
    final detail = _detail;
    final client = _client;
    if (detail != null && client != null) {
      return RankingDetailPage(
        key: ValueKey(detail.id),
        item: detail,
        client: client,
        installer: widget.installer,
        category: (_category ?? _categoriesOf(detail).first).label,
        stars: _stars[detail.source],
        installed: widget.installed.contains(detail.name),
        onBack: () => setState(() => _detail = null),
        onInstalled: widget.onInstalled,
        history: widget.history,
      );
    }
    final loading = _searching ? _search.loading : _states[_view]!.loading;
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
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        '랭킹',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  if (_client != null) ...[
                    const SizedBox(width: 8),
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
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: _searchField(),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: _searching
                ? Row(
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Text(
                            _search.loading
                                ? '"${_search.query}" 검색 중'
                                : '"${_search.query}" 검색 결과 ${_search.items.length}개',
                            key: const Key('ranking-search-summary'),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                      _chip(
                        '랭킹으로 돌아가기',
                        false,
                        _clearSearch,
                        key: const Key('ranking-search-back'),
                      ),
                    ],
                  )
                : Wrap(
                    spacing: 6,
                    children: [
                      for (final tab in _Tab.values)
                        _chip(
                          tab.label,
                          tab == _tab,
                          () => _select(tab),
                          key: Key('ranking-tab-${tab.name}'),
                        ),
                    ],
                  ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 8),
            child: Text(
              [
                if (!_searching) _notes[_tab]!,
                if (_category != null) _categoryNote,
                if (_starsLimited) 'GitHub 요청 한도에 걸려 일부 스타 수를 가져오지 못했습니다.',
              ].join(' '),
              style: const TextStyle(fontSize: 12, color: _sub),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(width: 200, child: _categoryList()),
                const SizedBox(width: 16),
                Expanded(child: _body()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // TextField 는 Material 조상이 있어야 해서 배경을 Material 로 깐다.
  Widget _searchField() => Material(
    color: const Color(0xB3FFFFFF),
    borderRadius: BorderRadius.circular(22),
    child: SizedBox(
      height: 44,
      child: Row(
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 14, right: 8),
            child: Icon(Icons.search, size: 20, color: _sub),
          ),
          Expanded(
            child: TextField(
              key: const Key('ranking-search-field'),
              controller: _searchText,
              onChanged: _onSearchChanged,
              onSubmitted: _onSearchSubmitted,
              textInputAction: TextInputAction.search,
              enabled: _client != null,
              style: const TextStyle(fontSize: 14, color: _ink),
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: 'skills.sh 에서 스킬 검색 (2자 이상, 여러 단어면 뜻으로 찾음)',
                hintStyle: TextStyle(fontSize: 14, color: _sub),
              ),
            ),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _searchText,
            builder: (context, value, _) => value.text.isEmpty
                ? const SizedBox(width: 14)
                : IconButton(
                    key: const Key('ranking-search-clear'),
                    tooltip: '검색어 지우기',
                    icon: const Icon(Icons.close, size: 18, color: _sub),
                    onPressed: _clearSearch,
                  ),
          ),
        ],
      ),
    ),
  );

  Widget _categoryList() {
    final items = _baseItems;
    final counts = <SkillCategory, int>{};
    for (final item in items) {
      for (final category in _categoriesOf(item)) {
        counts[category] = (counts[category] ?? 0) + 1;
      }
    }
    return CategoryList(
      counts: counts,
      total: items.length,
      selected: _category,
      onSelect: _selectCategory,
    );
  }

  Widget _body() {
    if (_client == null) {
      return const RankingStateView.error(
        message: RankingConfig.missingMessage,
      );
    }
    if (_searching) return _searchBody();

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
    final rows = _rows(
      _tab == _Tab.stars ? _byStars(state.items) : state.items,
      showChange: false,
    );
    if (rows.isEmpty && !state.hasMore && !state.loading) {
      return const RankingStateView.empty();
    }
    return ListView(
      key: PageStorageKey<String>('ranking-list-${_tab.name}'),
      children: [...rows, _footer(view, state)],
    );
  }

  Widget _searchBody() {
    if (_search.loading && _search.items.isEmpty) {
      return const RankingStateView.loading();
    }
    if (_search.error != null) {
      return RankingStateView.error(
        message: _search.error!,
        onRetry: () => _runSearch(_search.query!),
      );
    }
    final rows = _rows(_search.items, showChange: false);
    if (rows.isEmpty) return const RankingStateView.empty();
    return ListView(
      key: const PageStorageKey<String>('ranking-list-search'),
      children: rows,
    );
  }

  /// 카테고리로 거른 타일들. 순위는 거르기 전 목록의 순서를 그대로 쓴다.
  List<Widget> _rows(List<SkillRankItem> items, {required bool showChange}) {
    final category = _category;
    return [
      for (var i = 0; i < items.length; i++)
        if (category == null || _categoriesOf(items[i]).contains(category))
          RankingListTile(
            rank: i + 1,
            name: items[i].name,
            source: items[i].source,
            installs: items[i].installs,
            change: items[i].change,
            showChange: showChange,
            installed: widget.installed.contains(items[i].name),
            stars: _stars[items[i].source],
            category: (category ?? _categoriesOf(items[i]).first).label,
            onTap: () => setState(() => _detail = items[i]),
          ),
    ];
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
