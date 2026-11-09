import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../ui/glass.dart';
import '../skill_origin.dart';

/// 설치 명령 목록. 줄마다 복사 버튼이 있다.
class InstallCommands extends StatelessWidget {
  const InstallCommands(this.origin, {super.key});
  final SkillOrigin origin;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (origin.note case final note?)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(note, style: const TextStyle(color: Color(0xFF3A4658))),
        ),
      for (final c in origin.commands) _CommandRow(c),
    ],
  );
}

class _CommandRow extends StatefulWidget {
  const _CommandRow(this.command);
  final String command;

  @override
  State<_CommandRow> createState() => _CommandRowState();
}

class _CommandRowState extends State<_CommandRow> {
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.command));
    if (!mounted) return;
    setState(() => _copied = true);
    await Future<void>.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(top: 4),
    padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
    decoration: BoxDecoration(
      color: const Color(0x0F101828),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      children: [
        Expanded(
          child: SelectableText(
            widget.command,
            style: const TextStyle(fontFamily: 'Menlo', fontSize: 13),
          ),
        ),
        Tooltip(
          message: _copied ? '복사했다' : '복사',
          child: Semantics(
            button: true,
            label: '복사',
            child: GlassTap(
              onTap: _copy,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Icon(_copied ? Icons.check : Icons.copy, size: 18),
            ),
          ),
        ),
      ],
    ),
  );
}
