import 'dart:io';

import 'package:flutter/material.dart';

import 'access/folder_access.dart';
import 'scan/skill.dart';
import 'scan/skill_scanner.dart';
import 'ui/access_page.dart';
import 'ui/glass.dart';
import 'ui/skill_detail_page.dart';
import 'ui/skill_list_page.dart';

void main() => runApp(
  SkillGuiApp(access: createFolderAccess(), scan: scanClaude),
);

class SkillGuiApp extends StatefulWidget {
  final FolderAccess access;
  final Future<ScanResult> Function(Directory) scan;

  /// 폴더 추가 허락 버튼 표시. 샌드박스가 있는 macOS만 켠다.
  final bool showGrant;

  SkillGuiApp({
    super.key,
    required this.access,
    required this.scan,
    bool? showGrant,
  }) : showGrant = showGrant ?? Platform.isMacOS;

  @override
  State<SkillGuiApp> createState() => _SkillGuiAppState();
}

class _SkillGuiAppState extends State<SkillGuiApp> {
  final _nav = GlobalKey<NavigatorState>();
  Directory? _dir;
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
    try {
      _reduce = await widget.access.reduceTransparency();
      _dir = await widget.access.restore();
    } catch (_) {
      _dir = null;
    }
    if (_dir == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    await _rescan();
  }

  Future<void> _rescan() async {
    final dir = _dir;
    if (dir == null) return;
    setState(() {
      _loading = true;
      _failed = false;
    });
    ScanResult? r;
    try {
      r = await widget.scan(dir);
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
      builder: (_) => SkillDetailPage(
        skill: s,
        onGrantFolder: widget.showGrant
            ? (path) async {
                if (!await widget.access.grantFolder(path)) {
                  throw Exception('not granted');
                }
                await _rescan();
                _nav.currentState?.pop();
              }
            : null,
      ),
    ),
  );

  Widget _body() {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Colors.transparent,
        body: GlassBackground(child: Center(child: CircularProgressIndicator())),
      );
    }
    if (_dir == null) {
      return AccessPage(
        onPick: widget.access.pickClaudeDir,
        onGranted: (d) {
          _dir = d;
          _rescan();
        },
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
