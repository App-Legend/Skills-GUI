import 'package:flutter/material.dart';

import '../scan/skill.dart';
import 'glass.dart';

enum SourceFilter {
  all('전체'),
  global('전역'),
  plugin('플러그인'),
  disabled('꺼짐');

  final String label;
  const SourceFilter(this.label);

  bool matches(Skill s) => switch (this) {
        all => true,
        global => s.source != SkillSource.plugin,
        plugin => s.source == SkillSource.plugin,
        disabled => s.pluginEnabled == false,
      };
}

const _ink = Color(0xFF101828);
const _sub = Color(0xFF3A4658);

class SkillListPage extends StatefulWidget {
  final ScanResult result;
  final Future<void> Function() onRescan;
  final void Function(Skill) onOpen;

  const SkillListPage({
    super.key,
    required this.result,
    required this.onRescan,
    required this.onOpen,
  });

  @override
  State<SkillListPage> createState() => _SkillListPageState();
}

class _SkillListPageState extends State<SkillListPage> {
  SourceFilter _filter = SourceFilter.all;

  @override
  Widget build(BuildContext context) {
    final all = widget.result.skills;
    final shown = all.where(_filter.matches).toList();
    return Scaffold(
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
                    total: all.length,
                    filter: _filter,
                    onFilter: (f) => setState(() => _filter = f),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(child: _Main(shown: shown, widget: widget)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Tap extends StatelessWidget {
  final VoidCallback onTap;
  final Widget child;
  final Color? color;
  final EdgeInsets padding;

  const _Tap({
    required this.onTap,
    required this.child,
    this.color,
    this.padding = const EdgeInsets.symmetric(horizontal: 14),
  });

  @override
  Widget build(BuildContext context) => Material(
        color: color ?? Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Padding(padding: padding, child: Align(alignment: Alignment.centerLeft, widthFactor: 1, child: child)),
          ),
        ),
      );
}

class _Sidebar extends StatelessWidget {
  final int total;
  final SourceFilter filter;
  final ValueChanged<SourceFilter> onFilter;

  const _Sidebar({required this.total, required this.filter, required this.onFilter});

  @override
  Widget build(BuildContext context) => GlassPanel(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                constraints: const BoxConstraints(minHeight: 44),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(children: [
                  const Expanded(
                      child: Text('Claude Code', style: TextStyle(fontWeight: FontWeight.w600))),
                  Text('$total', style: const TextStyle(fontSize: 12, color: _sub)),
                ]),
              ),
              const SizedBox(height: 8),
              for (final f in SourceFilter.values)
                _Tap(
                  onTap: () => onFilter(f),
                  color: f == filter ? const Color(0xB3FFFFFF) : null,
                  child: Text(f.label,
                      style: TextStyle(fontWeight: f == filter ? FontWeight.w600 : FontWeight.w400)),
                ),
            ],
          ),
        ),
      );
}

class _Main extends StatelessWidget {
  final List<Skill> shown;
  final SkillListPage widget;

  const _Main({required this.shown, required this.widget});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GlassPanel(
            radius: 30,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(children: [
                const Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(left: 12),
                    child: Text('Claude Code 스킬',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                  ),
                ),
                _Tap(
                  onTap: widget.onRescan,
                  color: const Color(0xFF0064D1),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: const Text('다시 스캔',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                ),
              ]),
            ),
          ),
          for (final n in widget.result.notices)
            Padding(
              padding: const EdgeInsets.only(top: 12, left: 8),
              child: Text(n, style: const TextStyle(color: _sub)),
            ),
          const SizedBox(height: 20),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 320,
                mainAxisExtent: 168,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
              ),
              itemCount: shown.length,
              itemBuilder: (_, i) => _SkillCard(skill: shown[i], onOpen: widget.onOpen),
            ),
          ),
        ],
      );
}

class _Badge extends StatelessWidget {
  final String text;
  final Color bg;
  final Color fg;

  const _Badge(this.text, {this.bg = const Color(0x1F0064D1), this.fg = const Color(0xFF004A9C)});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
        child: Text(text, style: TextStyle(fontSize: 12, color: fg)),
      );
}

class _SkillCard extends StatelessWidget {
  final Skill skill;
  final void Function(Skill) onOpen;

  const _SkillCard({required this.skill, required this.onOpen});

  String get _tag => switch (skill.source) {
        SkillSource.global => '전역',
        SkillSource.synced => '동기화',
        SkillSource.plugin => skill.plugin ?? '플러그인',
      };

  @override
  Widget build(BuildContext context) {
    final s = skill;
    final body = s.problem?.message ?? s.description;
    return Material(
      color: const Color(0xDBFFFFFF), // 흰색 0.86
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => onOpen(s),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Wrap(spacing: 6, runSpacing: 4, children: [
                _Badge(_tag),
                if (s.pluginEnabled == false)
                  const _Badge('꺼짐', bg: Color(0x1FB42318), fg: Color(0xFFB42318)),
              ]),
              if (s.projectPath != null)
                Text(s.projectPath!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: _sub)),
              if (body != null)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(body,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: s.problem != null ? const Color(0xFFB42318) : _sub)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
