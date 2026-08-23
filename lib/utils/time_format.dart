/// Shared time formatting helpers used across screens and controllers.
abstract final class TimeFormat {
  /// Clock-style format: "5:03", "1:02:45".
  static String clock(int seconds) {
    final hours = seconds ~/ Duration.secondsPerHour;
    final minutes =
        (seconds % Duration.secondsPerHour) ~/ Duration.secondsPerMinute;
    final remainingSeconds = seconds % Duration.secondsPerMinute;

    if (hours > 0) {
      return '$hours:${_pad(minutes)}:${_pad(remainingSeconds)}';
    }
    return '$minutes:${_pad(remainingSeconds)}';
  }

  /// Compact human format: "1h 5m 20s", "45s", "2m".
  static String compact(int totalSeconds) {
    final hours = totalSeconds ~/ Duration.secondsPerHour;
    final minutes =
        (totalSeconds % Duration.secondsPerHour) ~/ Duration.secondsPerMinute;
    final seconds = totalSeconds % Duration.secondsPerMinute;

    final parts = [
      if (hours > 0) '${hours}h',
      if (minutes > 0 || (hours > 0 && seconds > 0)) '${minutes}m',
    ];

    if (seconds > 0 || parts.isEmpty) {
      parts.add('${seconds}s');
    }

    return parts.join(' ');
  }

  static String _pad(int value) => value.toString().padLeft(2, '0');
}
