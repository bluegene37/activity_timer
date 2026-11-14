import 'package:flutter/material.dart';

class AppTheme {
  // Spacing constants (Apple 8pt grid)
  static const double spacingSmall = 8.0;
  static const double spacing = 16.0;
  static const double spacingLarge = 24.0;
  static const double spacingXLarge = 32.0;

  // iOS Border radiuses
  static const double borderRadius = 12.0;
  static const double cardRadius = 16.0;
  static const double pillRadius = 24.0;

  // Button constants
  static const double buttonHeight = 50.0;
  static const double buttonElevation = 0.0;
  static const EdgeInsets buttonPadding = EdgeInsets.symmetric(
    horizontal: 20,
    vertical: 14,
  );

  // Apple System & Fitness Color Palette
  static const Color iosOrange = Color(0xFFFF9500);
  static const Color iosBlue = Color(0xFF007AFF);
  static const Color iosGreen = Color(0xFF34C759);
  static const Color iosMint = Color(0xFF00C7BE);
  static const Color iosTeal = Color(0xFF30B0C7);
  static const Color iosCyan = Color(0xFF32ADE6);
  static const Color iosIndigo = Color(0xFF5856D6);
  static const Color iosPurple = Color(0xFFAF52DE);
  static const Color iosPink = Color(0xFFFF2D55);
  static const Color iosRed = Color(0xFFFF3B30);
  static const Color iosYellow = Color(0xFFFFCC00);

  // iOS grouped-list surfaces. Both sides of each pair are Apple's system
  // values, so they are resolved from brightness rather than the ColorScheme.
  static const Color _cardDark = Color(0xFF1C1C1E);
  static const Color _cardLight = Colors.white;
  static const Color _separatorDark = Color(0xFF38383A);
  static const Color _separatorLight = Color(0xFFE5E5EA);

  /// Background of a grouped-list card.
  static Color cardBackground({required bool isDark}) =>
      isDark ? _cardDark : _cardLight;

  /// Hairline rule between grouped-list rows.
  static Color separator({required bool isDark}) =>
      isDark ? _separatorDark : _separatorLight;

  // Gene - Nov, 14, 2026: Contrast-safe foreground ink helper (dark ink on bright accents like Yellow/Orange/Green/Cyan, white on darker accents) and darkened accent text helper on light surfaces.
  // Gene - Nov, 14, 2026: Select WCAG AA (>=4.5:1) foreground ink across all accent luminances (soft dark ink on bright fills, white on dark fills, pure black on mid-luminance accents like iosBlue/iosPink/iosRed/iosPurple).
  // static Color onColor(Color background) =>
  //     ThemeData.estimateBrightnessForColor(background) == Brightness.light
  //         ? const Color(0xFF1C1C1E)
  //         : Colors.white;
  static Color onColor(Color background) {
    const darkInk = Color(0xFF1C1C1E);
    final bgLum = background.computeLuminance();
    final darkInkLum = darkInk.computeLuminance();
    final darkInkContrast = (bgLum + 0.05) / (darkInkLum + 0.05);
    if (darkInkContrast >= 4.5) {
      return darkInk;
    }
    final whiteContrast = 1.05 / (bgLum + 0.05);
    if (whiteContrast >= 4.5) {
      return Colors.white;
    }
    final blackContrast = (bgLum + 0.05) / 0.05;
    return blackContrast >= whiteContrast ? Colors.black : Colors.white;
  }

  static Color readableAccent(Color accent, {required bool isDark}) {
    if (!isDark && accent.computeLuminance() > 0.22) {
      final hsl = HSLColor.fromColor(accent);
      return hsl.withLightness(0.25).toColor();
    }
    return accent;
  }

  // Modern iOS Typography (SF Pro style with tightened tracking)
  static TextTheme _getTextTheme(Color onSurface, Color onSurfaceVariant) {
    return TextTheme(
      headlineLarge: TextStyle(
        fontSize: 34,
        fontWeight: FontWeight.w800,
        color: onSurface,
        letterSpacing: -0.8,
      ),
      headlineMedium: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: onSurface,
        letterSpacing: -0.6,
      ),
      headlineSmall: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: onSurface,
        letterSpacing: -0.4,
      ),
      titleLarge: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: onSurface,
        letterSpacing: -0.3,
      ),
      titleMedium: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: onSurface,
        letterSpacing: -0.2,
      ),
      titleSmall: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: onSurface,
        letterSpacing: -0.1,
      ),
      bodyLarge: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w400,
        color: onSurfaceVariant,
        letterSpacing: -0.2,
      ),
      bodyMedium: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: onSurfaceVariant,
        letterSpacing: -0.1,
      ),
      bodySmall: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: onSurfaceVariant,
        letterSpacing: 0.1,
      ),
      labelLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.1,
      ),
    );
  }

  // Light Theme (iOS Grouped System Style)
  static ThemeData getLightTheme(Color primaryColor) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: Brightness.light,
      surface: Colors.white,
    );

    final secondaryColor =
        primaryColor == const Color(0xFFF96015)
            ? const Color(0xFF5856D6)
            : colorScheme.secondary;

    const scaffoldBg = Color(0xFFF2F2F7); // iOS System Grouped Background
    const surfaceColor = Colors.white; // iOS Grouped Card Background
    const onSurface = Color(0xFF000000);
    // Gene - Nov, 14, 2026: Darkened light-mode onSurfaceVariant to AA-compliant gray (#636366, >5.3:1 on #F2F2F7/#FFFFFF) and derived contrast-safe button/FAB foregrounds via AppTheme.onColor.
    // const onSurfaceVariant = Color(0xFF8E8E93); // iOS System Gray
    const onSurfaceVariant = Color(0xFF636366);
    final onPrimaryColor = onColor(primaryColor);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: scaffoldBg,
      colorScheme: colorScheme.copyWith(
        primary: primaryColor,
        onPrimary: onPrimaryColor,
        secondary: secondaryColor,
        surface: surfaceColor,
        onSurface: onSurface,
        onSurfaceVariant: onSurfaceVariant,
        surfaceContainerLow: scaffoldBg,
        surfaceContainer: surfaceColor,
        surfaceContainerHighest: const Color(0xFFE5E5EA), // iOS System Gray 5
        outlineVariant: const Color(0xFFE5E5EA), // iOS Separator Hairline
      ),
      textTheme: _getTextTheme(onSurface, onSurfaceVariant),
      cardTheme: CardThemeData(
        color: surfaceColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
          side: const BorderSide(color: Color(0xFFE5E5EA), width: 0.8),
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
          fontSize: 17,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
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
          // foregroundColor: Colors.white,
          foregroundColor: onPrimaryColor,
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          side: BorderSide(
            color: primaryColor.withValues(alpha: 0.5),
            width: 1.2,
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
        // foregroundColor: Colors.white,
        foregroundColor: onPrimaryColor,
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(pillRadius),
        ),
      ),
    );
  }

  // Dark Theme (Apple Fitness & OLED Pure Black Look)
  static ThemeData getDarkTheme(Color primaryColor) {
    const scaffoldBg = Color(0xFF000000); // Apple Fitness OLED Pure Black
    const surfaceColor = Color(0xFF1C1C1E); // Apple Dark Secondary Grouped
    const onSurface = Color(0xFFFFFFFF);
    const onSurfaceVariant = Color(0xFF98989D); // Apple Dark System Gray
    // Gene - Nov, 14, 2026: Derive contrast-safe dark-theme button and FAB foreground from accent luminance.
    final onPrimaryColor = onColor(primaryColor);

    final darkColorScheme = ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: Brightness.dark,
      surface: surfaceColor,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: scaffoldBg,
      colorScheme: darkColorScheme.copyWith(
        primary: primaryColor,
        // onPrimary: Colors.white,
        onPrimary: onPrimaryColor,
        secondary: darkColorScheme.secondary,
        surface: surfaceColor,
        onSurface: onSurface,
        onSurfaceVariant: onSurfaceVariant,
        surfaceContainerLow: scaffoldBg,
        surfaceContainer: surfaceColor,
        surfaceContainerHighest: const Color(0xFF2C2C2E), // Apple Dark Gray 4
        outlineVariant: const Color(0xFF38383A), // Dark Hairline Separator
      ),
      textTheme: _getTextTheme(onSurface, onSurfaceVariant),
      cardTheme: CardThemeData(
        color: surfaceColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
          side: const BorderSide(color: Color(0xFF38383A), width: 0.8),
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
          fontSize: 17,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
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
          // foregroundColor: Colors.white,
          foregroundColor: onPrimaryColor,
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          side: BorderSide(
            color: primaryColor.withValues(alpha: 0.6),
            width: 1.2,
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
        // foregroundColor: Colors.white,
        foregroundColor: onPrimaryColor,
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(pillRadius),
        ),
      ),
    );
  }
}
