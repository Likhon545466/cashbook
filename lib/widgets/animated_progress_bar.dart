import 'package:flutter/material.dart';

class AnimatedProgressBar extends StatelessWidget {
  final double value;
  final double height;
  final Duration duration;

  const AnimatedProgressBar({
    super.key,
    required this.value,
    this.height = 8,
    this.duration = const Duration(milliseconds: 450),
  });

  @override
  Widget build(BuildContext context) {
    final target = value.clamp(0.0, 1.0);

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: target),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, animatedValue, _) {
        return LinearProgressIndicator(
          value: animatedValue,
          minHeight: height,
          borderRadius: BorderRadius.circular(24),
        );
      },
    );
  }
}
