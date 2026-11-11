import 'dart:io';

import 'package:flutter/material.dart';

import '../features/update/claude_cli.dart';
import '../features/update/update_check.dart';
import 'glass.dart';

const _sub = Color(0xFF3A4658);
const _red = Color(0xFFB42318);

/// "업데이트 필요" 탭. 처음 열릴 때 바로 확인하고, 업데이트는 확인 창 뒤에만 실행한다.
class UpdatePage extends StatefulWidget {
  final Directory? claudeDir;
  final ClaudeCli cli;
  final Future<List<PluginUpdate>> Function(Directory) check;
  final Future<List<String>> Function(Directory) markets;
  final Future<void> Function() onUpdated;

  /// 스킬 업데이트를 확인하는 곳(npx skills, 앱 설치 기록). 비면 플러그인만 확인한다.
  final List<SkillUpdateSource> sources;

  /// 확인하거나 업데이트해서 목록이 바뀔 때마다 알린다(사이드바 개수용).
  final void Function(List<PluginUpdate>) onChecked;

  const UpdatePage({
    super.key,
    required this.claudeDir,
    required this.cli,
    required this.check,
    this.markets = installedMarkets,
    required this.onUpdated,
    required this.onChecked,
    this.sources = const [],
  });

  @override
  State<UpdatePage> createState() => _UpdatePageState();
}

class _UpdatePageState extends State<UpdatePage> {
  List<PluginUpdate>? _found;
  DateTime? _checkedAt;
  bool _busy = false;
  bool _checking = false; // 업데이트 실행이 아닌 확인 중
  String? _error;
  final _failed = <String, String>{}; // PluginUpdate.key → 실패 이유

  static const _noCli = 'Claude Code 명령(claude)을 찾지 못했습니다';

  String _why(CmdResult r) {
    final msg = [r.stderr, r.stdout].map((s) => s.trim()).firstWhere(
      (s) => s.isNotEmpty,
      orElse: () => '종료 코드 ${r.exitCode}',
    );
    return msg;
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(_check);
  }

  Future<void> _check() async {
    final dir = widget.claudeDir;
    if (_busy || dir == null) return;
    setState(() {
      _busy = true;
      _checking = true;
      _found = null;
      _error = null;
      _failed.clear();
    });
    final errors = <String>[];
    // 끝난 곳부터 목록에 더한다. found가 null이면 확인 자체를 못 한 것.
    void add(List<PluginUpdate>? found, List<String> e) {
      if (!mounted) return;
      setState(() {
        if (found != null) _found = withoutDuplicateApp([...?_found, ...found]);
        errors.addAll(e);
        _error = errors.isEmpty ? null : errors.join('\n');
      });
    }

    // 플러그인과 스킬 확인을 함께 돌린다. npx는 스킬이 많은 프로젝트에서 오래 걸린다.
    await Future.wait([
      _checkPlugins(dir).then((r) => add(r.found, r.errors)),
      for (final s in widget.sources) s.check().forEach((r) => add(r.found, r.errors)),
    ]);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _checking = false;
      if (_found != null) _checkedAt = DateTime.now();
    });
    if (_found case final found?) widget.onChecked(found);
  }

  Future<({List<PluginUpdate>? found, List<String> errors})> _checkPlugins(Directory dir) async {
    final missed = <String>[];
    for (final m in await widget.markets(dir)) {
      final r = await widget.cli.run(['plugin', 'marketplace', 'update', m]);
      if (r == null) return (found: null, errors: [_noCli]);
      if (r.exitCode != 0) missed.add('$m(${_why(r)})');
    }
    // 마켓 갱신이 실패해도 갖고 있는 복사본으로 비교는 한다.
    return (
      found: await widget.check(dir),
      errors: [if (missed.isNotEmpty) '최신 정보를 받지 못했습니다: ${missed.join(', ')}'],
    );
  }

  Future<void> _update(PluginUpdate p) async {
    final source = widget.sources.where((s) => s.kind == p.kind).firstOrNull;
    final isSkill = p.kind != UpdateKind.plugin;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        content: Text(
          isSkill
              ? '${_title(p)} 스킬을 원본 최신 내용으로 바꿉니다(${p.agent?.label ?? p.projectPath ?? '전역'}). 이 스킬 폴더를 직접 고쳤다면 그 내용은 사라집니다.'
              : '${p.id}을(를) ${p.current} → ${p.latest}(으)로 업데이트합니다. Claude Code를 다시 시작해야 적용됩니다.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('업데이트')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    if (source != null) {
      final why = await source.update(p);
      if (!mounted) return;
      if (why != null) {
        setState(() {
          _busy = false;
          _failed[p.key] = why;
        });
        return;
      }
      await _done(p);
      return;
    }
    final r = await widget.cli.run(['plugin', 'update', p.id, '--scope', p.scope, '--json']);
    if (!mounted) return;
    if (r == null || r.exitCode != 0) {
      setState(() {
        _busy = false;
        _failed[p.key] = r == null
            ? _noCli
            // 명령형 설치는 사람이 명령을 확인해야 해서 앱에서 대신 승인하지 않는다.
            : '${r.stdout}${r.stderr}'.contains('shownCommand')
            ? 'Claude Code에서 직접 업데이트해야 합니다'
            : '업데이트하지 못했습니다: ${_why(r)}';
      });
      return;
    }
    await _done(p);
  }

  Future<void> _done(PluginUpdate p) async {
    setState(() {
      _busy = false;
      _found = _found?.where((x) => x.key != p.key).toList();
    });
    widget.onChecked(_found ?? []);
    await widget.onUpdated();
  }

  /// 앱 설치 항목의 id는 `source/slug`라 이름(slug)만 보인다.
  static String _title(PluginUpdate p) =>
      p.kind == UpdateKind.app ? p.id.split('/').last : p.id;

  /// "현재 버전 1.0 → 최신 버전 1.1". 버전이 없는 스킬은 새 내용이 있다는 것만 알린다.
  Widget _version(PluginUpdate p) {
    const label = TextStyle(color: _sub);
    const value = TextStyle(fontWeight: FontWeight.w600);
    if (p.current.isEmpty) {
      return Text(
        p.state == UpdateState.needed ? '버전 정보 없음 · 원본에 새 내용 있음' : '버전 정보 없음',
        style: label,
      );
    }
    return Text.rich(
      TextSpan(
        style: label,
        children: [
          const TextSpan(text: '현재 버전 '),
          TextSpan(text: p.current, style: value),
          if (p.latest case final latest?) ...[
            const TextSpan(text: ' → 최신 버전 '),
            TextSpan(text: latest, style: value.copyWith(color: const Color(0xFF0064D1))),
          ] else
            const TextSpan(text: ' · 최신 버전 확인 불가'),
        ],
      ),
    );
  }

  Widget _row(PluginUpdate p) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Material(
      color: const Color(0xDBFFFFFF),
      borderRadius: BorderRadius.circular(22),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _title(p),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  _version(p),
                  Text(
                    switch (p.kind) {
                      UpdateKind.plugin => 'Claude Code 플러그인 · 스킬 ${p.skillCount}개',
                      UpdateKind.skill => 'npx skills · ${p.projectPath ?? '전역'}',
                      UpdateKind.app => '앱으로 설치 · ${p.agent?.label ?? '전역'} · ${p.id}',
                    },
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: _sub),
                  ),
                  if (_failed[p.key] case final why?)
                    Text(why, style: const TextStyle(color: _red)),
                ],
              ),
            ),
            if (p.state == UpdateState.needed)
              FilledButton(
                onPressed: _busy ? null : () => _update(p),
                child: const Text('업데이트'),
              ),
          ],
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final found = _found;
    final needed = found?.where((p) => p.state == UpdateState.needed).toList() ?? [];
    final unknown = found?.where((p) => p.state == UpdateState.unknown).toList() ?? [];
    final at = _checkedAt;
    return Column(
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
                      '업데이트 필요',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                if (at != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Text(
                      '마지막 확인 ${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}',
                      style: const TextStyle(fontSize: 12, color: _sub),
                    ),
                  ),
                GlassTap(
                  onTap: _busy ? () {} : _check,
                  color: const Color(0xFF0064D1),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _checking
                      ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                      : Text(
                          at == null ? '업데이트 확인' : '다시 조회',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                        ),
                ),
              ],
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.only(top: 12, left: 8),
          child: Text(
            'Claude Code 플러그인, npx skills와 이 앱의 설치 버튼으로 설치한 스킬을 확인합니다. 손으로 넣은 스킬은 설치 기록이 없어 빠집니다.',
            style: TextStyle(fontSize: 12, color: _sub),
          ),
        ),
        if (_error case final e?)
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 8),
            child: Text(e, style: const TextStyle(color: _red)),
          ),
        const SizedBox(height: 16),
        Expanded(
          child: _checking && found == null
              ? const _Skeleton()
              : found == null
              ? const Center(
                  child: Text('업데이트 확인을 누르면 됩니다', style: TextStyle(color: _sub)),
                )
              : ListView(
                  children: [
                    if (needed.isEmpty && !_checking)
                      const Padding(
                        padding: EdgeInsets.all(8),
                        child: Text('모두 최신입니다', style: TextStyle(color: _sub)),
                      ),
                    for (final p in needed) _row(p),
                    if (unknown.isNotEmpty) ...[
                      const Padding(
                        padding: EdgeInsets.fromLTRB(8, 12, 8, 8),
                        child: Text('확인할 수 없음', style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                      for (final p in unknown) _row(p),
                    ],
                    if (_checking)
                      const Padding(
                        padding: EdgeInsets.all(8),
                        child: Row(
                          spacing: 10,
                          children: [
                            SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            Text('나머지를 확인하는 중입니다', style: TextStyle(color: _sub)),
                          ],
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

/// 확인 중 자리표시. 목록 행과 같은 모양 위로 빛이 왼쪽에서 오른쪽으로 지나간다.
class _Skeleton extends StatefulWidget {
  const _Skeleton();

  @override
  State<_Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<_Skeleton> with SingleTickerProviderStateMixin {
  late final _sweep = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  static const _base = Color(0xFFE4E8EE);
  static const _shine = Color(0xFFF7F9FC);

  @override
  void dispose() {
    _sweep.dispose();
    super.dispose();
  }

  static Widget _bar(double width, double height, {double radius = 6}) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(color: _base, borderRadius: BorderRadius.circular(radius)),
  );

  // 행 안의 칸들만 빛을 받는다. 카드 배경은 그대로.
  Widget _shimmer(Widget child) => AnimatedBuilder(
    animation: _sweep,
    child: child,
    builder: (_, child) => ShaderMask(
      blendMode: BlendMode.srcATop,
      shaderCallback: (r) => LinearGradient(
        colors: const [_base, _shine, _base],
        stops: const [0.35, 0.5, 0.65],
        transform: _Slide(_sweep.value),
      ).createShader(r),
      child: child,
    ),
  );

  Widget _card() => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xDBFFFFFF),
      borderRadius: BorderRadius.circular(22),
    ),
    child: _shimmer(
      Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 8,
              children: [_bar(180, 16), _bar(110, 13), _bar(70, 11)],
            ),
          ),
          _bar(84, 36, radius: 18), // 업데이트 버튼 자리
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    // 움직임 줄이기면 빛이 화면 밖에 멈춘 채로 둔다.
    if (MediaQuery.disableAnimationsOf(context)) _sweep.value = 0;
    return ListView(
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(8, 0, 8, 12),
          child: Text('최신 정보를 받는 중입니다', style: TextStyle(color: _sub)),
        ),
        for (var i = 0; i < 3; i++) _card(),
      ],
    );
  }
}

/// 그라디언트를 가로로 한 폭씩 밀어 빛이 왼쪽 밖에서 오른쪽 밖으로 지나가게 한다.
class _Slide extends GradientTransform {
  final double t;

  const _Slide(this.t);

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) =>
      Matrix4.translationValues(bounds.width * (t * 2 - 1), 0, 0);
}
