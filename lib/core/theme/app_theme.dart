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
    final baseTheme = palette.isDark
        ? ThemeData.dark(useMaterial3: true)
        : ThemeData.light(useMaterial3: true);
    final textTheme = GoogleFonts.cairoTextTheme(baseTheme.textTheme).copyWith(
      displayLarge: GoogleFonts.cairo(
          fontSize: 32,
          fontWeight: FontWeight.normal,
          color: palette.textPrimary),
      displayMedium: GoogleFonts.cairo(
          fontSize: 28,
          fontWeight: FontWeight.normal,
          color: palette.textPrimary),
      displaySmall: GoogleFonts.cairo(
          fontSize: 24,
          fontWeight: FontWeight.normal,
          color: palette.textPrimary),
      headlineMedium: GoogleFonts.cairo(
          fontSize: 20,
          fontWeight: FontWeight.normal,
          color: palette.textPrimary),
      headlineSmall: GoogleFonts.cairo(
          fontSize: 18,
          fontWeight: FontWeight.normal,
          color: palette.textPrimary),
      titleLarge: GoogleFonts.cairo(
          fontSize: 16,
          fontWeight: FontWeight.normal,
          color: palette.textPrimary),
      titleMedium: GoogleFonts.cairo(
          fontSize: 16,
          fontWeight: FontWeight.normal,
          color: palette.textPrimary),
      titleSmall: GoogleFonts.cairo(
          fontSize: 14,
          fontWeight: FontWeight.normal,
          color: palette.textPrimary),
      bodyLarge: GoogleFonts.cairo(
          fontSize: 16,
          fontWeight: FontWeight.normal,
          color: palette.textPrimary),
      bodyMedium: GoogleFonts.cairo(
          fontSize: 14,
          fontWeight: FontWeight.normal,
          color: palette.textSecondary),
      bodySmall: GoogleFonts.cairo(
          fontSize: 12,
          fontWeight: FontWeight.normal,
          color: palette.textMuted),
      labelLarge: GoogleFonts.cairo(
          fontSize: 14,
          fontWeight: FontWeight.normal,
          color: palette.textPrimary),
    );

    final scaffoldBackground =
        admin ? palette.scaffoldBackground : Colors.transparent;
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
      dividerColor: palette.border,
      shadowColor: palette.isDark
          ? AppColors.alpha(Colors.black, 0.32)
          : AppColors.alpha(AppColors.primaryPurple, 0.12),
      splashColor: AppColors.alpha(palette.primary, 0.10),
      highlightColor: AppColors.alpha(palette.primary, 0.06),
      fontFamily: 'Cairo',
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        elevation: 0,
        backgroundColor: appBarBackground,
        foregroundColor: palette.appBarForeground,
        centerTitle: true,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: GoogleFonts.cairo(
          fontSize: 20,
          fontWeight: FontWeight.normal,
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
            ? AppColors.alpha(Colors.black, 0.24)
            : AppColors.alpha(AppColors.primaryPurple, 0.10),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppColors.alpha(palette.border, 0.65)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: palette.dialog,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: GoogleFonts.cairo(
          fontSize: 18,
          fontWeight: FontWeight.normal,
          color: palette.textPrimary,
        ),
        contentTextStyle: GoogleFonts.cairo(
          fontSize: 14,
          color: palette.textSecondary,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.inputFill,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        hintStyle: GoogleFonts.cairo(color: palette.textMuted, fontSize: 14),
        labelStyle:
            GoogleFonts.cairo(color: palette.textSecondary, fontSize: 14),
        prefixIconColor: palette.iconSecondary,
        suffixIconColor: palette.iconSecondary,
        border: _inputBorder(palette.border),
        enabledBorder: _inputBorder(palette.border),
        focusedBorder: _inputBorder(palette.primary, width: 1.6),
        errorBorder: _inputBorder(AppColors.error),
        focusedErrorBorder: _inputBorder(AppColors.error, width: 1.6),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: palette.primary,
          foregroundColor: Colors.white,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle:
              GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.normal),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: palette.textPrimary,
          side: BorderSide(color: palette.borderStrong),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle:
              GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.normal),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: palette.primary,
          textStyle:
              GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.normal),
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
        labelStyle: GoogleFonts.cairo(color: palette.textPrimary, fontSize: 12),
        secondaryLabelStyle:
            GoogleFonts.cairo(color: Colors.white, fontSize: 12),
        brightness: palette.brightness,
        side: BorderSide(color: palette.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: palette.navBackground,
        selectedItemColor: palette.primary,
        unselectedItemColor: palette.textMuted,
        selectedLabelStyle:
            GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.normal),
        unselectedLabelStyle: GoogleFonts.cairo(fontSize: 12),
        type: BottomNavigationBarType.fixed,
        elevation: admin ? 8 : 0,
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        textStyle: GoogleFonts.cairo(color: palette.textPrimary, fontSize: 14),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: palette.inputFill,
          border: _inputBorder(palette.border),
          enabledBorder: _inputBorder(palette.border),
          focusedBorder: _inputBorder(palette.primary, width: 1.6),
        ),
      ),
    );
  }

  static OutlineInputBorder _inputBorder(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: color, width: width),
    );
  }
}
