import 'package:flutter/material.dart';

import '../scan/skill.dart';
import 'glass.dart';
import 'skill_list_page.dart';

const _ink = Color(0xFF101828);
const _sub = Color(0xFF3A4658);

enum AppTab {
  claude('Claude Code'),
  codex('Codex'),
  updates('업데이트 있음'),
  unused('미사용 후보'),
  discover('찾기·랭킹');

  final String label;
  const AppTab(this.label);
}

/// 배경, 왼쪽 사이드바 탭, 선택한 탭의 내용.
class AppShell extends StatefulWidget {
  final ScanResult result;
  final Future<void> Function() onRescan;
  final void Function(Skill) onOpen;

  const AppShell({
    super.key,
    required this.result,
    required this.onRescan,
    required this.onOpen,
  });

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  AppTab _tab = AppTab.claude;

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
                  onTab: (t) => setState(() => _tab = t),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _tab == AppTab.claude
                    ? SkillListPage(
                        result: widget.result,
                        onRescan: widget.onRescan,
                        onOpen: widget.onOpen,
                      )
                    : const Center(
                        child: Text(
                          '아직 준비 중입니다',
                          style: TextStyle(color: _sub),
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
  final int count;
  final ValueChanged<AppTab> onTab;

  const _Sidebar({required this.tab, required this.count, required this.onTab});

  Widget _group(String title) => Padding(
    padding: const EdgeInsets.fromLTRB(14, 0, 14, 4),
    child: Text(
      title,
      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _sub),
    ),
  );

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
              style: TextStyle(fontWeight: t == tab ? FontWeight.w600 : FontWeight.w400),
            ),
          ),
          if (t == AppTab.claude)
            Text('$count', style: const TextStyle(fontSize: 12, color: _sub)),
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
          _group('에이전트'),
          _item(AppTab.claude),
          _item(AppTab.codex),
          const SizedBox(height: 18),
          _group('정리'),
          _item(AppTab.updates),
          _item(AppTab.unused),
          _item(AppTab.discover),
        ],
      ),
    ),
  );
}
