import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:activity_timer/components/glowing_timer_ring.dart';
import 'package:activity_timer/components/color_selector.dart';

void main() {
  group('GlowingTimerRing Widget tests', () {
    testWidgets('renders GlowingTimerRing with child content', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: GlowingTimerRing(
                progress: 0.5,
                color: Colors.blue,
                backgroundColor: Colors.grey,
                size: 200,
                child: Text('05:00'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('05:00'), findsOneWidget);
    });
  });

  group('ColorSelector Widget tests', () {
    testWidgets('renders ColorSelector and allows tapping options', (WidgetTester tester) async {
      Color? tappedColor;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: ColorSelector(
                selectedColor: Colors.blue,
                onColorSelected: (color) {
                  tappedColor = color;
                },
              ),
            ),
          ),
        ),
      );

      expect(find.byType(GestureDetector), findsWidgets);
      
      // Tap the second color option
      await tester.tap(find.byType(GestureDetector).at(1));
      await tester.pump();

      expect(tappedColor, isNotNull);
    });
  });
}
