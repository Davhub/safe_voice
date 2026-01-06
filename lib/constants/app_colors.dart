import 'package:flutter/material.dart';

/// App color constants based on the primary color #fe6501
class AppColors {
  // Primary Colors
  static const Color primary = Color(0xFFfe6501);
  static const Color primaryLight = Color(0xFFff8533);
  static const Color primaryDark = Color(0xFFcc5200);
  
  // Secondary Colors
  static const Color secondary = Color(0xFF2196F3);
  static const Color secondaryLight = Color(0xFF64B5F6);
  static const Color secondaryDark = Color(0xFF1976D2);
}

/// Material Theme based on app colors
class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      primarySwatch: MaterialColor(0xFFfe6501, {
        50: const Color(0xFFfff3e0),
        100: const Color(0xFFffe0b3),
        200: const Color(0xFFffcc80),
        300: const Color(0xFFffb74d),
        400: const Color(0xFFffa726),
        500: AppColors.primary,
        600: AppColors.primaryDark,
        700: const Color(0xFFe65100),
        800: const Color(0xFFd84315),
        900: const Color(0xFFbf360c),
      }),
      primaryColor: AppColors.primary,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        primaryContainer: AppColors.primaryLight,
        secondary: AppColors.secondary,
        secondaryContainer: AppColors.secondaryLight,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.primary,
        elevation: 2,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        filled: true,
      ),
    );
  }
}
