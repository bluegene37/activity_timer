import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:path_provider/path_provider.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../models/alarm_sound.dart';
import 'cue_player.dart';

/// One alarm the OS should raise on its own, at [at].
@immutable
class ScheduledAlarm {
  const ScheduledAlarm({
    required this.id,
    required this.at,
    required this.title,
    required this.body,
    this.sound,
    this.isCompletion = false,
  });

  /// Stable within a session; ids are reused across reschedules so a stale
  /// notification is always replaced rather than duplicated.
  final int id;
  final DateTime at;
  final String title;
  final String body;

  /// The routine's chosen cue. Null falls back to the system default.
  final AlarmSound? sound;

  /// The end of the whole session, which uses the dedicated completion cue.
  final bool isCompletion;

  @override
  bool operator ==(Object other) =>
      other is ScheduledAlarm &&
      other.id == id &&
      other.at == at &&
      other.title == title &&
      other.body == body &&
      other.sound == sound &&
      other.isCompletion == isCompletion;

  @override
  int get hashCode => Object.hash(id, at, title, body, sound, isCompletion);

  @override
  String toString() => 'ScheduledAlarm($id, $at, $title)';
}

/// Raises alarms while the app is backgrounded or the screen is locked.
///
/// In-app cues (see `CuePlayer`) only sound while Flutter is running: iOS
/// suspends Dart timers the moment the app leaves the foreground, so a timer
/// that must survive a locked phone has to hand its boundaries to the OS.
/// This is that hand-off. The two mechanisms run together — whichever fires
/// first, the user is told — so a foreground session is never made worse by
/// a denied notification permission.
abstract interface class AlarmScheduler {
  /// Asks for permission if needed. Returns false when alarms cannot be
  /// raised in the background; callers carry on regardless.
  Future<bool> ensurePermission();

  /// Replaces every pending alarm for this session with [alarms].
  Future<void> schedule(List<ScheduledAlarm> alarms);

  /// Drops every pending alarm — a paused, finished, or abandoned session.
  Future<void> cancelAll();
}

/// The production scheduler, backed by OS local notifications.
class LocalNotificationAlarmScheduler implements AlarmScheduler {
  LocalNotificationAlarmScheduler({
    FlutterLocalNotificationsPlugin? plugin,
    this.idBase = activityIdBase,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const String channelId = 'activity_timer_alarms';
  static const String channelName = 'Timer alarms';
  static const String channelDescription =
      'Fires when a timer, interval, or brew step reaches its end.';

  /// How many notification ids one session type owns. Every scheduler gets
  /// its own block because an activity routine, a brew, and an interval
  /// schedule can all be live at once (each has its own floater in
  /// `MainNavigation`) and each numbers its alarms from zero — one shared
  /// block would let a brew's step alarm quietly replace a routine's.
  static const int idSpaceSize = 1000;

  /// Notifications survive the process, so ids must not collide with a
  /// previous run: every session type's alarms live in one reserved block.
  static const int activityIdBase = 9000;
  static const int brewIdBase = activityIdBase + idSpaceSize;
  static const int intervalIdBase = activityIdBase + 2 * idSpaceSize;

  /// The first notification id this scheduler owns. It owns
  /// [idSpaceSize] ids from here.
  final int idBase;

  final FlutterLocalNotificationsPlugin _plugin;

  bool _initialized = false;
  final Set<int> _pending = <int>{};

  /// iOS plays notification audio only from the app bundle or the app
  /// container's Library/Sounds directory — a Flutter asset is neither. So
  /// the cues are copied there once, which keeps the sounds in `assets/`
  /// as the single source of truth instead of duplicating them into the
  /// Xcode project.
  Future<void> _installDarwinSounds() async {
    if (!Platform.isIOS && !Platform.isMacOS) {
      return;
    }
    try {
      final library = await getLibraryDirectory();
      final sounds = Directory('${library.path}/Sounds');
      if (!sounds.existsSync()) {
        sounds.createSync(recursive: true);
      }
      for (final fileName in _cueFileNames) {
        final target = File('${sounds.path}/$fileName');
        if (target.existsSync()) {
          continue;
        }
        final data = await rootBundle.load('assets/sounds/$fileName');
        await target.writeAsBytes(
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
          flush: true,
        );
      }
    } catch (_) {
      // Without the copy iOS falls back to the default alert sound.
    }
  }

  static Iterable<String> get _cueFileNames sync* {
    for (final sound in AlarmSound.values) {
      yield sound.fileName;
    }
    yield AudioCuePlayer.completionSound;
  }

  /// Android ties a sound to its channel and will not let it change
  /// afterwards, so each cue gets its own channel.
  static String channelIdFor(AlarmSound? sound, {required bool isCompletion}) {
    if (isCompletion) {
      return '${channelId}_complete';
    }
    return sound == null ? channelId : '${channelId}_${sound.name}';
  }

  static String _rawResourceFor(String fileName) =>
      fileName.split('.').first.toLowerCase().replaceAll('-', '_');

  Future<void> _init() async {
    if (_initialized) {
      return;
    }
    tz_data.initializeTimeZones();
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/launcher_icon'),
        // Permission is requested explicitly in ensurePermission() so the
        // prompt lands when the user starts a timer, not at cold start.
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    await _installDarwinSounds();
    _initialized = true;
  }

  @override
  Future<bool> ensurePermission() async {
    try {
      await _init();
      final android =
          _plugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >();
      if (android != null) {
        final granted = await android.requestNotificationsPermission();
        return granted ?? false;
      }
      final ios =
          _plugin
              .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin
              >();
      if (ios != null) {
        final granted = await ios.requestPermissions(alert: true, sound: true);
        return granted ?? false;
      }
      return false;
    } catch (_) {
      // No notifications is a degraded mode, never a crash.
      return false;
    }
  }

  @override
  Future<void> schedule(List<ScheduledAlarm> alarms) async {
    try {
      await _init();
      await cancelAll();

      final now = DateTime.now();
      for (final alarm in alarms) {
        if (!alarm.at.isAfter(now)) {
          continue; // Already elapsed: the in-app cue covered it.
        }
        if (alarm.id < 0 || alarm.id >= idSpaceSize) {
          continue; // Outside this scheduler's block: never another's alarm.
        }
        await _plugin.zonedSchedule(
          id: idBase + alarm.id,
          title: alarm.title,
          body: alarm.body,
          scheduledDate: tz.TZDateTime.from(alarm.at, tz.local),
          notificationDetails: _detailsFor(alarm),
          // Exact timing is the entire point of a timer; inexact scheduling
          // would drift by minutes under Doze.
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        );
        _pending.add(idBase + alarm.id);
      }
    } catch (_) {
      // Scheduling is best-effort; the in-app cue still fires.
    }
  }

  /// The alarm's own cue, on both platforms, so a background alarm sounds
  /// like the one the routine was set up with.
  NotificationDetails _detailsFor(ScheduledAlarm alarm) {
    final fileName =
        alarm.isCompletion
            ? AudioCuePlayer.completionSound
            : alarm.sound?.fileName;

    return NotificationDetails(
      android: AndroidNotificationDetails(
        channelIdFor(alarm.sound, isCompletion: alarm.isCompletion),
        channelName,
        channelDescription: channelDescription,
        importance: Importance.max,
        priority: Priority.high,
        // An alarm should read as an alarm on the lock screen.
        category: AndroidNotificationCategory.alarm,
        fullScreenIntent: true,
        audioAttributesUsage: AudioAttributesUsage.alarm,
        sound:
            fileName == null
                ? null
                : RawResourceAndroidNotificationSound(
                  _rawResourceFor(fileName),
                ),
      ),
      iOS: DarwinNotificationDetails(
        interruptionLevel: InterruptionLevel.timeSensitive,
        sound: fileName,
      ),
    );
  }

  @override
  Future<void> cancelAll() async {
    try {
      await _init();
      // Notifications outlive the process, so a session killed mid-run
      // leaves alarms this in-memory set knows nothing about. Sweep the
      // whole owned block instead, or those orphans fire in the middle of
      // an unrelated session days later.
      final ids = <int>{..._pending};
      for (final request in await _plugin.pendingNotificationRequests()) {
        if (request.id >= idBase && request.id < idBase + idSpaceSize) {
          ids.add(request.id);
        }
      }
      for (final id in ids) {
        await _plugin.cancel(id: id);
      }
      _pending.clear();
    } catch (_) {}
  }
}

/// Used when a session should not touch the OS at all (tests, and any
/// platform where notifications are unavailable).
class NoopAlarmScheduler implements AlarmScheduler {
  @override
  Future<bool> ensurePermission() async => false;

  @override
  Future<void> schedule(List<ScheduledAlarm> alarms) async {}

  @override
  Future<void> cancelAll() async {}
}
