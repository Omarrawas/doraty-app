import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Export color utilities so files that import `app_colors.dart` get the
// `withValues` extension without having to import `color_utils.dart` directly.
export 'color_utils.dart';

@immutable
class AppColorPalette {
  final Brightness brightness;
  final Color primary;
  final Color secondary;
  final Color background;
  final Color scaffoldBackground;
  final Color surface;
  final Color surfaceElevated;
  final Color card;
  final Color dialog;
  final Color drawerBackground;
  final Color inputFill;
  final Color inputFillAlt;
  final Color appBarBackground;
  final Color appBarForeground;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color iconPrimary;
  final Color iconSecondary;
  final Color border;
  final Color borderStrong;
  final Color glass;
  final Color glassStrong;
  final Color navBackground;
  final Color shimmerBase;
  final Color shimmerHighlight;
  final LinearGradient backgroundGradient;
  final SystemUiOverlayStyle overlayStyle;

  const AppColorPalette({
    required this.brightness,

    required this.primary,
    required this.secondary,
    required this.background,
    required this.scaffoldBackground,
    required this.surface,
    required this.surfaceElevated,
    required this.card,
    required this.dialog,
    required this.drawerBackground,
    required this.inputFill,
    required this.inputFillAlt,
    required this.appBarBackground,
    required this.appBarForeground,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.iconPrimary,
    required this.iconSecondary,
    required this.border,
    required this.borderStrong,
    required this.glass,
    required this.glassStrong,
    required this.navBackground,
    required this.shimmerBase,
    required this.shimmerHighlight,
    required this.backgroundGradient,
    required this.overlayStyle,
  });

  bool get isDark => brightness == Brightness.dark;
}

/// Single source of truth for app colors.
class AppColors {
  AppColors._();

  // Brand
  static const Color primaryPurple = Color(0xFF6B4CE6);
  static const Color primaryBlue = Color(0xFF4E9FF5);
  static const Color deepPurple = Color(0xFF6A11CB);
  static const Color professionalBlue = Color(0xFF2575FC);
  static const Color mutedPurpleBlue = Color(0xFF434775);
  static const Color lightPurple = Color(0xFF7B2CBF);
  static const Color indigoBlue = Color(0xFF5A67D8);
  static const Color primaryDark = Color(0xFF2D1B69);

  // Legacy base colors kept as const because many screens still use them in
  // const widgets such as BoxDecoration(...).
  static const Color background = Color(0xFFF4F7FF);
  static const Color darkBackground = Color(0xFF111320);
  static const Color darkNavy = Color(0xFF18233A);
  static const Color darkDeep = Color(0xFF0C0F1B);
  static const Color darkScaffold = Color(0xFF111320);
  static const Color cardBackground = Color(0xFFFFFFFF);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightInputFill = Color(0xFFF8FAFF);
  static const Color darkCardSurface = Color(0xFF1B1F31);
  static const Color darkInputFill = Color(0xFF1E2338);
  static const Color darkInputFillAlt = Color(0xFF252B44);
  static const Color darkSurface2 = Color(0xFF1D2135);
  static const Color editorDarkBg = Color(0xFF161922);
  static const Color textPrimary = Color(0xFF1F2937);
  static const Color textSecondary = Color(0xFF5B6474);
  static const Color textLight = Color(0xFF8A94A6);
  static const Color textWhite = Color(0xFFF8FAFC);

  // Semantic
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  // Accent / misc
  static const Color accentPink = Color(0xFFEC4899);
  static const Color secondaryGold = Color(0xFFFFD700);
  static const Color silverRank = Color(0xFFC0C0C0);
  static const Color bronzeRank = Color(0xFFCD7F32);

  // Notifications
  static const Color notifLesson = Color(0xFF4299E1);
  static const Color notifExam = Color(0xFFEF5350);
  static const Color notifReply = Color(0xFF26A69A);
  static const Color notifAchievement = Color(0xFFFFB74D);
  static const Color notifAnnouncement = Color(0xFF7B2CBF);
  static const Color notifPromo = Color(0xFFE91E63);
  static const Color notifSystem = Color(0xFF607D8B);
  static const Color notifDefault = Color(0xFF9E9E9E);

  static const List<Color> categoryCardColors = [
    Color(0xFFE55A7E),
    Color(0xFF5A8DEE),
    Color(0xFFF18671),
    Color(0xFF14B3C5),
    Color(0xFF8B5CF6),
    Color(0xFF10B981),
    Color(0xFFF59E0B),
    Color(0xFF6366F1),
  ];

  static const Color featureGreen = Color(0xFF4CAF50);
  static const Color featureBlue = Color(0xFF2196F3);
  static const Color featureAmber = Color(0xFFFFC107);
  static const Color featurePurple = Color(0xFF9C27B0);

  static const Color shamCash = Color(0xFFFF6B00);
  static const Color syriatelCash = Color(0xFF00A651);
  static const Color mtnCash = Color(0xFFFFCC00);
  static const Color bankTransferBlue = Color(0xFF2196F3);

  static LinearGradient get backgroundGradient => darkBackgroundGradient;

  static const Color editorAccentLight = Color(0xFF0F6CBD);
  static const Color editorAccentDark = Color(0xFF8AB4F8);
  static const Color editorBorderLight = Color(0xFFD0D0D0);
  static const Color editorTextBody = Color(0xFF1B1B1B);
  static const Color editorTextSub = Color(0xFF5C5C5C);

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryPurple, primaryBlue],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkBackgroundGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF0C0F1B),
      Color(0xFF141A2C),
      Color(0xFF18233A),
    ],
  );

  static const LinearGradient heroBannerGradient = LinearGradient(
    colors: [deepPurple, professionalBlue],
  );

  static const LinearGradient actionButtonGradient = LinearGradient(
    colors: [lightPurple, indigoBlue],
  );

  static const LinearGradient searchGradient = LinearGradient(
    colors: [lightPurple, indigoBlue],
  );



  static const LinearGradient lightBackgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFFF9FAFB), // Very light grey/white
      Color(0xFFF3F4F6), // Slightly darker grey
    ],
  );

  static const AppColorPalette light = AppColorPalette(
    brightness: Brightness.light,
    primary: primaryPurple,
    secondary: primaryBlue,
    background: Color(0xFFF9FAFB),
    scaffoldBackground: Color(0xFFFAFBFF),
    surface: Colors.white,
    surfaceElevated: Colors.white,
    card: Colors.white,
    dialog: Colors.white,
    drawerBackground: Colors.white,
    inputFill: Color(0xFFF3F4F6),
    inputFillAlt: Color(0xFFE5E7EB),
    appBarBackground: Colors.white,
    appBarForeground: Color(0xFF111827),
    textPrimary: Color(0xFF111827),
    textSecondary: Color(0xFF4B5563),
    textMuted: Color(0xFF9CA3AF),
    iconPrimary: Color(0xFF111827),
    iconSecondary: Color(0xFF6B7280),
    border: Color(0xFFE5E7EB),
    borderStrong: Color(0xFFD1D5DB),
    glass: Color(0x90E0E7FF),
    glassStrong: Color(0xF2F1F5F9),
    navBackground: Colors.white,
    shimmerBase: Color(0xFFF3F4F6),
    shimmerHighlight: Color(0xFFE5E7EB),
    backgroundGradient: lightBackgroundGradient,
    overlayStyle: SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ),
  );



  static const AppColorPalette dark = AppColorPalette(
    brightness: Brightness.dark,
    primary: primaryPurple,
    secondary: primaryBlue,
    background: darkBackground,
    scaffoldBackground: darkScaffold,
    surface: Color(0xFF171A2B),
    surfaceElevated: darkSurface2,
    card: darkCardSurface,
    dialog: Color(0xFF171A2B),
    drawerBackground: Color(0xFF131728),
    inputFill: darkInputFill,
    inputFillAlt: darkInputFillAlt,
    appBarBackground: Color(0xFF171A2B),
    appBarForeground: textWhite,
    textPrimary: textWhite,
    textSecondary: Color(0xFFC4CCDA),
    textMuted: Color(0xFF8E98AA),
    iconPrimary: textWhite,
    iconSecondary: Color(0xFFC4CCDA),
    border: Color(0xFF2A3148),
    borderStrong: Color(0xFF39415C),
    glass: Color(0xD91B1F31),
    glassStrong: Color(0xF01D2135),
    navBackground: Color(0xFF171A2B),
    shimmerBase: Color(0xFF1A2030),
    shimmerHighlight: Color(0xFF262E44),
    backgroundGradient: darkBackgroundGradient,
    overlayStyle: SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    ),
  );



  static AppColorPalette of(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? dark : light;
  }

  static Color alpha(Color color, double opacity) {
    final value = opacity.clamp(0.0, 1.0);
    return color.withAlpha((value * 255).round());
  }

  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: alpha(primaryPurple, 0.10),
          blurRadius: 20,
          offset: Offset(0, 10),
        ),
      ];

  static List<BoxShadow> get buttonShadow => [
        BoxShadow(
          color: alpha(primaryPurple, 0.30),
          blurRadius: 15,
          offset: Offset(0, 5),
        ),
      ];

  static List<BoxShadow> get actionButtonShadow => [
        BoxShadow(
          color: alpha(lightPurple, 0.40),
          blurRadius: 20,
          offset: Offset(0, 10),
        ),
      ];

  static Color getCardColor(BuildContext context) => of(context).card;

  static Color getSurfaceColor(BuildContext context) => of(context).surface;

  static Color getElevatedSurfaceColor(BuildContext context) =>
      of(context).surfaceElevated;

  static Color getInputFillColor(BuildContext context,
      {bool stronger = false}) {
    final palette = of(context);
    return stronger ? palette.inputFillAlt : palette.inputFill;
  }

  static Color getGlassColor(BuildContext context, {double opacity = 0.2}) {
    final palette = of(context);
    final base = palette.isDark ? palette.glassStrong : palette.glass;
    return alpha(base, opacity.clamp(0.0, 1.0));
  }

  static Color getBorderColor(BuildContext context, {bool strong = false}) {
    final palette = of(context);
    return strong ? palette.borderStrong : palette.border;
  }

  static Color getTextColor(BuildContext context, {bool secondary = false}) {
    final palette = of(context);
    return secondary ? palette.textSecondary : palette.textPrimary;
  }

  static Color getMutedTextColor(BuildContext context) => of(context).textMuted;

  static LinearGradient getBackgroundGradient(BuildContext context) =>
      of(context).backgroundGradient;

  static Color getDrawerBackground(BuildContext context) =>
      of(context).drawerBackground;

  static Color getEditorAccent(BuildContext context) =>
      of(context).isDark ? editorAccentDark : editorAccentLight;

  static Color getEditorSurface(BuildContext context) =>
      of(context).isDark ? Color(0xFF161922) : light.inputFill;

  static Color getEditorBorder(BuildContext context) =>
      of(context).isDark ? alpha(Colors.white, 0.12) : editorBorderLight;

  static Color get glassBackground => light.glass;
  static Color get glassBorder => alpha(light.borderStrong, 0.55);
}
