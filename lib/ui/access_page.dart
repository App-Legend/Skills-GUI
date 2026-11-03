import 'dart:io';

import 'package:flutter/material.dart';

import 'glass.dart';

class AccessPage extends StatefulWidget {
  final Future<Directory?> Function() onPick;
  final void Function(Directory) onGranted;

  const AccessPage({super.key, required this.onPick, required this.onGranted});

  @override
  State<AccessPage> createState() => _AccessPageState();
}

class _AccessPageState extends State<AccessPage> {
  bool _busy = false;
  bool _retry = false;

  Future<void> _pick() async {
    setState(() => _busy = true);
    Directory? dir;
    try {
      dir = await widget.onPick();
    } catch (_) {
      dir = null;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (dir == null) {
      if (mounted) setState(() => _retry = true);
      return;
    }
    widget.onGranted(dir);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.transparent,
    body: GlassBackground(
      child: DefaultTextStyle(
        style: const TextStyle(color: Color(0xFF101828), fontSize: 14, height: 1.5),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: GlassPanel(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Claude Code 스킬 폴더를 허락해 주세요',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '홈 폴더의 .claude 폴더를 고르면 스킬을 읽습니다. 숨김 폴더가 안 보이면 ⌘⇧. 을 누르세요. 파일은 읽기만 합니다.',
                      style: TextStyle(color: Color(0xFF3A4658)),
                    ),
                    if (_retry) ...[
                      const SizedBox(height: 12),
                      const Text(
                        'Claude Code 설정 폴더(.claude)를 골라 주세요',
                        style: TextStyle(color: Color(0xFFB42318)),
                      ),
                    ],
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: _busy ? null : _pick,
                      child: const Text('폴더 고르기'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
