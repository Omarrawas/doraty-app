import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTheme {
  // Admin Theme - White background with dark text
  static ThemeData get adminLightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: Colors.transparent,
      colorScheme: ColorScheme.light(
        primary: AppColors.primaryPurple,
        secondary: AppColors.primaryBlue,
        surface: const Color(0xFFFAFBFF),
        onSurface: AppColors.textPrimary,
        onPrimary: Colors.white,
        surfaceTint: Colors.transparent,
      ),

      fontFamily: 'Cairo',
      // Arabic Font Support
      textTheme:
          GoogleFonts.cairoTextTheme(ThemeData.light().textTheme).copyWith(
        displayLarge: GoogleFonts.cairo(
          fontSize: 32,
          fontWeight: FontWeight.normal,
          color: AppColors.textPrimary,
        ),
        displayMedium: GoogleFonts.cairo(
          fontSize: 28,
          fontWeight: FontWeight.normal,
          color: AppColors.textPrimary,
        ),
        displaySmall: GoogleFonts.cairo(
          fontSize: 24,
          fontWeight: FontWeight.normal,
          color: AppColors.textPrimary,
        ),
        headlineMedium: GoogleFonts.cairo(
          fontSize: 20,
          fontWeight: FontWeight.normal,
          color: AppColors.textPrimary,
        ),
        headlineSmall: GoogleFonts.cairo(
          fontSize: 18,
          fontWeight: FontWeight.normal,
          color: AppColors.textPrimary,
        ),
        titleLarge: GoogleFonts.cairo(
          fontSize: 16,
          fontWeight: FontWeight.normal,
          color: AppColors.textPrimary,
        ),
        bodyLarge: GoogleFonts.cairo(
          fontSize: 16,
          fontWeight: FontWeight.normal,
          color: AppColors.textPrimary,
        ),
        bodyMedium: GoogleFonts.cairo(
          fontSize: 14,
          fontWeight: FontWeight.normal,
          color: AppColors.textSecondary,
        ),
        bodySmall: GoogleFonts.cairo(
          fontSize: 12,
          fontWeight: FontWeight.normal,
          color: AppColors.textLight,
        ),
        titleMedium: GoogleFonts.cairo(
          fontSize: 16,
          fontWeight: FontWeight.normal,
          color: AppColors.textPrimary,
        ),
        titleSmall: GoogleFonts.cairo(
          fontSize: 14,
          fontWeight: FontWeight.normal,
          color: AppColors.textPrimary,
        ),
        labelLarge: GoogleFonts.cairo(
          fontSize: 14,
          fontWeight: FontWeight.normal,
          color: AppColors.textPrimary,
        ),
      ),

      // AppBar Theme
      appBarTheme: AppBarTheme(
        elevation: 2,
        backgroundColor: AppColors.cardBackground,
        foregroundColor: AppColors.textPrimary,
        centerTitle: true,
        titleTextStyle: GoogleFonts.cairo(
          fontSize: 20,
          fontWeight: FontWeight.normal,
          color: AppColors.textPrimary,
        ),
      ),

      // Card Theme
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        color: AppColors.cardBackground,
        shadowColor: AppColors.primaryPurple.withOpacity(0.1),
      ),

      // Input Decoration Theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFFAFAFA),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.textLight.withOpacity(0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.textLight.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: AppColors.primaryPurple, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        hintStyle: GoogleFonts.cairo(
          color: AppColors.textLight,
          fontSize: 14,
        ),
      ),

      // Elevated Button Theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 2,
          backgroundColor: AppColors.primaryPurple,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.cairo(
            fontSize: 16,
            fontWeight: FontWeight.normal,
          ),
        ),
      ),

      // Bottom Navigation Bar Theme
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: AppColors.primaryPurple,
        unselectedItemColor: AppColors.textLight,
        selectedLabelStyle: GoogleFonts.cairo(
          fontSize: 12,
          fontWeight: FontWeight.normal,
        ),
        unselectedLabelStyle: GoogleFonts.cairo(
          fontSize: 12,
        ),
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
    );
  }

  // Admin Theme - Dark background
  static ThemeData get adminDarkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.darkScaffold,

      fontFamily: 'Cairo',
      textTheme:
          GoogleFonts.cairoTextTheme(ThemeData.dark().textTheme).copyWith(
        displayLarge: GoogleFonts.cairo(
          fontSize: 32,
          fontWeight: FontWeight.normal,
          color: Colors.white,
        ),
        displayMedium: GoogleFonts.cairo(
          fontSize: 28,
          fontWeight: FontWeight.normal,
          color: Colors.white,
        ),
        displaySmall: GoogleFonts.cairo(
          fontSize: 24,
          fontWeight: FontWeight.normal,
          color: Colors.white,
        ),
        headlineMedium: GoogleFonts.cairo(
          fontSize: 20,
          fontWeight: FontWeight.normal,
          color: Colors.white,
        ),
        headlineSmall: GoogleFonts.cairo(
          fontSize: 18,
          fontWeight: FontWeight.normal,
          color: Colors.white,
        ),
        titleLarge: GoogleFonts.cairo(
          fontSize: 16,
          fontWeight: FontWeight.normal,
          color: Colors.white,
        ),
        bodyLarge: GoogleFonts.cairo(
          fontSize: 16,
          color: Colors.white,
        ),
        bodyMedium: GoogleFonts.cairo(
          fontSize: 14,
          color: Colors.white,
        ),
        bodySmall: GoogleFonts.cairo(
          fontSize: 12,
          color: Colors.white,
        ),
      ),

      // AppBar Theme
      appBarTheme: AppBarTheme(
        elevation: 2,
        backgroundColor: AppColors.darkCardSurface,
        foregroundColor: Colors.white,
        centerTitle: true,
        titleTextStyle: GoogleFonts.cairo(
          fontSize: 20,
          fontWeight: FontWeight.normal,
          color: Colors.white,
        ),
      ),

      // Card Theme
      cardTheme: CardThemeData(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        color: AppColors.darkCardSurface,
        shadowColor: Colors.black.withOpacity(0.3),
      ),

      // Input Decoration Theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.darkInputFill,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: AppColors.primaryPurple, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        hintStyle: GoogleFonts.cairo(
          color: Colors.white,
          fontSize: 14,
        ),
      ),

      // Elevated Button Theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 2,
          backgroundColor: AppColors.primaryPurple,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.cairo(
            fontSize: 16,
            fontWeight: FontWeight.normal,
          ),
        ),
      ),

      // Bottom Navigation Bar Theme
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppColors.darkCardSurface,
        selectedItemColor: AppColors.primaryPurple,
        unselectedItemColor: Colors.white,
        selectedLabelStyle: GoogleFonts.cairo(
          fontSize: 12,
          fontWeight: FontWeight.normal,
        ),
        unselectedLabelStyle: GoogleFonts.cairo(
          fontSize: 12,
        ),
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
    );
  }

  static ThemeData get lightTheme {
    const Color lightSurface = Color(0xFFF9FAFF); // Almost white but with blue/purple hint

    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.light(
        primary: AppColors.primaryPurple,
        secondary: AppColors.primaryBlue,
        surface: lightSurface,
        onSurface: AppColors.textPrimary,
        onPrimary: Colors.white,
        error: AppColors.error,
        onError: Colors.white,
        surfaceTint: Colors.transparent,
      ),
      scaffoldBackgroundColor: AppColors.background,
      dialogBackgroundColor: lightSurface,

      fontFamily: 'Cairo',
      // Arabic Font Support
      textTheme:
          GoogleFonts.cairoTextTheme(ThemeData.light().textTheme).copyWith(
        displayLarge: GoogleFonts.cairo(
          fontSize: 32,
          fontWeight: FontWeight.normal,
          color: AppColors.textPrimary,
        ),
        displayMedium: GoogleFonts.cairo(
          fontSize: 28,
          fontWeight: FontWeight.normal,
          color: AppColors.textPrimary,
        ),
        displaySmall: GoogleFonts.cairo(
          fontSize: 24,
          fontWeight: FontWeight.normal,
          color: AppColors.textPrimary,
        ),
        headlineMedium: GoogleFonts.cairo(
          fontSize: 20,
          fontWeight: FontWeight.normal,
          color: AppColors.textPrimary,
        ),
        headlineSmall: GoogleFonts.cairo(
          fontSize: 18,
          fontWeight: FontWeight.normal,
          color: AppColors.textPrimary,
        ),
        titleLarge: GoogleFonts.cairo(
          fontSize: 16,
          fontWeight: FontWeight.normal,
          color: AppColors.textPrimary,
        ),
        bodyLarge: GoogleFonts.cairo(
          fontSize: 16,
          fontWeight: FontWeight.normal,
          color: AppColors.textPrimary,
        ),
        bodyMedium: GoogleFonts.cairo(
          fontSize: 14,
          fontWeight: FontWeight.normal,
          color: AppColors.textSecondary,
        ),
        bodySmall: GoogleFonts.cairo(
          fontSize: 12,
          fontWeight: FontWeight.normal,
          color: AppColors.textLight,
        ),
        titleMedium: GoogleFonts.cairo(
          fontSize: 16,
          fontWeight: FontWeight.normal,
          color: AppColors.textPrimary,
        ),
        titleSmall: GoogleFonts.cairo(
          fontSize: 14,
          fontWeight: FontWeight.normal,
          color: AppColors.textPrimary,
        ),
        labelLarge: GoogleFonts.cairo(
          fontSize: 14,
          fontWeight: FontWeight.normal,
          color: AppColors.textPrimary,
        ),
      ),

      // AppBar Theme
      appBarTheme: AppBarTheme(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        centerTitle: true,
        titleTextStyle: GoogleFonts.cairo(
          fontSize: 20,
          fontWeight: FontWeight.normal,
          color: AppColors.textPrimary,
        ),
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
        ),
      ),

      // Card Theme
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        color: Colors.white.withOpacity(0.9),
        shadowColor: AppColors.primaryPurple.withOpacity(0.1),
      ),

      // Dialog Theme
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.cardBackground,
        surfaceTintColor: AppColors.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: GoogleFonts.cairo(
          fontSize: 18,
          fontWeight: FontWeight.normal,
          color: AppColors.textPrimary,
        ),
        contentTextStyle: GoogleFonts.cairo(
          fontSize: 14,
          color: AppColors.textSecondary,
        ),
      ),

      // Input Decoration Theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withOpacity(0.9),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.textLight.withOpacity(0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.textLight.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: AppColors.primaryPurple, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        hintStyle: GoogleFonts.cairo(
          color: AppColors.textLight,
          fontSize: 14,
        ),
      ),

      // Elevated Button Theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: AppColors.primaryPurple,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.cairo(
            fontSize: 16,
            fontWeight: FontWeight.normal,
          ),
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    const Color darkSurface = AppColors.darkBackground;

    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.dark(
        primary: AppColors.primaryPurple,
        secondary: AppColors.primaryBlue,
        surface: darkSurface,
        onSurface: Colors.white,
        onPrimary: Colors.white,
        error: AppColors.error,
        onError: Colors.white,
        surfaceContainerHighest: darkSurface,
        surfaceContainer: darkSurface,
        surfaceTint: Colors.transparent,
      ),
      scaffoldBackgroundColor: Colors.transparent,
      dialogBackgroundColor: darkSurface,

      fontFamily: 'Cairo',
      // Arabic Font Support
      textTheme:
          GoogleFonts.cairoTextTheme(ThemeData.dark().textTheme).copyWith(
        displayLarge: GoogleFonts.cairo(
          fontSize: 32,
          fontWeight: FontWeight.normal,
          color: Colors.white,
        ),
        displayMedium: GoogleFonts.cairo(
          fontSize: 28,
          fontWeight: FontWeight.normal,
          color: Colors.white,
        ),
        displaySmall: GoogleFonts.cairo(
          fontSize: 24,
          fontWeight: FontWeight.normal,
          color: Colors.white,
        ),
        headlineMedium: GoogleFonts.cairo(
          fontSize: 20,
          fontWeight: FontWeight.normal,
          color: Colors.white,
        ),
        headlineSmall: GoogleFonts.cairo(
          fontSize: 18,
          fontWeight: FontWeight.normal,
          color: Colors.white,
        ),
        titleLarge: GoogleFonts.cairo(
          fontSize: 16,
          fontWeight: FontWeight.normal,
          color: Colors.white,
        ),
        bodyLarge: GoogleFonts.cairo(
          fontSize: 16,
          color: Colors.white,
        ),
        bodyMedium: GoogleFonts.cairo(
          fontSize: 14,
          color: Colors.white,
        ),
        bodySmall: GoogleFonts.cairo(
          fontSize: 12,
          color: Colors.white,
        ),
      ),

      // AppBar Theme
      appBarTheme: AppBarTheme(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        centerTitle: true,
        titleTextStyle: GoogleFonts.cairo(
          fontSize: 20,
          fontWeight: FontWeight.normal,
          color: Colors.white,
        ),
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
        ),
      ),

      // Card Theme
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        color: AppColors.darkCardSurface.withOpacity(0.8),
        shadowColor: Colors.black.withOpacity(0.2),
      ),

      // Dialog Theme
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.darkBackground,
        surfaceTintColor: AppColors.darkBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: GoogleFonts.cairo(
          fontSize: 18,
          fontWeight: FontWeight.normal,
          color: Colors.white,
        ),
        contentTextStyle: GoogleFonts.cairo(
          fontSize: 14,
          color: Colors.white,
        ),
      ),

      // Input Decoration Theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.darkInputFillAlt.withOpacity(0.8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: AppColors.primaryPurple, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        hintStyle: GoogleFonts.cairo(
          color: Colors.white,
          fontSize: 14,
        ),
      ),

      // Elevated Button Theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: AppColors.primaryPurple,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.cairo(
            fontSize: 16,
            fontWeight: FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
