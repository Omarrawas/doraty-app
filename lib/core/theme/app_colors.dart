import 'package:flutter/material.dart';
// Export color utilities so files that import `app_colors.dart` get the
// `withValues` extension without having to import `color_utils.dart` directly.
export 'color_utils.dart';

class AppColors {
  // Primary Colors - Purple to Blue Gradient
  static const Color primaryPurple = Color(0xFF6B4CE6);
  static const Color primaryBlue = Color(0xFF4E9FF5);
  static const Color primaryDark = Color(0xFF2D1B69);

  // Gradient Colors
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryPurple, primaryBlue],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFEBF5FF), // Clear Blue-White
      Color(0xFFE0EEFF), // Soft Blue
      Color(0xFFF3F1FF), // Soft Sky-White/Purple
    ],
  );

  // Dark Mode Background Gradient - Deep Dark with Purple Accent
  static const LinearGradient darkBackgroundGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF0F0E17), // Very Dark Purple
      Color(0xFF1A1A2E), // Dark Blue-Grey
      Color(0xFF16213E), // Dark Navy
    ],
  );

  static const LinearGradient darkGradient = LinearGradient(
    colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // Background Colors
  static const Color background = Color(0xFFF8F9FE);
  static const Color cardBackground = Colors.white;
  static const Color darkBackground = Color(0xFF1A1A2E);

  // Text Colors
  static const Color textPrimary = Color(0xFF2D3142);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textLight = Color(0xFF9CA3AF);
  static const Color textWhite = Colors.white;

  // Accent Colors
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);
  static const Color accentPink = Color(0xFFEC4899);
  static const Color secondaryGold = Color(0xFFFFD700);


  // Syrian Payment Methods Colors
  static const Color shamCash = Color(0xFFFF6B00);
  static const Color syriatelCash = Color(0xFF00A651);
  static const Color mtnCash = Color(0xFFFFCC00);

  // Glassmorphism
  static Color glassBackground = Colors.white.withAlpha((0.1 * 255).round());
  static Color glassBorder = Colors.white.withAlpha((0.2 * 255).round());

  // Dynamic Theme Helpers
  static Color getCardColor(BuildContext context) {
    return Theme.of(context).cardTheme.color ??
        (Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1E1E2E).withOpacity(0.8)
            : Colors.white.withOpacity(0.9));
  }

  static Color getSurfaceColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? const Color(0xFF1A1A2E) : const Color(0xFFFAFBFF);
  }

  static Color getGlassColor(BuildContext context, {double opacity = 0.2}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Dark mode: white tint for glass; Light mode: purple/blue tint for glass
    return isDark
        ? Colors.white.withOpacity(opacity)
        : AppColors.primaryPurple.withOpacity(opacity * 0.5);
  }

  static Color getTextColor(BuildContext context, {bool secondary = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (secondary) {
      return isDark ? Colors.white70 : textSecondary;
    }
    return isDark ? Colors.white : textPrimary;
  }

  static LinearGradient getBackgroundGradient(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? darkBackgroundGradient : backgroundGradient;
  }

  // Shadows
  static List<BoxShadow> cardShadow = [
    BoxShadow(
      color: primaryPurple.withAlpha((0.1 * 255).round()),
      blurRadius: 20,
      offset: const Offset(0, 10),
    ),
  ];

  static List<BoxShadow> buttonShadow = [
    BoxShadow(
      color: primaryPurple.withAlpha((0.3 * 255).round()),
      blurRadius: 15,
      offset: const Offset(0, 5),
    ),
  ];
}

// (ColorUtils implemented in `color_utils.dart`)
