import 'dart:io';

import 'package:flutter/material.dart';

import '../scan/skill.dart';
import 'glass.dart';
import 'skill_badges.dart';

const _sub = Color(0xFF3A4658);
const _red = Color(0xFFB42318);

class SkillDetailPage extends StatelessWidget {
  final Skill skill;

  /// null이면 허락 버튼을 숨긴다 (Windows).
  final Future<void> Function(String path)? onGrantFolder;

  const SkillDetailPage({super.key, required this.skill, this.onGrantFolder});

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
    final s = skill;
    final link = s.linkTarget;
    final canGrant =
        s.problem?.kind == ProblemKind.noPermission &&
        link != null &&
        onGrantFolder != null;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GlassBackground(
        child: DefaultTextStyle(
          style: const TextStyle(color: Color(0xFF101828), fontSize: 14, height: 1.5),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                GlassPanel(
                  radius: 30,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: () => Navigator.maybePop(context),
                        child: const Text('Claude Code 스킬'),
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
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Flexible(child: SkillBadge(sourceTag(s))),
                            if (s.pluginEnabled == false) ...[
                              const SizedBox(width: 6),
                              const SkillBadge('꺼짐', bg: Color(0x1FB42318), fg: _red),
                            ],
                          ],
                        ),
                        if (s.projectPath != null)
                          Text(s.projectPath!, style: const TextStyle(color: _sub)),
                        if (s.pluginVersion != null)
                          _section('버전', SelectableText(s.pluginVersion!)),
                        _section('경로', SelectableText(s.path)),
                        if (link != null)
                          _section('실제 경로', SelectableText(link)),
                        if (s.description != null)
                          _section('설명', Text(s.description!)),
                        if (s.problem != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 20),
                            child: Text(s.problem!.message, style: const TextStyle(color: _red)),
                          ),
                        if (canGrant)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: _GrantButton(
                              onGrant: () => onGrantFolder!(File(link).parent.path),
                            ),
                          ),
                        if (s.skillMd != null)
                          _section(
                            'SKILL.md 원문',
                            SelectableText(
                              s.skillMd!,
                              style: const TextStyle(fontFamily: 'Menlo', fontSize: 13),
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
      ),
    );
  }
}

class _GrantButton extends StatefulWidget {
  final Future<void> Function() onGrant;

  const _GrantButton({required this.onGrant});

  @override
  State<_GrantButton> createState() => _GrantButtonState();
}

class _GrantButtonState extends State<_GrantButton> {
  bool _busy = false;
  bool _failed = false;

  Future<void> _run() async {
    setState(() {
      _busy = true;
      _failed = false;
    });
    try {
      await widget.onGrant();
    } catch (_) {
      _failed = true;
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      FilledButton(
        onPressed: _busy ? null : _run,
        child: const Text('폴더 추가 허락'),
      ),
      if (_failed)
        const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text('폴더를 허락하지 못했습니다', style: TextStyle(color: _red)),
        ),
    ],
  );
}
