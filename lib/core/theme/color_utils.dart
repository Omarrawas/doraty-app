import 'package:flutter/material.dart';

/// Small Color utilities to avoid precision loss when setting alpha.
///
/// Use `color.withValues(0.2)` instead of the deprecated `withOpacity`.
/// This returns a new [Color] with the given opacity (0.0 - 1.0) using
/// integer alpha to avoid precision loss across color spaces.
extension ColorUtils on Color {
  /// Returns a color with the given opacity (0.0 - 1.0).
  ///
  /// The returned color uses `Color.fromARGB` with a rounded 0-255 alpha
  /// value to avoid floating-point precision issues.
  Color withValues(double opacity) {
    // Compute integer alpha (0-255) from opacity (0.0-1.0) without casts.
    int a = (opacity * 255).round();
    if (a < 0) {
      a = 0;
    } else if (a > 255) {
      a = 255;
    }
    return Color.fromARGB(a, red, green, blue);
  }

  /// Convenience: same as [withValues], but accepts an int 0-255 alpha.
  Color withAlphaByte(int alpha) {
    final a = alpha.clamp(0, 255);
    return Color.fromARGB(a, red, green, blue);
  }
}
