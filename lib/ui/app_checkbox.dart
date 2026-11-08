import 'package:flutter/material.dart';

/// 앱 공용 체크박스. 둥근 사각형 박스와 라벨을 한 줄로 그리고, 줄 전체를 눌러 바꾼다.
/// 체크는 앱 메인 파랑, 미체크는 반투명 흰색, 호버는 연한 체크 아이콘으로 구분한다.
class AppCheckbox extends StatefulWidget {
  const AppCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    required this.label,
    this.trailing,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final String label;

  /// 라벨 오른쪽에 붙일 위젯(예: 개수). 없으면 생략한다.
  final Widget? trailing;

  @override
  State<AppCheckbox> createState() => _AppCheckboxState();
}

class _AppCheckboxState extends State<AppCheckbox> {
  static const _blue = Color(0xFF0064D1);
  static const _boxOff = Color(0xB3FFFFFF); // 흰색 0.70
  static const _hoverMark = Color(0x590064D1);

  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final checked = widget.value;
    return Semantics(
      label: widget.label,
      checked: checked,
      button: true,
      excludeSemantics: true,
      onTap: () => widget.onChanged(!checked),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => widget.onChanged(!checked),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _box(checked),
                const SizedBox(width: 8),
                Text(
                  widget.label,
                  style: TextStyle(
                    color: checked ? _blue : null,
                    fontWeight: checked ? FontWeight.w600 : null,
                  ),
                ),
                if (widget.trailing != null) ...[
                  const SizedBox(width: 4),
                  widget.trailing!,
                ],
                const SizedBox(width: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _box(bool checked) => AnimatedContainer(
    duration: const Duration(milliseconds: 120),
    width: 20,
    height: 20,
    decoration: BoxDecoration(
      color: checked ? _blue : _boxOff,
      borderRadius: BorderRadius.circular(5),
    ),
    child: (checked || _hover)
        ? Icon(
            Icons.check_rounded,
            size: 15,
            color: checked ? Colors.white : _hoverMark,
          )
        : null,
  );
}
