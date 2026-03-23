import 'package:flutter/material.dart';
// Export color utilities so files that import `app_colors.dart` get the
// `withValues` extension without having to import `color_utils.dart` directly.
export 'color_utils.dart';

/// ════════════════════════════════════════════════════════════════════
/// AppColors — Single Source of Truth for all colors in the app
/// ════════════════════════════════════════════════════════════════════
///
/// HOW TO USE:
///   • Static colors  → AppColors.primaryPurple
///   • Dark variants  → AppColors.dark.cardSurface
///   • Context-aware → AppColors.getTextColor(context)
///
/// TO CHANGE THE APP THEME:
///   Simply edit the color values below. All screens will update automatically.
/// ════════════════════════════════════════════════════════════════════
class AppColors {
  AppColors._(); // prevent instantiation

  // ─── Brand / Primary ────────────────────────────────────────────────
  /// Main purple – used for buttons, FAB, active states
  static const Color primaryPurple = Color(0xFF6B4CE6);

  /// Secondary accent – used for gradients and highlights
  static const Color primaryBlue = Color(0xFF4E9FF5);

  /// Deep purple used for hero gradients (home banner etc.)
  static const Color deepPurple = Color(0xFF6A11CB);

  /// Professional blue used alongside deepPurple in hero gradients
  static const Color professionalBlue = Color(0xFF2575FC);

  /// Muted purple-blue (course cards, chips)
  static const Color mutedPurpleBlue = Color(0xFF434775);

  /// Light purple (login button gradient end)
  static const Color lightPurple = Color(0xFF7B2CBF);

  /// Blue-purple gradient end (search bar, login button)
  static const Color indigoBlue = Color(0xFF5A67D8);

  /// Dark base used for dark backgrounds
  static const Color primaryDark = Color(0xFF2D1B69);

  // ─── Backgrounds ────────────────────────────────────────────────────
  static const Color background         = Color(0xFFF8F9FE);
  static const Color darkBackground     = Color(0xFF1A1A2E);
  static const Color darkNavy           = Color(0xFF16213E);
  static const Color darkDeep          = Color(0xFF0F0E17);
  static const Color darkScaffold       = Color(0xFF13131D);

  // ─── Surface / Card ─────────────────────────────────────────────────
  static const Color cardBackground     = Colors.white;
  static const Color lightSurface       = Color(0xFFF9FAFF);
  static const Color lightInputFill     = Color(0xFFFAFAFA);

  /// Dark card / appbar surface
  static const Color darkCardSurface    = Color(0xFF1E1E2E);

  /// Dark input field background
  static const Color darkInputFill      = Color(0xFF252535);

  /// Dark input fill with slight purple tint
  static const Color darkInputFillAlt   = Color(0xFF2D2D44);

  /// Dark list item / secondary surface
  static const Color darkSurface2       = Color(0xFF2A2A2A);

  /// Rich dark used in editor / math toolbar
  static const Color editorDarkBg       = Color(0xFF1E1E1E);

  // ─── Text ───────────────────────────────────────────────────────────
  static const Color textPrimary        = Color(0xFF2D3142);
  static const Color textSecondary      = Color(0xFF6B7280);
  static const Color textLight          = Color(0xFF9CA3AF);
  static const Color textWhite          = Colors.white;

  // ─── Semantic / Status ──────────────────────────────────────────────
  static const Color success            = Color(0xFF10B981);
  static const Color warning            = Color(0xFFF59E0B);
  static const Color error              = Color(0xFFEF4444);
  static const Color info               = Color(0xFF3B82F6);

  // ─── Accent / Misc ──────────────────────────────────────────────────
  static const Color accentPink         = Color(0xFFEC4899);
  static const Color secondaryGold      = Color(0xFFFFD700);
  static const Color silverRank         = Color(0xFFC0C0C0);
  static const Color bronzeRank         = Color(0xFFCD7F32);

  // ─── Notification Category Colors ───────────────────────────────────
  static const Color notifLesson        = Color(0xFF4299E1);
  static const Color notifExam          = Color(0xFFEF5350);
  static const Color notifReply         = Color(0xFF26A69A);
  static const Color notifAchievement   = Color(0xFFFFB74D);
  static const Color notifAnnouncement  = Color(0xFF7B2CBF);
  static const Color notifPromo         = Color(0xFFE91E63);
  static const Color notifSystem        = Color(0xFF607D8B);
  static const Color notifDefault       = Color(0xFF9E9E9E);

  // ─── Category Card Palette (explore screen) ─────────────────────────
  static const List<Color> categoryCardColors = [
    Color(0xFFE55A7E), // Pink
    Color(0xFF5A8DEE), // Blue
    Color(0xFFF18671), // Orange-Red
    Color(0xFF14B3C5), // Cyan
    Color(0xFF8B5CF6), // Violet
    Color(0xFF10B981), // Green
    Color(0xFFF59E0B), // Amber
    Color(0xFF6366F1), // Indigo
  ];

  // ─── Feature Menu Colors ────────────────────────────────────────────
  static const Color featureGreen       = Color(0xFF4CAF50);
  static const Color featureBlue        = Color(0xFF2196F3);
  static const Color featureAmber       = Color(0xFFFFC107);
  static const Color featurePurple      = Color(0xFF9C27B0);

  // ─── Syrian Payment Methods ─────────────────────────────────────────
  static const Color shamCash           = Color(0xFFFF6B00);
  static const Color syriatelCash       = Color(0xFF00A651);
  static const Color mtnCash            = Color(0xFFFFCC00);
  static const Color bankTransferBlue   = Color(0xFF2196F3);

  // ─── Math Toolbar / Editor ──────────────────────────────────────────
  static const Color editorAccentLight  = Color(0xFF0F6CBD);
  static const Color editorAccentDark   = Color(0xFF8AB4F8);
  static const Color editorBorderLight  = Color(0xFFD0D0D0);
  static const Color editorTextBody     = Color(0xFF1B1B1B);
  static const Color editorTextSub      = Color(0xFF5C5C5C);

  // ─── Glassmorphism ──────────────────────────────────────────────────
  static Color glassBackground = Colors.white.withAlpha((0.1 * 255).round());
  static Color glassBorder     = Colors.white.withAlpha((0.2 * 255).round());

  // ─── Gradients ──────────────────────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryPurple, primaryBlue],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Light mode page background
  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFEBF5FF), // Clear Blue-White
      Color(0xFFE0EEFF), // Soft Blue
      Color(0xFFF3F1FF), // Soft Sky-White/Purple
    ],
  );

  /// Dark mode page background
  static const LinearGradient darkBackgroundGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [darkDeep, darkBackground, darkNavy],
  );

  static const LinearGradient darkGradient = LinearGradient(
    colors: [darkBackground, darkNavy],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  /// Hero / Banner gradient (home screen top banner)
  static const LinearGradient heroBannerGradient = LinearGradient(
    colors: [deepPurple, professionalBlue],
  );

  /// Login / action button gradient
  static const LinearGradient actionButtonGradient = LinearGradient(
    colors: [lightPurple, indigoBlue],
  );

  /// Search bar active gradient
  static const LinearGradient searchGradient = LinearGradient(
    colors: [lightPurple, indigoBlue],
  );

  // ─── Shadows ────────────────────────────────────────────────────────
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

  static List<BoxShadow> actionButtonShadow = [
    BoxShadow(
      color: lightPurple.withOpacity(0.4),
      blurRadius: 20,
      offset: const Offset(0, 10),
    ),
  ];

  // ─── Context-Aware Helpers ──────────────────────────────────────────

  static Color getCardColor(BuildContext context) {
    return Theme.of(context).cardTheme.color ??
        (Theme.of(context).brightness == Brightness.dark
            ? darkCardSurface.withOpacity(0.8)
            : Colors.white.withOpacity(0.9));
  }

  static Color getSurfaceColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? darkBackground : lightSurface;
  }

  static Color getGlassColor(BuildContext context, {double opacity = 0.2}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark
        ? Colors.white.withOpacity(opacity)
        : primaryPurple.withOpacity(opacity * 0.5);
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

  static Color getDrawerBackground(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? darkBackground : Colors.white;
  }

  static Color getEditorAccent(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? editorAccentDark : editorAccentLight;
  }

  static Color getEditorSurface(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? editorDarkBg : lightInputFill;
  }

  static Color getEditorBorder(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? Colors.white12 : editorBorderLight;
  }
}
