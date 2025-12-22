import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/theme_provider.dart';

/// A widget that provides a dynamic gradient background
/// that adapts to the current theme (light/dark)
class DynamicGradientBackground extends StatelessWidget {
  final Widget child;

  const DynamicGradientBackground({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: themeProvider.getBackgroundGradient(context),
      ),
      child: child,
    );
  }
}
