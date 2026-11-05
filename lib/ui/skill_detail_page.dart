import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../features/skill_analysis/skill_analysis.dart';
import '../features/skill_analysis/skill_analysis_cache.dart';
import '../features/skill_analysis/skill_analysis_client.dart';
import '../features/skill_analysis/skill_analysis_config.dart';
import '../scan/skill.dart';
import 'glass.dart';
import 'skill_badges.dart';

const _sub = Color(0xFF3A4658);
const _red = Color(0xFFB42318);

class SkillDetailPage extends StatefulWidget {
  final Skill skill;
  final SkillAnalysisApiClient? analysisClient;
  final SkillAnalysisCache? analysisCache;

  const SkillDetailPage({
    super.key,
    required this.skill,
    this.analysisClient,
    this.analysisCache,
  });

  @override
  State<SkillDetailPage> createState() => _SkillDetailPageState();
}

class _SkillDetailPageState extends State<SkillDetailPage> {
  late final SkillAnalysisApiClient _analysisClient =
      widget.analysisClient ?? SkillAnalysisConfig.createClient();
  late final SkillAnalysisCache _analysisCache =
      widget.analysisCache ?? SkillAnalysisConfig.createCache();
  SkillAnalysis? _analysis;
  String? _analysisError;
  bool _analyzing = false;

  @override
  void initState() {
    super.initState();
    _loadAnalysis();
  }

  Future<void> _loadAnalysis() async {
    if (widget.skill.skillMd == null || widget.skill.problem != null) return;
    setState(() => _analyzing = true);
    try {
      final cached = await _analysisCache.load(widget.skill);
      final analysis = cached ?? await _analysisClient.analyze(widget.skill);
      if (cached == null) await _analysisCache.save(widget.skill, analysis);
      if (!mounted) return;
      setState(() {
        _analysis = analysis;
        _analyzing = false;
      });
    } on SkillAnalysisApiException catch (e) {
      if (mounted) {
        setState(() {
          _analysisError = e.message;
          _analyzing = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _analysisError = '한국어 분석을 만들지 못했습니다.';
          _analyzing = false;
        });
      }
    }
  }

  Widget _section(String title, Widget body) => Padding(
    padding: const EdgeInsets.only(top: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        body,
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final s = widget.skill;
    final link = s.linkTarget;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.maybePop(context),
      },
      child: Focus(autofocus: true, child: _page(context, s, link)),
    );
  }

  Widget _analysisBody() {
    if (_analyzing) {
      return const Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 8),
          Expanded(child: Text('SKILL.md와 파일 목록을 바탕으로 분석하고 있습니다.')),
        ],
      );
    }
    if (_analysisError case final error?) {
      return Text(error, style: const TextStyle(color: _red));
    }
    final analysis = _analysis;
    if (analysis == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _analysisItem('개요', [analysis.overview]),
        _analysisItem('사용 상황', analysis.whenToUse),
        _analysisItem('작동 방식', analysis.workflow),
        _analysisItem('준비 사항', analysis.requirements),
        _analysisItem('결과물', analysis.outputs),
        if (analysis.contents.isNotEmpty)
          _analysisItem('구성 요소', [
            for (final item in analysis.contents) '${item.path}: ${item.role}',
          ]),
        _analysisItem('주의 사항', analysis.cautions),
        for (final section in analysis.additionalSections)
          _analysisItem(section.title, [section.content]),
      ],
    );
  }

  Widget _analysisItem(String title, List<String> items) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final item
                  in items
                      .expand(
                        (text) => text.split(
                          RegExp(r'\n+|(?<=[.!?])\s+(?=[가-힣A-Z])'),
                        ),
                      )
                      .where((text) => text.trim().isNotEmpty))
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(item.trim()),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _page(BuildContext context, Skill s, String? link) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: DefaultTextStyle(
        style: const TextStyle(
          color: Color(0xFF101828),
          fontSize: 14,
          height: 1.5,
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GlassPanel(
                radius: 30,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => Navigator.maybePop(context),
                      icon: const Icon(Icons.chevron_left),
                      label: const Text('내 스킬'),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              GlassPanel(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.name,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Flexible(child: SkillBadge(sourceTag(s))),
                          if (s.pluginEnabled == false) ...[
                            const SizedBox(width: 6),
                            const SkillBadge(
                              '꺼짐',
                              bg: Color(0x1FB42318),
                              fg: _red,
                            ),
                          ],
                        ],
                      ),
                      if (s.projectPath != null)
                        Text(
                          s.projectPath!,
                          style: const TextStyle(color: _sub),
                        ),
                      if (s.pluginVersion != null)
                        _section('버전', SelectableText(s.pluginVersion!)),
                      _section('경로', SelectableText(s.path)),
                      if (link != null) _section('실제 경로', SelectableText(link)),
                      if (s.skillMd != null && s.problem == null)
                        Padding(
                          padding: const EdgeInsets.only(top: 20),
                          child: _analysisBody(),
                        ),
                      if (s.problem != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 20),
                          child: Text(
                            s.problem!.message,
                            style: const TextStyle(color: _red),
                          ),
                        ),
                      if (s.description != null || s.skillMd != null)
                        Material(
                          type: MaterialType.transparency,
                          child: ExpansionTile(
                            title: const Text('원문 설명'),
                            tilePadding: EdgeInsets.zero,
                            childrenPadding: const EdgeInsets.only(bottom: 16),
                            expandedCrossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              if (s.description != null)
                                _section('설명', SelectableText(s.description!)),
                              if (s.skillMd != null)
                                _section(
                                  'SKILL.md 원문',
                                  SelectableText(s.skillMd!),
                                ),
                            ],
                          ),
                        ),
                      if (s.files.isNotEmpty)
                        _section(
                          '포함된 파일',
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 240),
                            child: ListView(
                              shrinkWrap: true,
                              children: [for (final f in s.files) Text(f)],
                            ),
                          ),
                        ),
                    ],
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
