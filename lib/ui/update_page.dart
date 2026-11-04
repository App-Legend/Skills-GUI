import 'dart:io';

import 'package:flutter/material.dart';

import '../update/claude_cli.dart';
import '../update/update_check.dart';
import 'glass.dart';

const _sub = Color(0xFF3A4658);
const _red = Color(0xFFB42318);

/// "업데이트 필요" 탭. 버튼을 눌러야 확인하고, 업데이트는 확인 창 뒤에만 실행한다.
class UpdatePage extends StatefulWidget {
  final Directory? claudeDir;
  final ClaudeCli cli;
  final Future<List<PluginUpdate>> Function(Directory) check;
  final Future<void> Function() onUpdated;

  /// 확인하거나 업데이트해서 목록이 바뀔 때마다 알린다(사이드바 개수용).
  final void Function(List<PluginUpdate>) onChecked;

  const UpdatePage({
    super.key,
    required this.claudeDir,
    required this.cli,
    required this.check,
    required this.onUpdated,
    required this.onChecked,
  });

  @override
  State<UpdatePage> createState() => _UpdatePageState();
}

class _UpdatePageState extends State<UpdatePage> {
  List<PluginUpdate>? _found;
  DateTime? _checkedAt;
  bool _busy = false;
  String? _error;
  final _failed = <String, String>{}; // id → 실패 이유

  static const _noCli = 'Claude Code 명령(claude)을 찾지 못했습니다';

  String _why(CmdResult r) {
    final msg = [r.stderr, r.stdout].map((s) => s.trim()).firstWhere(
      (s) => s.isNotEmpty,
      orElse: () => '종료 코드 ${r.exitCode}',
    );
    return msg;
  }

  Future<void> _check() async {
    final dir = widget.claudeDir;
    if (_busy || dir == null) return;
    setState(() {
      _busy = true;
      _error = null;
      _failed.clear();
    });
    final r = await widget.cli.run(['plugin', 'marketplace', 'update']);
    String? error;
    List<PluginUpdate>? found;
    if (r == null) {
      error = _noCli;
    } else {
      // 마켓 갱신이 실패해도 갖고 있는 복사본으로 비교는 한다.
      if (r.exitCode != 0) error = '최신 정보를 받지 못했습니다: ${_why(r)}';
      found = await widget.check(dir);
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = error;
      if (found != null) {
        _found = found;
        _checkedAt = DateTime.now();
      }
    });
    if (found != null) widget.onChecked(found);
  }

  Future<void> _update(PluginUpdate p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        content: Text(
          '${p.id}을(를) ${p.current} → ${p.latest}(으)로 업데이트합니다. Claude Code를 다시 시작해야 적용됩니다.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('업데이트')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    final r = await widget.cli.run(['plugin', 'update', p.id, '--scope', p.scope, '--json']);
    if (!mounted) return;
    if (r == null || r.exitCode != 0) {
      setState(() {
        _busy = false;
        _failed[p.id] = r == null
            ? _noCli
            // 명령형 설치는 사람이 명령을 확인해야 해서 앱에서 대신 승인하지 않는다.
            : '${r.stdout}${r.stderr}'.contains('shownCommand')
            ? 'Claude Code에서 직접 업데이트해 주세요'
            : '업데이트하지 못했습니다: ${_why(r)}';
      });
      return;
    }
    setState(() {
      _busy = false;
      _found = _found?.where((x) => x.id != p.id).toList();
    });
    widget.onChecked(_found ?? []);
    await widget.onUpdated();
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
                    p.id,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    p.latest == null ? '현재 ${p.current}' : '${p.current} → ${p.latest}',
                    style: const TextStyle(color: _sub),
                  ),
                  Text('스킬 ${p.skillCount}개', style: const TextStyle(fontSize: 12, color: _sub)),
                  if (_failed[p.id] case final why?)
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
                  child: _busy
                      ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                      : const Text(
                          '업데이트 확인',
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
            '플러그인만 확인합니다. 전역 스킬은 버전 정보가 없어 빠집니다.',
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
          child: _busy && found == null
              ? const Center(child: CircularProgressIndicator())
              : found == null
              ? const Center(
                  child: Text('업데이트 확인을 눌러 주세요', style: TextStyle(color: _sub)),
                )
              : ListView(
                  children: [
                    if (needed.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(8),
                        child: Text('모든 플러그인이 최신입니다', style: TextStyle(color: _sub)),
                      ),
                    for (final p in needed) _row(p),
                    if (unknown.isNotEmpty) ...[
                      const Padding(
                        padding: EdgeInsets.fromLTRB(8, 12, 8, 8),
                        child: Text('확인할 수 없음', style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                      for (final p in unknown) _row(p),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}
