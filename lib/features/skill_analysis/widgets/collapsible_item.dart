import 'package:flutter/material.dart';

import '../../../ui/glass.dart';

/// 제목 옆 화살표를 누르면 본문이 펼쳐지는 항목. 처음에는 접혀 있다.
class CollapsibleItem extends StatefulWidget {
  const CollapsibleItem({super.key, required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  State<CollapsibleItem> createState() => _CollapsibleItemState();
}

class _CollapsibleItemState extends State<CollapsibleItem> {
  bool _open = false;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Semantics(
        button: true,
        expanded: _open,
        // 버튼 안쪽 여백만큼 당겨 제목이 다른 항목 제목과 같은 줄에 선다.
        child: Transform.translate(
          offset: const Offset(-10, 0),
          child: GlassTap(
            onTap: () => setState(() => _open = !_open),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Icon(_open ? Icons.expand_less : Icons.expand_more, size: 20),
              ],
            ),
          ),
        ),
      ),
      if (_open)
        Padding(padding: const EdgeInsets.only(top: 4), child: widget.child),
    ],
  );
}
