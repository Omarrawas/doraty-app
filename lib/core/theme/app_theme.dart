import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTheme {
  static ThemeData get adminLightTheme =>
      _buildTheme(AppColors.light, admin: true);

  static ThemeData get adminDarkTheme =>
      _buildTheme(AppColors.dark, admin: true);

  static ThemeData get lightTheme => _buildTheme(AppColors.light);

  static ThemeData get darkTheme => _buildTheme(AppColors.dark);

  static ThemeData _buildTheme(AppColorPalette palette, {bool admin = false}) {
    final isDark = palette.isDark;
    final baseTheme = isDark
        ? ThemeData.dark(useMaterial3: true)
        : ThemeData.light(useMaterial3: true);
    
    final displayFont = GoogleFonts.plusJakartaSans;
    final bodyFont = GoogleFonts.inter;
    final labelFont = GoogleFonts.plusJakartaSans;

    final textTheme = (isDark 
        ? GoogleFonts.interTextTheme(baseTheme.textTheme)
        : GoogleFonts.interTextTheme(baseTheme.textTheme)).copyWith(
      displayLarge: displayFont(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.64, // roughly -0.02em
          color: palette.textPrimary),
      displayMedium: displayFont(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.56,
          color: palette.textPrimary),
      displaySmall: displayFont(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.48,
          color: palette.textPrimary),
      headlineMedium: displayFont(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.40,
          color: palette.textPrimary),
      headlineSmall: displayFont(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.36,
          color: palette.textPrimary),
      titleLarge: bodyFont(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: palette.textPrimary),
      titleMedium: bodyFont(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: palette.textPrimary),
      titleSmall: bodyFont(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: palette.textPrimary),
      bodyLarge: bodyFont(
          fontSize: 16,
          fontWeight: FontWeight.normal,
          color: palette.textPrimary),
      bodyMedium: bodyFont(
          fontSize: 14,
          fontWeight: FontWeight.normal,
          color: palette.textSecondary),
      bodySmall: bodyFont(
          fontSize: 12,
          fontWeight: FontWeight.normal,
          color: palette.textMuted),
      labelLarge: labelFont(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: palette.textPrimary),
      labelMedium: labelFont(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: palette.textSecondary),
      labelSmall: labelFont(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: palette.textMuted),
    );

    final scaffoldBackground =
        admin ? palette.scaffoldBackground : palette.scaffoldBackground;
    final appBarBackground =
        admin ? palette.appBarBackground : Colors.transparent;

    return ThemeData(
      useMaterial3: true,
      brightness: palette.brightness,
      colorScheme: ColorScheme(
        brightness: palette.brightness,
        primary: palette.primary,
        onPrimary: Colors.white,
        secondary: palette.secondary,
        onSecondary: Colors.white,
        error: AppColors.error,
        onError: Colors.white,
        surface: palette.surface,
        onSurface: palette.textPrimary,
      ),
      scaffoldBackgroundColor: scaffoldBackground,
      dialogBackgroundColor: palette.dialog,
      canvasColor: palette.surface,
      dividerColor: Colors.transparent, // Disable hard line borders
      shadowColor: palette.isDark
          ? const Color(0x14000000)
          // Ambient shadow: primary at 8% (0.08 alpha) -> 0x14 roughly
          : const Color.fromRGBO(44, 47, 103, 0.08), 
      splashColor: AppColors.alpha(palette.primary, 0.10),
      highlightColor: AppColors.alpha(palette.primary, 0.06),
      fontFamily: 'Inter',
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        elevation: 0,
        backgroundColor: appBarBackground,
        foregroundColor: palette.appBarForeground,
        centerTitle: true,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: displayFont(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: palette.appBarForeground,
        ),
        iconTheme: IconThemeData(color: palette.iconPrimary),
        actionsIconTheme: IconThemeData(color: palette.iconPrimary),
        systemOverlayStyle: palette.overlayStyle,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: palette.card,
        shadowColor: palette.isDark
            ? const Color(0x14000000)
            : const Color.fromRGBO(44, 47, 103, 0.08),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide.none, // Forbidden solid borders
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: palette.dialog,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        titleTextStyle: displayFont(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: palette.textPrimary,
        ),
        contentTextStyle: bodyFont(
          fontSize: 14,
          color: palette.textSecondary,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.inputFill,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        hintStyle: bodyFont(color: palette.textMuted, fontSize: 14),
        labelStyle:
            bodyFont(color: palette.textSecondary, fontSize: 14),
        prefixIconColor: palette.iconSecondary,
        suffixIconColor: palette.iconSecondary,
        border: _inputBorder(Colors.transparent, radius: 9999), 
        enabledBorder: _inputBorder(Colors.transparent, radius: 9999),
        // "Ghost Border" of primary at 40% opacity during active
        focusedBorder: _inputBorder(palette.borderStrong, width: 2, radius: 9999),
        errorBorder: _inputBorder(AppColors.error, radius: 9999),
        focusedErrorBorder: _inputBorder(AppColors.error, width: 2, radius: 9999),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: palette.primary,
          foregroundColor: Colors.white,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          textStyle:
              bodyFont(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: palette.textPrimary,
          side: BorderSide(color: palette.borderStrong),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          textStyle:
              bodyFont(fontSize: 14, fontWeight: FontWeight.normal),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: palette.primary,
          textStyle:
              bodyFont(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      iconTheme: IconThemeData(color: palette.iconPrimary),
      listTileTheme: ListTileThemeData(
        iconColor: palette.iconPrimary,
        textColor: palette.textPrimary,
        tileColor: Colors.transparent,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: palette.inputFillAlt,
        selectedColor: palette.primary,
        disabledColor: palette.inputFill,
        secondarySelectedColor: palette.primary,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        labelStyle: bodyFont(color: palette.textPrimary, fontSize: 12),
        secondaryLabelStyle:
            bodyFont(color: palette.textPrimary, fontSize: 12),
        brightness: palette.brightness,
        side: BorderSide(color: palette.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: palette.navBackground,
        selectedItemColor: palette.primary,
        unselectedItemColor: palette.textMuted,
        selectedLabelStyle:
            bodyFont(fontSize: 12, fontWeight: FontWeight.w600),
        unselectedLabelStyle: bodyFont(fontSize: 12),
        type: BottomNavigationBarType.fixed,
        elevation: admin ? 8 : 0,
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        textStyle: bodyFont(color: palette.textPrimary, fontSize: 14),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: palette.inputFill,
          border: _inputBorder(Colors.transparent, radius: 9999),
          enabledBorder: _inputBorder(Colors.transparent, radius: 9999),
          focusedBorder: _inputBorder(palette.borderStrong, width: 2, radius: 9999),
        ),
      ),
      extensions: [palette],
    );
  }

  static OutlineInputBorder _inputBorder(Color color,
      {double width = 1, double radius = 16}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(radius),
      borderSide: BorderSide(color: color, width: width),
    );
  }
}
