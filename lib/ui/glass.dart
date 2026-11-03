import 'dart:ui';

import 'package:flutter/widgets.dart';

/// macOS "투명도 줄이기"가 켜졌는지 알리는 값. 조상이 없으면 false.
class ReduceTransparency extends InheritedWidget {
  final bool value;

  const ReduceTransparency({super.key, required this.value, required super.child});

  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ReduceTransparency>()?.value ??
      false;

  @override
  bool updateShouldNotify(ReduceTransparency old) => value != old.value;
}

class GlassBackground extends StatelessWidget {
  final Widget child;

  const GlassBackground({super.key, required this.child});

  static Widget _blob(Color c, double size, {double? l, double? r, double? t, double? b}) =>
      Positioned(
        left: l,
        right: r,
        top: t,
        bottom: b,
        child: ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(shape: BoxShape.circle, color: c.withValues(alpha: 0.75)),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: const Color(0xFFDCE3EE),
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            _blob(const Color(0xFF9DB8F2), 620, l: -140, t: -180),
            _blob(const Color(0xFFF3C6A8), 560, r: -120, t: 220),
            _blob(const Color(0xFFB9E3D3), 480, l: 400, b: -220),
            Positioned.fill(child: child),
          ],
        ),
      );
}

class GlassPanel extends StatelessWidget {
  final Widget child;
  final double radius;

  const GlassPanel({super.key, required this.child, this.radius = 28});

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(radius);
    if (ReduceTransparency.of(context)) {
      return DecoratedBox(
        decoration: BoxDecoration(color: const Color(0xFFF4F6FA), borderRadius: r),
        child: child,
      );
    }
    return ClipRRect(
      borderRadius: r,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0x6BFFFFFF), // 흰색 0.42
            borderRadius: r,
            border: Border.all(color: const Color(0x14000000), width: 0.5),
          ),
          child: child,
        ),
      ),
    );
  }
}
