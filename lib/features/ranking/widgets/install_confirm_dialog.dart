import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../ui/glass.dart';

const _ink = Color(0xFF101828);
const _sub = Color(0xFF3A4658);
const _blue = Color(0xFF0064D1);
const _green = Color(0xFF067647);
const _amber = Color(0xFF8A5A00);
const _red = Color(0xFFB42318);

/// 보안 점검 요약의 종류. 색과 아이콘이 달라진다.
enum AuditTone { passed, warning, none }

/// 앱 유리 패널 모양의 설치 확인 창. 설치하면 true, 취소하면 false.
Future<bool?> showInstallConfirm(
  BuildContext context, {
  required String name,
  required String source,
  required String target,
  required String path,
  required int fileCount,
  required String auditText,
  required AuditTone auditTone,
  required bool replacing,
}) => showDialog<bool>(
  context: context,
  barrierColor: const Color(0x33101828),
  builder: (context) => InstallConfirmDialog(
    name: name,
    source: source,
    target: target,
    path: path,
    fileCount: fileCount,
    auditText: auditText,
    auditTone: auditTone,
    replacing: replacing,
  ),
);

class InstallConfirmDialog extends StatelessWidget {
  const InstallConfirmDialog({
    super.key,
    required this.name,
    required this.source,
    required this.target,
    required this.path,
    required this.fileCount,
    required this.auditText,
    required this.auditTone,
    required this.replacing,
  });

  final String name;
  final String source;
  final String target;
  final String path;
  final int fileCount;
  final String auditText;
  final AuditTone auditTone;

  /// 같은 이름의 스킬을 바꾸는 경우.
  final bool replacing;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(28);
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: ClipRRect(
          borderRadius: radius,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xEBFFFFFF),
                borderRadius: radius,
                border: Border.all(color: const Color(0x14000000), width: 0.5),
              ),
              child: DefaultTextStyle(
                style: const TextStyle(color: _ink, fontSize: 14, height: 1.5),
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _heading(),
                      const SizedBox(height: 20),
                      _infoBox(),
                      const SizedBox(height: 12),
                      _audit(),
                      if (replacing) ...[
                        const SizedBox(height: 10),
                        _note(
                          Icons.warning_amber_rounded,
                          '같은 이름의 폴더를 새 파일로 바꾼다. 그 폴더에서 고친 내용은 사라진다.',
                          _red,
                        ),
                      ],
                      const SizedBox(height: 14),
                      const Text(
                        '스킬은 에이전트에게 주는 지시문이다. 믿을 수 있는 출처인지 확인해야 한다.',
                        style: TextStyle(fontSize: 12, color: _sub),
                      ),
                      const SizedBox(height: 22),
                      _buttons(context),
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

  Widget _heading() => Row(
    children: [
      Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: const Color(0x1F0064D1),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(
          replacing ? Icons.sync_rounded : Icons.download_rounded,
          color: _blue,
        ),
      ),
      const SizedBox(width: 14),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              replacing ? '이미 있는 스킬을 바꿀까?' : '스킬을 설치할까?',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            Text(
              '$name · $source',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, color: _sub),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _infoBox() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(
      color: const Color(0xFFF4F6FA),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      children: [
        _row('설치할 곳', Text(target)),
        _row(
          '위치',
          Text(
            path,
            style: const TextStyle(
              fontFamily: 'Consolas',
              fontFamilyFallback: ['Menlo', 'monospace'],
              fontSize: 13,
            ),
          ),
        ),
        _row('파일', Text('$fileCount개')),
      ],
    ),
  );

  static Widget _row(String label, Widget value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 72,
          child: Text(label, style: const TextStyle(color: _sub)),
        ),
        Expanded(child: value),
      ],
    ),
  );

  Widget _audit() => switch (auditTone) {
    AuditTone.passed => _note(Icons.verified_user_rounded, auditText, _green),
    AuditTone.warning => _note(Icons.gpp_maybe_rounded, auditText, _red),
    AuditTone.none => _note(Icons.shield_outlined, auditText, _amber),
  };

  static Widget _note(IconData icon, String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 13, color: color, height: 1.45),
          ),
        ),
      ],
    ),
  );

  Widget _buttons(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.end,
    children: [
      GlassTap(
        key: const Key('ranking-install-cancel'),
        onTap: () => Navigator.pop(context, false),
        color: const Color(0xFFE8EEF8),
        padding: const EdgeInsets.symmetric(horizontal: 22),
        child: const Text('취소', style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      const SizedBox(width: 8),
      GlassTap(
        key: const Key('ranking-install-confirm'),
        onTap: () => Navigator.pop(context, true),
        color: _blue,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Text(
          replacing ? '바꾸기' : '설치',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ],
  );
}
