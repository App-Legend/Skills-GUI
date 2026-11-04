import 'package:flutter/material.dart';

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
  search('검색');

  final String label;
  const AppTab(this.label);
}

/// 배경, 왼쪽 사이드바 탭, 선택한 탭의 내용.
class AppShell extends StatefulWidget {
  final ScanResult result;
  final Future<void> Function() onRescan;

  /// "업데이트 필요" 탭 내용. null이면 준비 중.
  final Widget? updates;
  final bool scanning;

  const AppShell({
    super.key,
    required this.result,
    required this.onRescan,
    this.updates,
    this.scanning = false,
  });

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  AppTab _tab = AppTab.mine;
  Skill? _detail; // 내 스킬 탭에서 연 상세. 사이드바 오른쪽에만 뜬다.

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
                  count: widget.result.skills.length,
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
                            ),
                          ),
                          if (_detail case final s?)
                            MaterialPage(child: SkillDetailPage(skill: s)),
                        ],
                        onDidRemovePage: (_) => setState(() => _detail = null),
                      ),
                    ),
                    widget.updates ?? _notReady,
                    _notReady,
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
  final int count;
  final ValueChanged<AppTab> onTab;

  const _Sidebar({required this.tab, required this.count, required this.onTab});

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
          if (t == AppTab.mine)
            Text('$count', style: const TextStyle(fontSize: 12, color: _sub)),
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
