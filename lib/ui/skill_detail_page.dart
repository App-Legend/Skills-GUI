import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../features/skill_analysis/skill_analysis.dart';
import '../features/skill_analysis/skill_analysis_cache.dart';
import '../features/skill_analysis/skill_analysis_client.dart';
import '../features/skill_analysis/skill_analysis_store.dart';
import '../features/skill_analysis/skill_origin.dart';
import '../features/skill_analysis/widgets/category_badges.dart';
import '../features/skill_analysis/widgets/analysis_sections.dart';
import '../features/skill_analysis/widgets/install_commands.dart';
import '../features/skill_delete/skill_deleter.dart';
import '../features/skill_delete/widgets/delete_confirm_dialog.dart';
import '../access/folder_access.dart';
import '../scan/skill.dart';
import 'glass.dart';
import 'skill_badges.dart';

const _sub = Color(0xFF3A4658);
const _red = Color(0xFFB42318);
const _faint = Color(0xFF8A94A6);

class SkillDetailPage extends StatefulWidget {
  final Skill skill;

  /// 목록과 함께 쓰는 분석 저장소. null이면 이 화면에서 따로 만든다.
  final SkillAnalysisStore? analysisStore;
  final SkillAnalysisApiClient? analysisClient;
  final SkillAnalysisCache? analysisCache;

  /// 설치 명령과 GitHub 주소를 찾는다. null이면 홈의 `.claude`에서 찾는다.
  final SkillOriginResolver? resolveOrigin;

  /// 삭제한 뒤 부른다(목록 다시 스캔).
  final Future<void> Function()? onDeleted;

  /// 실제로 지우는 함수. 테스트에서 바꿔 끼운다.
  final Future<void> Function(SkillDeletePlan plan) deleter;

  const SkillDetailPage({
    super.key,
    required this.skill,
    this.analysisStore,
    this.analysisClient,
    this.analysisCache,
    this.resolveOrigin,
    this.onDeleted,
    this.deleter = deleteSkill,
  });

  @override
  State<SkillDetailPage> createState() => _SkillDetailPageState();
}

class _SkillDetailPageState extends State<SkillDetailPage> {
  SkillAnalysisStore? _ownStore;
  late final SkillAnalysisStore _store =
      widget.analysisStore ??
      (_ownStore = SkillAnalysisStore(
        client: widget.analysisClient,
        cache: widget.analysisCache,
      ));
  SkillOrigin? _origin;

  SkillAnalysis? get _analysis => _store.analysisOf(widget.skill);
  String? get _analysisError => _store.errorOf(widget.skill);
  bool get _analyzing => _store.isLoading(widget.skill);

  @override
  void initState() {
    super.initState();
    _store.addListener(_changed);
    _store.request([widget.skill], first: true);
    _loadOrigin();
  }

  @override
  void dispose() {
    _store.removeListener(_changed);
    _ownStore?.dispose();
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> _loadOrigin() async {
    final resolve =
        widget.resolveOrigin ?? (s) => resolveSkillOrigin(s, claudeHomeDir());
    final origin = await resolve(widget.skill);
    if (mounted) setState(() => _origin = origin);
  }

  Future<void> _openGithub(String url) async {
    if (await openExternalUrl(url) || !mounted) return;
    ScaffoldMessenger.maybeOf(context)
        ?.showSnackBar(SnackBar(content: Text('브라우저를 열지 못했다: $url')));
  }

  Widget _githubButton() {
    final url = _origin?.githubUrl;
    // 내 스킬 목록의 필터 칩(전체·전역)과 같은 모양. 주소가 없으면 흐리게 두고 누를 수 없다.
    final button = Semantics(
      button: true,
      enabled: url != null,
      child: Opacity(
        opacity: url == null ? 0.4 : 1,
        child: IgnorePointer(
          ignoring: url == null,
          child: GlassTap(
            onTap: url == null ? () {} : () => _openGithub(url),
            color: const Color(0xB3FFFFFF),
            child: const Text(
              'GitHub로 가기',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ),
    );
    if (_origin == null || url != null) return button;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'GitHub 주소를 찾지 못했다',
          maxLines: 1,
          style: TextStyle(fontSize: 12, color: _sub),
        ),
        const SizedBox(width: 8),
        button,
      ],
    );
  }

  Future<void> _delete() async {
    final s = widget.skill;
    final plan = planSkillDelete(s);
    final ok = await confirmSkillDelete(
      context,
      name: s.name,
      plan: plan,
      fileCount: s.files.length,
    );
    if (!ok || !mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      await widget.deleter(plan);
    } on Object catch (e) {
      messenger?.showSnackBar(SnackBar(content: Text('삭제하지 못했다: $e')));
      return;
    }
    messenger?.showSnackBar(SnackBar(content: Text('${s.name}을 삭제했다.')));
    if (mounted) Navigator.maybePop(context);
    await widget.onDeleted?.call();
  }

  Widget _deleteButton() {
    final canDelete = planSkillDelete(widget.skill).canDelete;
    // GitHub 버튼과 같은 칩 모양. 지울 수 없으면 흐리게 두고, 누르면 이유를 보여준다.
    return Semantics(
      button: true,
      label: '스킬 삭제',
      child: Opacity(
        opacity: canDelete ? 1 : 0.4,
        child: GlassTap(
          onTap: _delete,
          color: const Color(0xB3FFFFFF),
          child: const Text(
            '삭제',
            style: TextStyle(fontWeight: FontWeight.w600, color: _red),
          ),
        ),
      ),
    );
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
          Expanded(child: Text('SKILL.md와 파일 목록을 바탕으로 분석하고 있다.')),
        ],
      );
    }
    if (_analysisError case final error?) {
      return Row(
        children: [
          Flexible(
            child: Text(error, style: const TextStyle(color: _red)),
          ),
          const SizedBox(width: 8),
          GlassTap(
            onTap: () => _store.retry(widget.skill),
            color: const Color(0xB3FFFFFF),
            child: const Text(
              '다시 시도',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      );
    }
    final analysis = _analysis;
    if (analysis == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: AnalysisSections(analysis),
    );
  }

  /// 이름 아래 작고 흐린 보조 정보.
  Widget _meta(String text) =>
      SelectableText(text, style: const TextStyle(fontSize: 12, color: _faint));

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
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF101828),
                      ),
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
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              s.name,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (s.source != SkillSource.synced) ...[
                            const SizedBox(width: 12),
                            // 자기 너비만 쓰고 오른쪽 끝에 붙는다. 이름이 남은 너비를 모두 쓴다.
                            _githubButton(),
                            const SizedBox(width: 8),
                            _deleteButton(),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      _meta(s.path),
                      if (link != null) _meta('실제 경로: $link'),
                      if (s.pluginVersion != null)
                        _meta('버전 ${s.pluginVersion}'),
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
                          if (_analysis?.categories case final c?
                              when c.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Flexible(flex: 2, child: CategoryBadges(c)),
                          ],
                        ],
                      ),
                      if (s.projectPath != null)
                        Text(
                          s.projectPath!,
                          style: const TextStyle(color: _sub),
                        ),
                      if (_origin case final origin?
                          when origin.commands.isNotEmpty)
                        _section('설치방법', InstallCommands(origin)),
                      if (s.skillMd != null && s.problem == null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
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
