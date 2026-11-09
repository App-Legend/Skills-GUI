import 'package:flutter/widgets.dart';

/// 처음 그려질 때 [onShow]를 한 번 부른다.
/// 긴 목록(ListView)은 화면 근처 항목만 그리므로, 보이는 항목만 요청하게 된다.
class RequestOnShow extends StatefulWidget {
  const RequestOnShow({super.key, required this.onShow, required this.child});

  final VoidCallback onShow;
  final Widget child;

  @override
  State<RequestOnShow> createState() => _RequestOnShowState();
}

class _RequestOnShowState extends State<RequestOnShow> {
  @override
  void initState() {
    super.initState();
    // 그리는 도중에 상태를 바꾸지 않도록 한 프레임 뒤에 부른다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onShow();
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
