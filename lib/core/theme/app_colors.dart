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

  // Light Mode Background Gradient - Vibrant Purple to Blue
  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF7B2CBF), // Deep Purple
      Color(0xFF5A67D8), // Purple-Blue
      Color(0xFF4299E1), // Sky Blue
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

  // Category Colors
  static const Color scienceBranch = Color(0xFF8B5CF6);
  static const Color literaryBranch = Color(0xFFEC4899);

  // Syrian Payment Methods Colors
  static const Color shamCash = Color(0xFFFF6B00);
  static const Color syriatelCash = Color(0xFF00A651);
  static const Color mtnCash = Color(0xFFFFCC00);

  // Glassmorphism
  static Color glassBackground = Colors.white.withAlpha((0.1 * 255).round());
  static Color glassBorder = Colors.white.withAlpha((0.2 * 255).round());

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
