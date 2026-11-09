import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 어두운 바탕의 명령어 블록과 복사 버튼.
///
/// [display] 는 화면에 보이는 (여러 줄일 수 있는) 명령, [copyText] 는 복사할 문자열이다.
/// [onRun] 이 있으면 실행 버튼을 붙인다 (지금 운영체제의 명령일 때만 준다).
class CommandBlock extends StatefulWidget {
  const CommandBlock({
    super.key,
    required this.display,
    required this.copyText,
    this.onRun,
  });

  final String display;
  final String copyText;
  final VoidCallback? onRun;

  @override
  State<CommandBlock> createState() => _CommandBlockState();
}

class _CommandBlockState extends State<CommandBlock> {
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.copyText));
    if (!mounted) return;
    setState(() => _copied = true);
    await Future<void>.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: const Color(0xFF111827),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(18, 16, 8, 16),
            child: SelectableText(
              widget.display,
              style: const TextStyle(
                fontFamily: 'Consolas',
                fontFamilyFallback: ['Menlo', 'monospace'],
                fontSize: 13,
                height: 1.7,
                color: Color(0xFFE5E7EB),
              ),
            ),
          ),
        ),
        if (widget.onRun != null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: TextButton.icon(
              key: const Key('command-run'),
              onPressed: widget.onRun,
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF6CE9A6),
              ),
              icon: const Icon(Icons.play_arrow_rounded, size: 18),
              label: const Text('실행'),
            ),
          ),
        Padding(
          padding: const EdgeInsets.all(6),
          child: IconButton(
            key: const Key('command-copy'),
            tooltip: _copied ? '복사했다' : '명령 복사',
            onPressed: _copy,
            icon: Icon(
              _copied ? Icons.check : Icons.copy_rounded,
              size: 18,
              color: _copied
                  ? const Color(0xFF6CE9A6)
                  : const Color(0xFF9CA3AF),
            ),
          ),
        ),
      ],
    ),
  );
}
