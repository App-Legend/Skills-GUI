import 'dart:io';

import 'package:flutter/material.dart';

import 'access/folder_access.dart';
import 'scan/skill.dart';
import 'scan/skill_scanner.dart';
import 'ui/glass.dart';
import 'ui/skill_detail_page.dart';
import 'ui/skill_list_page.dart';

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

  const SkillGuiApp({
    super.key,
    required this.claudeDir,
    required this.scan,
    required this.reduceTransparency,
  });

  @override
  State<SkillGuiApp> createState() => _SkillGuiAppState();
}

class _SkillGuiAppState extends State<SkillGuiApp> {
  final _nav = GlobalKey<NavigatorState>();
  ScanResult? _result;
  bool _loading = true;
  bool _failed = false;
  bool _reduce = false;

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
  }

  void _open(Skill s) => _nav.currentState!.push(
    MaterialPageRoute<void>(
      builder: (_) => SkillDetailPage(skill: s),
    ),
  );

  Widget _body() {
    if (_loading) {
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
    return SkillListPage(result: r, onRescan: _rescan, onOpen: _open);
  }

  @override
  Widget build(BuildContext context) => ReduceTransparency(
    value: _reduce,
    child: MaterialApp(
      title: 'Skill-GUI',
      debugShowCheckedModeBanner: false,
      navigatorKey: _nav,
      home: _body(),
    ),
  );
}
