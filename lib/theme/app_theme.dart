import 'package:flutter/material.dart';

class AppTheme {
  // Spacing constants
  static const double spacingSmall = 8.0;
  static const double spacing = 16.0;
  static const double spacingLarge = 24.0;
  static const double spacingXLarge = 32.0;

  // Border radius
  static const double borderRadius = 12.0;
  static const double cardRadius = 24.0;

  // Button constants
  static const double buttonHeight = 48.0;
  static const double buttonElevation = 0.0;
  static const EdgeInsets buttonPadding = EdgeInsets.symmetric(
    horizontal: 24,
    vertical: 12,
  );

  // Modern Text Styles
  static TextTheme _getTextTheme(Color onSurface, Color onSurfaceVariant) {
    return TextTheme(
      headlineLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: onSurface, letterSpacing: -0.5),
      headlineMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: onSurface, letterSpacing: -0.5),
      headlineSmall: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: onSurface),
      titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: onSurface),
      titleMedium: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: onSurface),
      titleSmall: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: onSurface),
      bodyLarge: TextStyle(fontSize: 16, color: onSurfaceVariant),
      bodyMedium: TextStyle(fontSize: 14, color: onSurfaceVariant),
      bodySmall: TextStyle(fontSize: 12, color: onSurfaceVariant, fontWeight: FontWeight.w600, letterSpacing: 0.5),
      labelLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0),
    );
  }

  // Theme methods
  static ThemeData getLightTheme(Color primaryColor) {
    // Generate a Material 3 color scheme based on the seed color.
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: Brightness.light,
      surface: Colors.white,
    );
    
    // Fallbacks if dynamic colors don't provide a good secondary
    final secondaryColor = primaryColor == const Color(0xFFF96015) ? const Color(0xFF3333A3) : colorScheme.secondary;

    const scaffoldBg = Color(0xFFF8F9FA);
    const onSurface = Color(0xFF1E2022);
    const onSurfaceVariant = Color(0xFF77838F);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: scaffoldBg,
      colorScheme: colorScheme.copyWith(
        primary: primaryColor,
        secondary: secondaryColor,
        surface: Colors.white,
        onSurface: onSurface,
        onSurfaceVariant: onSurfaceVariant,
        surfaceContainerLow: scaffoldBg,
        surfaceContainer: Colors.white,
        surfaceContainerHighest: const Color(0xFFE9ECEF),
        outlineVariant: Colors.grey.withOpacity(0.1),
      ),
      textTheme: _getTextTheme(onSurface, onSurfaceVariant),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: scaffoldBg, // Match scaffold for seamless look
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        elevation: 0,
        iconTheme: const IconThemeData(color: onSurface),
        titleTextStyle: const TextStyle(
          color: onSurface,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: buttonElevation,
          padding: buttonPadding,
          minimumSize: const Size.fromHeight(buttonHeight),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          backgroundColor: primaryColor,
          foregroundColor: colorScheme.onPrimary,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: secondaryColor,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  // Pure Monochrome Dark Theme 
  static ThemeData getDarkTheme(Color ignoredColor) {
    const primaryColor = Colors.white;
    const onPrimary = Colors.black;
    const scaffoldBg = Color(0xFF121212);
    const surfaceColor = Color(0xFF1E1E1E);
    const onSurface = Color(0xFFF8F9FA);
    const onSurfaceVariant = Color(0xFFAAB4BE);
    const secondaryColor = Color(0xFFB0B0B0); // Light gray for secondary elements

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: scaffoldBg,
      colorScheme: const ColorScheme.dark(
        primary: primaryColor,
        onPrimary: onPrimary,
        secondary: secondaryColor,
        onSecondary: onPrimary,
        surface: surfaceColor,
        onSurface: onSurface,
        onSurfaceVariant: onSurfaceVariant,
      ).copyWith(
        surfaceContainerLow: scaffoldBg,
        surfaceContainer: surfaceColor,
        surfaceContainerHighest: const Color(0xFF2C2C2C),
        outlineVariant: Colors.white.withOpacity(0.1),
      ),
      textTheme: _getTextTheme(onSurface, onSurfaceVariant),
      cardTheme: CardThemeData(
        color: surfaceColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: scaffoldBg,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        elevation: 0,
        iconTheme: IconThemeData(color: onSurface),
        titleTextStyle: TextStyle(
          color: onSurface,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: buttonElevation,
          padding: buttonPadding,
          minimumSize: const Size.fromHeight(buttonHeight),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          backgroundColor: primaryColor,
          foregroundColor: onPrimary,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primaryColor, // Use white in monochrome
        foregroundColor: onPrimary, // Black icon
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}
