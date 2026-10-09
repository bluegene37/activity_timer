import 'package:flutter/material.dart';

import 'app_theme.dart';

/// Washi-paper palette taken from genexis.dev. Scoped to the Brew section:
/// nothing outside `lib/screens/brew_*` should read these.
class BrewPalette {
  const BrewPalette({
    required this.paper,
    required this.paperRaised,
    required this.paperDeep,
    required this.ink,
    required this.inkSoft,
    required this.lead,
    required this.hairline,
  });

  final Color paper;
  final Color paperRaised;
  final Color paperDeep;
  final Color ink;
  final Color inkSoft;
  final Color lead;
  final Color hairline;
}

abstract final class BrewTheme {
  static const _light = BrewPalette(
    paper: Color(0xFFF2EDE3),
    paperRaised: Color(0xFFFAF7F0),
    paperDeep: Color(0xFFE7E0D0),
    ink: Color(0xFF16161A),
    inkSoft: Color(0xFF5A564E),
    lead: Color(0xFFB4402C),
    hairline: Color(0x2E2B2B2E),
  );

  // The site is light-only; these are derived so the tab still works in the
  // app's dark mode. Lead is lifted for contrast against dark paper.
  static const _dark = BrewPalette(
    paper: Color(0xFF1B1815),
    paperRaised: Color(0xFF241F1B),
    paperDeep: Color(0xFF15120F),
    ink: Color(0xFFF2EDE3),
    inkSoft: Color(0xFFB8B0A2),
    lead: Color(0xFFD9614A),
    hairline: Color(0x33F2EDE3),
  );

  static const fontFamily = 'Literata';

  static BrewPalette paletteFor(Brightness brightness) =>
      brightness == Brightness.dark ? _dark : _light;

  // Gene - Oct, 9, 2026: Preserved original of(BuildContext) implementation.
  // static BrewPalette of(BuildContext context) =>
  //     paletteFor(Theme.of(context).brightness);

  // Gene - Oct, 9, 2026: Adapted BrewTheme.of(context) so Brew screens respect both
  // Coffee theme (washi palette) and Modern theme (system/iOS palette derived from Theme.of(context)).
  static BrewPalette of(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;

    // When the ambient theme is the washi Coffee theme (using Literata)
    if (theme.textTheme.bodyMedium?.fontFamily == fontFamily) {
      return paletteFor(theme.brightness);
    }

    // When wearing the Modern (iOS / AppTheme) look
    return BrewPalette(
      paper: theme.scaffoldBackgroundColor,
      paperRaised:
          theme.cardTheme.color ?? AppTheme.cardBackground(isDark: isDark),
      paperDeep: colorScheme.surfaceContainerHighest,
      ink: colorScheme.onSurface,
      inkSoft: colorScheme.onSurfaceVariant,
      lead: colorScheme.primary,
      hairline: AppTheme.separator(isDark: isDark),
    );
  }

  /// A theme that keeps [AppTheme]'s radii and spacing so the Brew section
  /// shares the app's layout grammar while changing palette and type.
  static ThemeData themeFor(Brightness brightness) {
    final palette = paletteFor(brightness);
    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: palette.lead,
      onPrimary: palette.paperRaised,
      secondary: palette.inkSoft,
      onSecondary: palette.paperRaised,
      surface: palette.paperRaised,
      onSurface: palette.ink,
      surfaceContainerHighest: palette.paperDeep,
      onSurfaceVariant: palette.inkSoft,
      outlineVariant: palette.hairline,
      error: palette.lead,
      onError: palette.paperRaised,
    );

    // Derive from AppTheme so the two app themes share an identical
    // TextTheme structure: MaterialApp animates theme switches with
    // TextStyle.lerp, which throws when the styles' `inherit` flags differ.
    final base =
        brightness == Brightness.dark
            ? AppTheme.getDarkTheme(palette.lead)
            : AppTheme.getLightTheme(palette.lead);

    return base.copyWith(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: palette.paper,
      textTheme: base.textTheme.apply(
        fontFamily: fontFamily,
        bodyColor: palette.ink,
        displayColor: palette.ink,
      ),
      cardTheme: CardThemeData(
        color: palette.paperRaised,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
          side: BorderSide(color: palette.hairline),
        ),
      ),
      dividerTheme: DividerThemeData(color: palette.hairline, thickness: 0.6),
      // Derive from AppTheme's button style rather than styleFrom: the two
      // themes' buttons must resolve textStyles with the SAME `inherit` flag,
      // or the button's AnimatedDefaultTextStyle throws on every theme
      // switch. AppTheme sets a raw inherit-true textStyle; dropping it here
      // made coffee buttons fall back to labelLarge (inherit-false, merged
      // with typography), which cannot lerp against it.
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: (base.elevatedButtonTheme.style ?? const ButtonStyle()).copyWith(
          backgroundColor: WidgetStatePropertyAll(palette.lead),
          foregroundColor: WidgetStatePropertyAll(palette.paperRaised),
          textStyle: const WidgetStatePropertyAll(
            TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.2,
              fontFamily: fontFamily,
            ),
          ),
        ),
      ),
    );
  }
}
