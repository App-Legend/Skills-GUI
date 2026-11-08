import 'package:flutter/material.dart';

import '../features/skill_analysis/skill_analysis_store.dart';
import '../scan/skill.dart';
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
  search('검색'),
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

  const AppShell({
    super.key,
    required this.result,
    required this.onRescan,
    this.updates,
    this.ranking,
    this.scanning = false,
    this.updateCount = 0,
    this.analysisStore,
  });

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  AppTab _tab = AppTab.mine;
  Skill? _detail; // 내 스킬 탭에서 연 상세. 사이드바 오른쪽에만 뜬다.

  // 목록 카드와 상세가 같은 분석 결과를 쓴다.
  late final SkillAnalysisStore _analysis =
      widget.analysisStore ?? SkillAnalysisStore();

  @override
  void dispose() {
    if (widget.analysisStore == null) _analysis.dispose();
    super.dispose();
  }

  void _onTab(AppTab t) => setState(() {
    // 내 스킬 탭을 다시 누르면 목록으로 돌아간다.
    if (t == AppTab.mine && _tab == AppTab.mine) _detail = null;
    _tab = t;
  });

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
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                // 탭을 옮겨도 각 화면의 필터·확인 결과가 남도록 모두 유지한다.
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
                            ),
                          ),
                          if (_detail case final s?)
                            MaterialPage(
                              child: SkillDetailPage(
                                skill: s,
                                analysisStore: _analysis,
                              ),
                            ),
                        ],
                        onDidRemovePage: (_) => setState(() => _detail = null),
                      ),
                    ),
                    widget.updates ?? _notReady,
                    _notReady,
                    widget.ranking ?? _notReady,
                  ],
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

  const _Sidebar({
    required this.tab,
    required this.counts,
    required this.onTab,
  });

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
      child: ListView(children: [for (final t in AppTab.values) _item(t)]),
    ),
  );
}
