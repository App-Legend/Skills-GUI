import 'dart:io';

import 'package:flutter/material.dart';

import 'access/folder_access.dart';
import 'scan/skill.dart';
import 'scan/skill_scanner.dart';
import 'ui/glass.dart';
import 'ui/app_shell.dart';
import 'ui/update_page.dart';
import 'update/claude_cli.dart';
import 'update/update_check.dart';

void main() => runApp(
  SkillGuiApp(
    claudeDir: claudeHomeDir(),
    scan: scanClaude,
    reduceTransparency: reduceTransparency,
  ),
);

class SkillGuiApp extends StatefulWidget {
  final Directory? claudeDir;
  final Future<ScanResult> Function(Directory) scan;
  final Future<bool> Function() reduceTransparency;
  final ClaudeCli cli;
  final Future<List<PluginUpdate>> Function(Directory) findUpdates;

  SkillGuiApp({
    super.key,
    required this.claudeDir,
    required this.scan,
    required this.reduceTransparency,
    ClaudeCli? cli,
    this.findUpdates = checkUpdates,
  }) : cli = cli ?? ProcessClaudeCli();

  @override
  State<SkillGuiApp> createState() => _SkillGuiAppState();
}

class _SkillGuiAppState extends State<SkillGuiApp> {
  ScanResult? _result;
  bool _loading = true;
  bool _failed = false;
  bool _reduce = false;
  int _updateCount = 0;

  static int _needed(List<PluginUpdate> l) =>
      l.where((p) => p.state == UpdateState.needed).length;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    _reduce = await widget.reduceTransparency();
    await _rescan();
  }

  Future<void> _rescan() async {
    final dir = widget.claudeDir;
    setState(() {
      _loading = true;
      _failed = false;
    });
    ScanResult? r;
    try {
      if (dir != null) r = await widget.scan(dir);
    } catch (_) {
      r = null;
    }
    if (!mounted) return;
    setState(() {
      _result = r;
      _failed = r == null;
      _loading = false;
    });
    // 인터넷 없이 컴퓨터 안 마켓 복사본과 비교해 사이드바 개수만 먼저 채운다.
    if (dir != null) {
      final n = _needed(await widget.findUpdates(dir));
      if (mounted) setState(() => _updateCount = n);
    }
  }

  Widget _body() {
    // 처음 스캔할 때만 로딩 화면. 다시 스캔할 때는 탭·필터가 남도록 지금 화면을 둔다.
    if (_loading && _result == null) {
      return const Scaffold(
        backgroundColor: Colors.transparent,
        body: GlassBackground(child: Center(child: CircularProgressIndicator())),
      );
    }
    final r = _result;
    if (_failed || r == null) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: GlassBackground(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('스캔하지 못했습니다'),
                const SizedBox(height: 12),
                FilledButton(onPressed: _rescan, child: const Text('다시 스캔')),
              ],
            ),
          ),
        ),
      );
    }
    return AppShell(
      result: r,
      onRescan: _rescan,
      scanning: _loading,
      updateCount: _updateCount,
      updates: UpdatePage(
        claudeDir: widget.claudeDir,
        cli: widget.cli,
        check: widget.findUpdates,
        onUpdated: _rescan,
        onChecked: (l) => setState(() => _updateCount = _needed(l)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ReduceTransparency(
    value: _reduce,
    child: MaterialApp(
      title: 'Skill-GUI',
      debugShowCheckedModeBanner: false,
      home: _body(),
    ),
  );
}
