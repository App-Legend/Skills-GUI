import 'package:flutter/material.dart';

import '../features/ranking/install/install_history.dart';
import '../features/ranking/widgets/install_history_view.dart';
import '../features/skill_analysis/skill_analysis_store.dart';
import '../features/scan/skill.dart';
import '../features/usage/skill_usage.dart';
import 'glass.dart';
import 'skill_detail_page.dart';
import 'skill_list_page.dart';

const _ink = Color(0xFF101828);
const _sub = Color(0xFF3A4658);

const _notReady = Center(
  child: Text('아직 준비 중입니다', style: TextStyle(color: _sub)),
);

enum AppTab {
  mine('내 스킬'),
  updates('업데이트 필요'),
  ranking('랭킹');

  final String label;
  const AppTab(this.label);
}

/// 배경, 왼쪽 사이드바 탭, 선택한 탭의 내용.
class AppShell extends StatefulWidget {
  final ScanResult result;
  final Future<void> Function() onRescan;

  /// "업데이트 필요" 탭 내용. null이면 준비 중.
  final Widget? updates;

  /// "랭킹" 탭 내용. null이면 준비 중.
  final Widget? ranking;
  final bool scanning;

  /// 업데이트가 필요한 플러그인 수. 0이면 숫자를 숨긴다.
  final int updateCount;

  /// null이면 기본 분석 서버와 캐시를 쓴다.
  final SkillAnalysisStore? analysisStore;

  /// 랭킹에서 하는 설치 기록. 설치 중이면 사이드바 랭킹 탭에 "설치 중"을 띄운다.
  final InstallHistory? installHistory;

  /// 내 스킬 "미사용 후보" 필터용 사용 기록. null이면 읽는 중.
  final SkillUsage? usage;

  /// 사이드바 탭을 누를 때마다 부른다. 바깥에서 넣은 탭 화면을 처음으로 돌릴 때 쓴다.
  final ValueChanged<AppTab>? onTabSelected;

  const AppShell({
    super.key,
    required this.result,
    required this.onRescan,
    this.updates,
    this.ranking,
    this.scanning = false,
    this.updateCount = 0,
    this.analysisStore,
    this.installHistory,
    this.usage,
    this.onTabSelected,
  });

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  AppTab _tab = AppTab.mine;
  Skill? _detail; // 내 스킬 탭에서 연 상세. 사이드바 오른쪽에만 뜬다.
  bool _updatesOpened = false;

  // 목록 카드와 상세가 같은 분석 결과를 쓴다.
  late final SkillAnalysisStore _analysis =
      widget.analysisStore ?? SkillAnalysisStore();

  @override
  void dispose() {
    if (widget.analysisStore == null) _analysis.dispose();
    super.dispose();
  }

  void _onTab(AppTab t) {
    setState(() {
      // 내 스킬 탭을 누르면 언제나 목록으로 돌아간다(다른 탭에 갔다 와도).
      if (t == AppTab.mine) _detail = null;
      _tab = t;
      if (t == AppTab.updates) _updatesOpened = true;
    });
    widget.onTabSelected?.call(t);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.transparent,
    body: GlassBackground(
      child: DefaultTextStyle(
        style: const TextStyle(color: _ink, fontSize: 14, height: 1.5),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 240,
                child: _Sidebar(
                  tab: _tab,
                  counts: {
                    AppTab.mine: widget.result.skills.length,
                    AppTab.updates: widget.updateCount,
                  },
                  onTab: _onTab,
                  installHistory: widget.installHistory,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                // 탭을 옮겨도 각 화면의 필터·확인 결과가 남도록 모두 유지한다(열린 상세와 위쪽 탭은 탭을 누를 때 처음으로).
                child: IndexedStack(
                  index: _tab.index,
                  children: [
                    // 상세 페이지가 사이드바의 화면 낭독 정보를 가리지 않도록 영역을 나눈다.
                    Semantics(
                      container: true,
                      child: Navigator(
                        pages: [
                          MaterialPage(
                            child: SkillListPage(
                              result: widget.result,
                              onRescan: widget.onRescan,
                              onOpen: (s) => setState(() => _detail = s),
                              scanning: widget.scanning,
                              analysisStore: _analysis,
                              usage: widget.usage,
                            ),
                          ),
                          if (_detail case final s?)
                            MaterialPage(
                              child: SkillDetailPage(
                                skill: s,
                                analysisStore: _analysis,
                                onDeleted: widget.onRescan,
                              ),
                            ),
                        ],
                        onDidRemovePage: (_) => setState(() => _detail = null),
                      ),
                    ),
                    // 업데이트 화면은 처음 열 때 만들어져 바로 확인한다.
                    _updatesOpened ? widget.updates ?? _notReady : const SizedBox(),
                    widget.ranking ?? _notReady,
                  ],
                ),
              ),
              // 오른쪽 사이드바: 설치 기록. 열려 있을 때만 보이고 어느 탭에서든 남는다.
              if (widget.installHistory case final history?)
                ValueListenableBuilder<bool>(
                  valueListenable: history.panelOpen,
                  builder: (context, open, _) => Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: open
                        ? SizedBox(
                            width: 300,
                            child: InstallHistoryPanel(history: history),
                          )
                        : Align(
                            alignment: Alignment.topCenter,
                            child: InstallHistoryRail(history: history),
                          ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _Sidebar extends StatelessWidget {
  final AppTab tab;
  final Map<AppTab, int> counts;
  final ValueChanged<AppTab> onTab;
  final InstallHistory? installHistory;

  const _Sidebar({
    required this.tab,
    required this.counts,
    required this.onTab,
    this.installHistory,
  });

  /// 랭킹 탭 오른쪽의 "설치 중 n" 표시. 설치가 없으면 아무것도 안 그린다.
  Widget _installing() {
    final history = installHistory;
    if (history == null) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: history,
      builder: (context, _) {
        final n = history.runningCount;
        if (n == 0) return const SizedBox.shrink();
        return GestureDetector(
          onTap: () => history.panelOpen.value = true,
          child: Row(
            key: const Key('sidebar-installing'),
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFF0064D1),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '설치 중 $n',
                style: const TextStyle(fontSize: 12, color: Color(0xFF0064D1)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _item(AppTab t) => Semantics(
    selected: t == tab,
    button: true,
    child: GlassTap(
      onTap: () => onTab(t),
      color: t == tab ? const Color(0xB3FFFFFF) : null,
      child: Row(
        children: [
          Expanded(
            child: Text(
              t.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: t == tab ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
          if (t == AppTab.ranking) _installing(),
          if ((counts[t] ?? 0) > 0)
            Text(
              '${counts[t]}',
              style: const TextStyle(fontSize: 12, color: _sub),
            ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => GlassPanel(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
      child: ListView(
        children: [
          // 앱 로고. 원본은 저장소 밖 로고 키트(검정 가로형)에서 PNG 로 뽑았다.
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 20),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Image.asset(
                'assets/logo/skillgui-logo.png',
                key: const Key('app-logo'),
                height: 30,
                semanticLabel: 'Skill-GUI',
                filterQuality: FilterQuality.medium,
              ),
            ),
          ),
          for (final t in AppTab.values) _item(t),
        ],
      ),
    ),
  );
}
