import 'package:activity_timer/theme/brew_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('light palette matches the genexis.dev tokens', () {
    final palette = BrewTheme.paletteFor(Brightness.light);
    expect(palette.paper, const Color(0xFFF2EDE3));
    expect(palette.paperRaised, const Color(0xFFFAF7F0));
    expect(palette.ink, const Color(0xFF16161A));
    expect(palette.inkSoft, const Color(0xFF5A564E));
    expect(palette.lead, const Color(0xFFB4402C));
  });

  test('dark palette inverts paper and ink and lifts the accent', () {
    final palette = BrewTheme.paletteFor(Brightness.dark);
    expect(palette.paper, const Color(0xFF1B1815));
    expect(palette.ink, const Color(0xFFF2EDE3));
    expect(palette.lead, const Color(0xFFD9614A));
  });

  test('theme uses Literata and paints the paper background', () {
    final theme = BrewTheme.themeFor(Brightness.light);
    expect(theme.textTheme.bodyMedium?.fontFamily, 'Literata');
    expect(theme.scaffoldBackgroundColor, const Color(0xFFF2EDE3));
    expect(theme.brightness, Brightness.light);
  });

  testWidgets('BrewTheme.of reads the palette from the ambient brightness', (
    tester,
  ) async {
    late BrewPalette seen;
    await tester.pumpWidget(
      MaterialApp(
        theme: BrewTheme.themeFor(Brightness.dark),
        home: Builder(
          builder: (context) {
            seen = BrewTheme.of(context);
            return const SizedBox();
          },
        ),
      ),
    );
    expect(seen.paper, const Color(0xFF1B1815));
  });
}
