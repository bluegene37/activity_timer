import 'package:flutter/material.dart';

class ForUI {
  // Spacing constants
  static const double spacingSmall = 8.0;
  static const double spacing = 16.0;
  static const double spacingLarge = 24.0;
  static const double spacingXLarge = 32.0;

  // Border radius
  static const double borderRadius = 12.0;
  static const double cardRadius = 16.0;

  // Button constants
  static const double buttonHeight = 48.0;
  static const double buttonElevation = 2.0;
  static const EdgeInsets buttonPadding = EdgeInsets.symmetric(
    horizontal: 24,
    vertical: 12,
  );

  // Card constants
  static const double cardElevation = 4.0;

  // Theme methods
  static ThemeData getLightTheme(Color primaryColor) {
    final bool isLightPrimary = primaryColor.computeLuminance() > 0.5;
    final onPrimary = isLightPrimary ? Colors.black : Colors.white;

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: Colors.white,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: Brightness.light,
        surface: Colors.white,
      ).copyWith(
        primary: primaryColor,
        onPrimary: onPrimary,
        secondary: primaryColor,
        surface: Colors.white,
        surfaceContainerLow: Colors.white,
        surfaceContainer: Colors.white,
        outlineVariant: primaryColor.withValues(alpha: 0.1),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
          side: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        elevation: 0,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          padding: buttonPadding,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          backgroundColor: primaryColor,
          foregroundColor: onPrimary,
        ),
      ),
    );
  }

  static ThemeData getDarkTheme(Color primaryColor) {
    final bool isLightPrimary = primaryColor.computeLuminance() > 0.5;
    final onPrimary = isLightPrimary ? Colors.black : Colors.white;
    const scaffoldBlack = Color(0xFF000000); // True Black for OLED

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: scaffoldBlack,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: Brightness.dark,
        surface: scaffoldBlack,
      ).copyWith(
        primary: primaryColor,
        onPrimary: onPrimary,
        secondary: primaryColor,
        surface: scaffoldBlack,
        surfaceContainerLow: const Color(0xFF121212),
        surfaceContainer: const Color(0xFF1E1E1E),
        outlineVariant: primaryColor.withValues(alpha: 0.2),
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF121212),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: scaffoldBlack,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        elevation: 0,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          padding: buttonPadding,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          backgroundColor: primaryColor,
          foregroundColor: onPrimary,
        ),
      ),
    );
  }

  // Helper methods
  static Widget emptyState({
    required String title,
    required String message,
    required String buttonText,
    required VoidCallback onButtonPressed,
    required IconData icon,
  }) {
    return Builder(
      builder: (context) {
        final theme = Theme.of(context);
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(spacing),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 80,
                  color: theme.colorScheme.primary.withValues(alpha: 0.5),
                ),
                const SizedBox(height: spacingLarge),
                Text(
                  title,
                  style: theme.textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: spacingSmall),
                Text(
                  message,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: spacingLarge),
                ElevatedButton.icon(
                  onPressed: onButtonPressed,
                  icon: const Icon(Icons.add),
                  label: Text(buttonText),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static Widget badge({
    required String text,
    required Color backgroundColor,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
