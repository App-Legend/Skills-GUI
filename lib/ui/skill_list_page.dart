import 'package:flutter/material.dart';

import '../scan/skill.dart';
import 'glass.dart';
import 'skill_badges.dart';

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
    final shown = widget.result.skills.where(_filter.matches).toList();
    return DefaultTextStyle(
      style: const TextStyle(color: _ink, fontSize: 14, height: 1.5),
      child: _Main(
        shown: shown,
        widget: widget,
        filter: _filter,
        onFilter: (f) => setState(() => _filter = f),
      ),
    );
  }
}

class _Main extends StatelessWidget {
  final List<Skill> shown;
  final SkillListPage widget;
  final SourceFilter filter;
  final ValueChanged<SourceFilter> onFilter;

  const _Main({
    required this.shown,
    required this.widget,
    required this.filter,
    required this.onFilter,
  });

  @override
  Widget build(BuildContext context) => Column(
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
                    'Claude Code 스킬',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              GlassTap(
                onTap: widget.onRescan,
                color: const Color(0xFF0064D1),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: const Text(
                  '다시 스캔',
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
            for (final f in SourceFilter.values)
              Semantics(
                selected: f == filter,
                button: true,
                child: GlassTap(
                  onTap: () => onFilter(f),
                  color: f == filter ? const Color(0xB3FFFFFF) : null,
                  child: Text(
                    f.label,
                    style: TextStyle(
                      fontWeight: f == filter ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      for (final n in widget.result.notices)
        Padding(
          padding: const EdgeInsets.only(top: 12, left: 8),
          child: Text(n, style: const TextStyle(color: _sub)),
        ),
      const SizedBox(height: 20),
      Expanded(
        child: shown.isEmpty
            ? Center(
                child: Text(
                  widget.result.skills.isEmpty
                      ? '스킬을 찾지 못했습니다'
                      : '해당하는 스킬이 없습니다',
                  style: const TextStyle(color: _sub),
                ),
              )
            : GridView.builder(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 320,
                  mainAxisExtent: 168,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                ),
                itemCount: shown.length,
                itemBuilder: (_, i) =>
                    _SkillCard(skill: shown[i], onOpen: widget.onOpen),
              ),
      ),
    ],
  );
}

class _SkillCard extends StatelessWidget {
  final Skill skill;
  final void Function(Skill) onOpen;

  const _SkillCard({required this.skill, required this.onOpen});

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
              Text(
                s.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Flexible(child: SkillBadge(cardTag(skill))),
                  if (s.pluginEnabled == false) ...[
                    const SizedBox(width: 6),
                    const SkillBadge(
                      '꺼짐',
                      bg: Color(0x1FB42318),
                      fg: Color(0xFFB42318),
                    ),
                  ],
                ],
              ),
              if (s.projectPath != null)
                Text(
                  s.projectPath!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: _sub),
                ),
              if (body != null)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      body,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: s.problem != null
                            ? const Color(0xFFB42318)
                            : _sub,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
