import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Export color utilities so files that import `app_colors.dart` get the
// `withValues` extension without having to import `color_utils.dart` directly.
export 'color_utils.dart';

@immutable
class AppColorPalette extends ThemeExtension<AppColorPalette> {
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

  @override
  AppColorPalette copyWith({
    Brightness? brightness,
    Color? primary,
    Color? secondary,
    Color? background,
    Color? scaffoldBackground,
    Color? surface,
    Color? surfaceElevated,
    Color? card,
    Color? dialog,
    Color? drawerBackground,
    Color? inputFill,
    Color? inputFillAlt,
    Color? appBarBackground,
    Color? appBarForeground,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? iconPrimary,
    Color? iconSecondary,
    Color? border,
    Color? borderStrong,
    Color? glass,
    Color? glassStrong,
    Color? navBackground,
    Color? shimmerBase,
    Color? shimmerHighlight,
    LinearGradient? backgroundGradient,
    SystemUiOverlayStyle? overlayStyle,
  }) {
    return AppColorPalette(
      brightness: brightness ?? this.brightness,
      primary: primary ?? this.primary,
      secondary: secondary ?? this.secondary,
      background: background ?? this.background,
      scaffoldBackground: scaffoldBackground ?? this.scaffoldBackground,
      surface: surface ?? this.surface,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      card: card ?? this.card,
      dialog: dialog ?? this.dialog,
      drawerBackground: drawerBackground ?? this.drawerBackground,
      inputFill: inputFill ?? this.inputFill,
      inputFillAlt: inputFillAlt ?? this.inputFillAlt,
      appBarBackground: appBarBackground ?? this.appBarBackground,
      appBarForeground: appBarForeground ?? this.appBarForeground,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      iconPrimary: iconPrimary ?? this.iconPrimary,
      iconSecondary: iconSecondary ?? this.iconSecondary,
      border: border ?? this.border,
      borderStrong: borderStrong ?? this.borderStrong,
      glass: glass ?? this.glass,
      glassStrong: glassStrong ?? this.glassStrong,
      navBackground: navBackground ?? this.navBackground,
      shimmerBase: shimmerBase ?? this.shimmerBase,
      shimmerHighlight: shimmerHighlight ?? this.shimmerHighlight,
      backgroundGradient: backgroundGradient ?? this.backgroundGradient,
      overlayStyle: overlayStyle ?? this.overlayStyle,
    );
  }

  @override
  AppColorPalette lerp(ThemeExtension<AppColorPalette>? other, double t) {
    if (other is! AppColorPalette) return this;
    return AppColorPalette(
      brightness: t < 0.5 ? brightness : other.brightness,
      primary: Color.lerp(primary, other.primary, t)!,
      secondary: Color.lerp(secondary, other.secondary, t)!,
      background: Color.lerp(background, other.background, t)!,
      scaffoldBackground:
          Color.lerp(scaffoldBackground, other.scaffoldBackground, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceElevated: Color.lerp(surfaceElevated, other.surfaceElevated, t)!,
      card: Color.lerp(card, other.card, t)!,
      dialog: Color.lerp(dialog, other.dialog, t)!,
      drawerBackground: Color.lerp(drawerBackground, other.drawerBackground, t)!,
      inputFill: Color.lerp(inputFill, other.inputFill, t)!,
      inputFillAlt: Color.lerp(inputFillAlt, other.inputFillAlt, t)!,
      appBarBackground: Color.lerp(appBarBackground, other.appBarBackground, t)!,
      appBarForeground: Color.lerp(appBarForeground, other.appBarForeground, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      iconPrimary: Color.lerp(iconPrimary, other.iconPrimary, t)!,
      iconSecondary: Color.lerp(iconSecondary, other.iconSecondary, t)!,
      border: Color.lerp(border, other.border, t)!,
      borderStrong: Color.lerp(borderStrong, other.borderStrong, t)!,
      glass: Color.lerp(glass, other.glass, t)!,
      glassStrong: Color.lerp(glassStrong, other.glassStrong, t)!,
      navBackground: Color.lerp(navBackground, other.navBackground, t)!,
      shimmerBase: Color.lerp(shimmerBase, other.shimmerBase, t)!,
      shimmerHighlight:
          Color.lerp(shimmerHighlight, other.shimmerHighlight, t)!,
      backgroundGradient:
          LinearGradient.lerp(backgroundGradient, other.backgroundGradient, t)!,
      overlayStyle: t < 0.5 ? overlayStyle : other.overlayStyle,
    );
  }
}


/// Single source of truth for app colors.
class AppColors {
  AppColors._();

  // Brand (New Premium Palette)
  static const Color brandPrimary = Color(0xFF1978E5);
  static const Color brandSecondary = Color(0xFF5F78A3);
  static const Color brandTertiary = Color(0xFFC55800);
  static const Color brandNeutral = Color(0xFF74777F);

  // Brand (Legacy/Compatibility)
  static const Color primaryPurple = brandPrimary; 
  static const Color primaryBlue = Color(0xFF00E5FF);   // Electric Neon Cyan
  static const Color deepPurple = Color(0xFF2E004F);    // Nocturne Dark Purple
  static const Color professionalBlue = brandPrimary;
  static const Color mutedPurpleBlue = brandSecondary;
  static const Color lightPurple = Color(0xFF9163FF);
  static const Color indigoBlue = Color(0xFF5A67D8);
  static const Color primaryDark = Color(0xFF1A1C2C);

  // Legacy base colors kept as const because many screens still use them in
  // const widgets such as BoxDecoration(...).
  static const Color background = Color(0xFFFBFCFF);
  static const Color darkBackground = Color(0xFF0B0C15); // Nocturne Black
  static const Color darkNavy = Color(0xFF121422);       // Dark Surface
  static const Color darkDeep = Color(0xFF080911);       // Deeper Shadow
  static const Color darkScaffold = Color(0xFF0B0C15);
  static const Color cardBackground = Color(0xFFFFFFFF);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightInputFill = Color(0xFFF8FAFF);
  static const Color darkCardSurface = Color(0xFF171A2E);
  static const Color darkInputFill = Color(0xFF131628);
  static const Color darkInputFillAlt = Color(0xFF1C213A);
  static const Color darkSurface2 = Color(0xFF14172C);
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

  static LinearGradient backgroundGradient(BuildContext context) =>
      of(context).backgroundGradient;

  static const Color editorAccentLight = Color(0xFF0F6CBD);
  static const Color editorAccentDark = Color(0xFF8AB4F8);
  static const Color editorBorderLight = Color(0xFFD0D0D0);
  static const Color editorTextBody = Color(0xFF1B1B1B);
  static const Color editorTextSub = Color(0xFF5C5C5C);

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [brandPrimary, Color(0xFF4DA1FF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkBackgroundGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF0B0C15), // Black
      Color(0xFF121422), // Surface
      Color(0xFF2E004F), // Nocturne Purple
    ],
  );

  static const LinearGradient heroBannerGradient = LinearGradient(
    colors: [deepPurple, professionalBlue],
  );

  static const LinearGradient actionButtonGradient = LinearGradient(
    colors: [brandPrimary, Color(0xFF64B5F6)],
  );

  static const LinearGradient searchGradient = LinearGradient(
    colors: [brandPrimary, Color(0xFF90CAF9)],
  );



  static const LinearGradient lightBackgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFFFBFCFF), // Pure white
      Color(0xFFF2F5FF), // Very soft airy blue
    ],
  );

  static const AppColorPalette light = AppColorPalette(
    brightness: Brightness.light,
    primary: brandPrimary,
    secondary: brandSecondary,
    background: background,
    scaffoldBackground: background,
    surface: lightSurface,
    surfaceElevated: lightSurface,
    card: cardBackground,
    dialog: lightSurface,
    drawerBackground: lightSurface,
    inputFill: Color(0xFFF1F4F9), // Light airy blue-grey
    inputFillAlt: Color(0xFFE8EDF5),
    appBarBackground: lightSurface,
    appBarForeground: Color(0xFF1A1C1E), // Near black
    textPrimary: Color(0xFF1A1C1E),
    textSecondary: Color(0xFF42474E),
    textMuted: brandNeutral,
    iconPrimary: Color(0xFF1A1C1E),
    iconSecondary: Color(0xFF42474E),
    border: Color(0xFFDDE2EA),
    borderStrong: Color(0xFFC1C7CE),
    glass: Color(0xA6FFFFFF), // Frosty White Glass
    glassStrong: Color(0xE6FFFFFF), 
    navBackground: lightSurface,
    shimmerBase: Color(0xFFE1E2E5),
    shimmerHighlight: Color(0xFFF1F0F4),
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
    surface: darkNavy,
    surfaceElevated: darkSurface2,
    card: darkCardSurface,
    dialog: darkNavy,
    drawerBackground: Color(0xFF131728),
    inputFill: darkInputFill,
    inputFillAlt: darkInputFillAlt,
    appBarBackground: darkNavy,
    appBarForeground: textWhite,
    textPrimary: textWhite,
    textSecondary: Color(0xFFB4B9D6),
    textMuted: Color(0xFF757BA3),
    iconPrimary: textWhite,
    iconSecondary: Color(0xFFB4B9D6),
    border: Color(0xFF232842),
    borderStrong: Color(0xFF2E3558),
    glass: Color(0xBF131628), // Nocturne Translucency
    glassStrong: Color(0xD9171A2E),
    navBackground: darkNavy,
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
    return Theme.of(context).extension<AppColorPalette>() ?? (Theme.of(context).brightness == Brightness.dark ? dark : light);
  }

  static Color alpha(Color color, double opacity) {
    return color.withOpacity(opacity.clamp(0.0, 1.0));
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
