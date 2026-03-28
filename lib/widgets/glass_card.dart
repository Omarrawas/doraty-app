import 'package:flutter/material.dart';
import 'dart:ui';

class GlassCard extends StatelessWidget {
  final Widget child;
  final double opacity;
  final double blur;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;

  const GlassCard({
    super.key,
    required this.child,
    this.opacity = 0.2,
    this.blur = 15,
    this.padding,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding ?? const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(opacity),
            borderRadius: borderRadius ?? BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withOpacity(opacity + 0.1),
              width: 1.5,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}
