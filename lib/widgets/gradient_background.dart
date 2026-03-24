import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

class GradientBackground extends StatelessWidget {
  final Widget child;

  GradientBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: AppColors.getBackgroundGradient(context),
      ),
      child: child,
    );
  }
}
