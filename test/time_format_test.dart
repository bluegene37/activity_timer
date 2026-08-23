import 'package:activity_timer/utils/time_format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TimeFormat.clock', () {
    test('formats seconds under a minute', () {
      expect(TimeFormat.clock(45), '0:45');
      expect(TimeFormat.clock(5), '0:05');
    });

    test('formats minutes and seconds', () {
      expect(TimeFormat.clock(303), '5:03');
      expect(TimeFormat.clock(60), '1:00');
    });

    test('formats hours', () {
      expect(TimeFormat.clock(3765), '1:02:45');
      expect(TimeFormat.clock(3600), '1:00:00');
    });

    test('formats zero', () {
      expect(TimeFormat.clock(0), '0:00');
    });
  });

  group('TimeFormat.compact', () {
    test('seconds only', () {
      expect(TimeFormat.compact(45), '45s');
      expect(TimeFormat.compact(0), '0s');
    });

    test('minutes only', () {
      expect(TimeFormat.compact(120), '2m');
    });

    test('minutes and seconds', () {
      expect(TimeFormat.compact(90), '1m 30s');
    });

    test('hours combinations', () {
      expect(TimeFormat.compact(3600), '1h');
      expect(TimeFormat.compact(3920), '1h 5m 20s');
      expect(TimeFormat.compact(7200), '2h');
    });
  });
}
