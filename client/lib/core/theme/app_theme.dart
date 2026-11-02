import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';
import 'app_text_styles.dart';

class AppTheme {
  const AppTheme._();

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: const ColorScheme.light(
          primary: AppColors.primary,
          onPrimary: Colors.white,
          secondary: AppColors.tertiary,
          onSecondary: Colors.white,
          surface: AppColors.surface,
          onSurface: AppColors.text,
          error: AppColors.danger,
          onError: Colors.white,
        ),
        scaffoldBackgroundColor: AppColors.background,
        fontFamily: GoogleFonts.ibmPlexSans().fontFamily,
        textTheme: AppTextStyles.textTheme,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.text,
          elevation: 0,
          centerTitle: false,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.secondary,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          border: const OutlineInputBorder(
            borderSide: BorderSide(color: AppColors.outlined),
          ),
          enabledBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: AppColors.outlined),
          ),
          focusedBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: AppColors.primary, width: 2),
          ),
          errorBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: AppColors.danger),
          ),
          hintStyle: AppTextStyles.textTheme.bodyMedium?.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            minimumSize: const Size(0, 48),
            shape: const RoundedRectangleBorder(),
            textStyle: AppTextStyles.textTheme.labelLarge,
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.text,
            minimumSize: const Size(0, 48),
            side: const BorderSide(color: AppColors.outlined),
            shape: const RoundedRectangleBorder(),
            textStyle: AppTextStyles.textTheme.labelLarge,
          ),
        ),
        navigationBarTheme: const NavigationBarThemeData(
          backgroundColor: AppColors.secondary,
          indicatorColor: AppColors.primary,
        ),
        dividerTheme: const DividerThemeData(
          color: AppColors.disabled,
          thickness: 1,
        ),
      );
}
