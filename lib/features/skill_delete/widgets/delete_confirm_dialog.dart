import 'package:flutter/material.dart';

import '../../../ui/glass.dart';
import '../skill_deleter.dart';

const _ink = Color(0xFF101828);
const _red = Color(0xFFB42318);
const _sub = Color(0xFF3A4658);

/// 지울 대상을 보여주고 확인을 받는다. 지우기로 하면 true.
/// 지울 수 없는 스킬이면 이유만 보여준다.
Future<bool> confirmSkillDelete(
  BuildContext context, {
  required String name,
  required SkillDeletePlan plan,
  int fileCount = 0,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    barrierColor: const Color(0x33101828),
    builder: (context) =>
        _DeleteDialog(name: name, plan: plan, fileCount: fileCount),
  );
  return ok == true;
}

/// 앱의 유리 패널 모양 확인창.
class _DeleteDialog extends StatelessWidget {
  const _DeleteDialog({
    required this.name,
    required this.plan,
    required this.fileCount,
  });

  final String name;
  final SkillDeletePlan plan;
  final int fileCount;

  Widget _pathBox(String path) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(top: 4),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: const Color(0x0F101828),
      borderRadius: BorderRadius.circular(10),
    ),
    child: SelectableText(
      path,
      style: const TextStyle(fontFamily: 'Menlo', fontSize: 13),
    ),
  );

  Widget _chip(
    BuildContext context,
    String label, {
    required bool result,
    bool danger = false,
  }) => GlassTap(
    onTap: () => Navigator.pop(context, result),
    color: danger ? _red : const Color(0xB3FFFFFF),
    child: Text(
      label,
      style: TextStyle(
        fontWeight: FontWeight.w600,
        color: danger ? Colors.white : _ink,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final target = plan.target;
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: GlassPanel(
          child: Material(
            type: MaterialType.transparency,
            child: DefaultTextStyle(
              style: const TextStyle(color: _ink, fontSize: 14, height: 1.5),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plan.canDelete ? '$name 삭제' : '$name은 지울 수 없다',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (plan.canDelete && target != null) ...[
                      const Text(
                        '지울 경로',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      _pathBox(target),
                      const SizedBox(height: 12),
                      if (plan.isLink) ...[
                        const Text('링크만 지운다. 원본 폴더는 남는다.'),
                        if (plan.keptOriginal case final original?) ...[
                          const SizedBox(height: 8),
                          const Text(
                            '남는 원본',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          _pathBox(original),
                        ],
                      ] else
                        Text(
                          '폴더와 안의 파일 $fileCount개를 모두 지운다. 되돌릴 수 없다.',
                          style: const TextStyle(color: _red),
                        ),
                    ] else
                      Text(
                        plan.blockedReason ?? '',
                        style: const TextStyle(color: _sub),
                      ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: plan.canDelete
                          ? [
                              _chip(context, '취소', result: false),
                              const SizedBox(width: 8),
                              _chip(context, '삭제', result: true, danger: true),
                            ]
                          : [_chip(context, '닫기', result: false)],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
