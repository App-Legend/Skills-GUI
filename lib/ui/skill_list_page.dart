import 'package:flutter/material.dart';

import '../features/skill_analysis/skill_analysis.dart';
import '../features/skill_analysis/skill_analysis_store.dart';
import '../features/skill_analysis/widgets/category_badges.dart';
import '../features/skill_analysis/widgets/category_filter_panel.dart';
import '../features/scan/agent.dart';
import '../features/scan/skill.dart';
import '../features/usage/skill_usage.dart';
import 'glass.dart';
import 'skill_badges.dart';

enum SourceFilter {
  all('전체'),
  global('전역'),
  project('프로젝트'),
  plugin('플러그인'),
  disabled('꺼짐'),
  unused('미사용 후보');

  final String label;
  const SourceFilter(this.label);

  bool matches(Skill s, SkillUsage? usage, DateTime now) => switch (this) {
    all => true,
    global => s.source == SkillSource.global || s.source == SkillSource.synced,
    project => s.source == SkillSource.project,
    plugin => s.source == SkillSource.plugin,
    disabled => s.pluginEnabled == false,
    unused => usage?.isStale(s, now) == true,
  };
}

/// 미사용 후보가 무엇을 근거로 하는지. 기록이 없다고 안 쓴 것은 아니다.
String _usageNote(SkillUsage? u) {
  if (u == null) return '사용 기록을 읽는 중입니다';
  if (u.since.isEmpty) return '사용 기록을 찾지 못해 판단할 수 없습니다';
  final periods = [
    for (final MapEntry(key: a, value: t) in u.since.entries)
      '${a.label} ${t.toLocal().toString().substring(0, 10)}부터',
  ].join(', ');
  return '${SkillUsage.staleAfter.inDays}일 넘게 사용 기록이 없는 스킬입니다. '
      '확인한 기록: $periods. 다른 에이전트 스킬은 판단할 수 없어 빠집니다.';
}

/// 에이전트 필터. null은 전체.
String _agentLabel(Agent? a) => a?.label ?? '전체';

const _ink = Color(0xFF101828);
const _sub = Color(0xFF3A4658);

class SkillListPage extends StatefulWidget {
  final ScanResult result;
  final Future<void> Function() onRescan;
  final void Function(Skill) onOpen;

  /// 다시 스캔 중이면 버튼에 링을 보여준다.
  final bool scanning;

  /// 한국어 요약·카테고리. null이면 원문 설명만 보여 준다.
  final SkillAnalysisStore? analysisStore;

  /// 세션 로그 사용 기록. null이면 아직 읽는 중이다.
  final SkillUsage? usage;

  const SkillListPage({
    super.key,
    required this.result,
    required this.onRescan,
    required this.onOpen,
    this.scanning = false,
    this.analysisStore,
    this.usage,
  });

  @override
  State<SkillListPage> createState() => _SkillListPageState();
}

class _SkillListPageState extends State<SkillListPage> {
  SourceFilter _filter = SourceFilter.all;
  Agent? _agent;
  Set<String> _categories = {};
  bool _categoryOpen = false;

  @override
  void initState() {
    super.initState();
    widget.analysisStore?.request(widget.result.skills);
  }

  @override
  void didUpdateWidget(SkillListPage old) {
    super.didUpdateWidget(old);
    if (old.result != widget.result ||
        old.analysisStore != widget.analysisStore) {
      widget.analysisStore?.request(widget.result.skills);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.analysisStore;
    return DefaultTextStyle(
      style: const TextStyle(color: _ink, fontSize: 14, height: 1.5),
      child: store == null
          ? _build((_) => null, 0)
          : ListenableBuilder(
              listenable: store,
              builder: (_, _) => _build(
                store.analysisOf,
                widget.result.skills.where(store.isLoading).length,
              ),
            ),
    );
  }

  Widget _build(SkillAnalysis? Function(Skill) analysisOf, int pending) {
    final now = DateTime.now();
    final counts = <String, int>{};
    for (final s in widget.result.skills) {
      for (final c in analysisOf(s)?.categories ?? const <String>[]) {
        counts[c] = (counts[c] ?? 0) + 1;
      }
    }
    final shown = widget.result.skills
        .where((s) => _agent == null || s.agents.contains(_agent))
        .where((s) => _filter.matches(s, widget.usage, now))
        .where(
          (s) =>
              _categories.isEmpty ||
              (analysisOf(s)?.categories.any(_categories.contains) ?? false),
        )
        .toList();
    return _Main(
      shown: shown,
      widget: widget,
      filter: _filter,
      onFilter: (f) => setState(() => _filter = f),
      agent: _agent,
      onAgent: (a) => setState(() => _agent = a),
      analysisOf: analysisOf,
      categoryOpen: _categoryOpen,
      onCategoryOpen: () => setState(() => _categoryOpen = !_categoryOpen),
      categoryActive: _categories.isNotEmpty,
      categoryPanel: CategoryFilterPanel(
        counts: counts,
        selected: _categories,
        pendingCount: pending,
        onChanged: (v) => setState(() => _categories = v),
      ),
    );
  }
}

class _Main extends StatelessWidget {
  final List<Skill> shown;
  final SkillListPage widget;
  final SourceFilter filter;
  final ValueChanged<SourceFilter> onFilter;
  final Agent? agent;
  final ValueChanged<Agent?> onAgent;
  final SkillAnalysis? Function(Skill) analysisOf;
  final bool categoryOpen;
  final VoidCallback onCategoryOpen;
  final bool categoryActive;
  final Widget categoryPanel;

  const _Main({
    required this.shown,
    required this.widget,
    required this.filter,
    required this.onFilter,
    required this.agent,
    required this.onAgent,
    required this.analysisOf,
    required this.categoryOpen,
    required this.onCategoryOpen,
    required this.categoryActive,
    required this.categoryPanel,
  });

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
                    '내 스킬',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              Tooltip(
                message: '카테고리 필터',
                child: Semantics(
                  label: '카테고리 필터',
                  button: true,
                  selected: categoryOpen,
                  child: GlassTap(
                    onTap: onCategoryOpen,
                    color: categoryOpen || categoryActive
                        ? const Color(0xB3FFFFFF)
                        : null,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Icon(
                      Icons.filter_list,
                      size: 20,
                      color: categoryActive ? const Color(0xFF0064D1) : _ink,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GlassTap(
                onTap: widget.scanning ? () {} : widget.onRescan,
                color: const Color(0xFF0064D1),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: widget.scanning
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
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
      if (categoryOpen)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: GlassPanel(
            radius: 22,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: categoryPanel,
              ),
            ),
          ),
        ),
      Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Wrap(
          spacing: 6,
          runSpacing: 6, // 에이전트가 많아 창이 좁으면 줄을 바꾼다.
          children: [
            for (final a in [null, ...Agent.values])
              _chip(_agentLabel(a), a == agent, () => onAgent(a)),
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Wrap(
          spacing: 6,
          children: [
            for (final f in SourceFilter.values)
              _chip(f.label, f == filter, () => onFilter(f)),
          ],
        ),
      ),
      if (filter == SourceFilter.unused)
        Padding(
          padding: const EdgeInsets.only(top: 12, left: 8),
          child: Text(
            _usageNote(widget.usage),
            style: const TextStyle(color: _sub),
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
                  mainAxisExtent: 196,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                ),
                itemCount: shown.length,
                itemBuilder: (_, i) => _SkillCard(
                  skill: shown[i],
                  analysis: analysisOf(shown[i]),
                  onOpen: widget.onOpen,
                ),
              ),
      ),
    ],
  );
}

class _SkillCard extends StatelessWidget {
  final Skill skill;
  final SkillAnalysis? analysis;
  final void Function(Skill) onOpen;

  const _SkillCard({
    required this.skill,
    required this.analysis,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final s = skill;
    final a = analysis;
    final summary = a == null || a.summary.isEmpty ? a?.overview : a.summary;
    final body = s.problem?.message ?? summary ?? s.description;
    final categories = a?.categories ?? const <String>[];
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
                )
              else
                const Spacer(),
              if (categories.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: CategoryBadges(categories),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
