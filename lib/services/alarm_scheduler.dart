import 'dart:async';
import 'dart:io';

// Gene - Nov, 06, 2026: Commented out unnecessary foundation.dart import since widgets.dart already exports foundation elements.
// import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
// Gene - Nov, 06, 2026: Added widgets, routes, and session service imports to support notification tap handling.
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:path_provider/path_provider.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../models/alarm_sound.dart';
// Gene - Nov, 7, 2026: Commented out unused route imports after updating notification tap handler to surface MainNavigation with the running floater via UiMessenger.
// import '../routes/app_pages.dart';
// import '../routes/app_routes.dart';
import 'activity_session_service.dart';
import 'brew_session_service.dart';
import 'cue_player.dart';
import 'interval_session_service.dart';
import 'ui_messenger.dart';

/// One alarm the OS should raise on its own, at [at].
// Gene - Nov, 06, 2026: Preserved original ScheduledAlarm implementation.
// @immutable
// class ScheduledAlarm {
//   const ScheduledAlarm({
//     required this.id,
//     required this.at,
//     required this.title,
//     required this.body,
//     this.sound,
//     this.isCompletion = false,
//   });
//
//   /// Stable within a session; ids are reused across reschedules so a stale
//   /// notification is always replaced rather than duplicated.
//   final int id;
//   final DateTime at;
//   final String title;
//   final String body;
//
//   /// The routine's chosen cue. Null falls back to the system default.
//   final AlarmSound? sound;
//
//   /// The end of the whole session, which uses the dedicated completion cue.
//   final bool isCompletion;
//
//   @override
//   bool operator ==(Object other) =>
//       other is ScheduledAlarm &&
//       other.id == id &&
//       other.at == at &&
//       other.title == title &&
//       other.body == body &&
//       other.sound == sound &&
//       other.isCompletion == isCompletion;
//
//   @override
//   int get hashCode => Object.hash(id, at, title, body, sound, isCompletion);
//
//   @override
//   String toString() => 'ScheduledAlarm($id, $at, $title)';
// }

// Gene - Nov, 06, 2026: Added payload property to ScheduledAlarm to support deep navigation when tapping background notifications.
@immutable
class ScheduledAlarm {
  const ScheduledAlarm({
    required this.id,
    required this.at,
    required this.title,
    required this.body,
    this.sound,
    this.isCompletion = false,
    this.payload,
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

  /// Route/session payload used when the notification is tapped.
  final String? payload;

  @override
  bool operator ==(Object other) =>
      other is ScheduledAlarm &&
      other.id == id &&
      other.at == at &&
      other.title == title &&
      other.body == body &&
      other.sound == sound &&
      other.isCompletion == isCompletion &&
      other.payload == payload;

  @override
  int get hashCode => Object.hash(id, at, title, body, sound, isCompletion, payload);

  @override
  String toString() => 'ScheduledAlarm($id, $at, $title, payload: $payload)';
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
  // Gene - Nov, 8, 2026: Added optional clock parameter, operation serialization, and scheduled fire-time tracking so cancelAll never silences already-delivered notifications.
  // LocalNotificationAlarmScheduler({
  //   FlutterLocalNotificationsPlugin? plugin,
  //   this.idBase = activityIdBase,
  // }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin();
  LocalNotificationAlarmScheduler({
    FlutterLocalNotificationsPlugin? plugin,
    this.idBase = activityIdBase,
    DateTime Function()? clock,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin(),
       _clock = clock ?? DateTime.now;

  static const String channelId = 'activity_timer_alarms';
  // Gene - Nov, 8, 2026: Versioned Android notification channel prefix so devices with previously cached silent channels create fresh channels with sound bound.
  static const String channelIdV2 = '${channelId}_v2';
  static const String channelName = 'Timer alarms';
  static const String channelDescription =
      'Fires when a timer, interval, or brew step reaches its end.';
  // Gene - Nov, 8, 2026: Added notification action identifiers for Snooze (+5m) and Dismiss.
  static const String snooze5mActionId = 'snooze_5m';
  static const String dismissActionId = 'dismiss_alarm';

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
  final DateTime Function() _clock;

  bool _initialized = false;
  // Gene - Nov, 8, 2026: Replaced Set<int> _pending with Map<int, DateTime> _pending to track each notification's scheduled fire time and avoid cancelling delivered notifications whose sound is playing.
  // final Set<int> _pending = <int>{};
  final Map<int, DateTime> _pending = <int, DateTime>{};
  Future<void> _opChain = Future<void>.value();

  Future<T> _serialize<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    _opChain = _opChain.then((_) async {
      try {
        completer.complete(await action());
      } catch (e, st) {
        completer.completeError(e, st);
      }
    });
    return completer.future;
  }

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
        // Gene - Nov, 8, 2026: Ensure existing sound file is non-empty before skipping copy so a partial/0-byte file never silences iOS notifications.
        // if (target.existsSync()) {
        //   continue;
        // }
        if (target.existsSync() && target.lengthSync() > 0) {
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
  // Gene - Nov, 8, 2026: Versioned Android notification channel IDs to _v2 so Android registers fresh channels with raw sound resources instead of reusing cached silent v1 channels.
  // static String channelIdFor(AlarmSound? sound, {required bool isCompletion}) {
  //   if (isCompletion) {
  //     return '${channelId}_complete';
  //   }
  //   return sound == null ? channelId : '${channelId}_${sound.name}';
  // }
  static String channelIdFor(AlarmSound? sound, {required bool isCompletion}) {
    if (isCompletion) {
      return '${channelIdV2}_complete';
    }
    return sound == null ? channelIdV2 : '${channelIdV2}_${sound.name}';
  }

  static String _rawResourceFor(String fileName) =>
      fileName.split('.').first.toLowerCase().replaceAll('-', '_');

  // Gene - Nov, 06, 2026: Callback handling for tapping notifications to restore and route back to running screens.
  // static void onNotificationTapped(NotificationResponse response) {
  //   handlePayload(response.payload);
  // }
  //
  // static void handlePayload(String? payload) {
  //   if (payload == null) return;
  //   if (payload.startsWith('activity')) {
  //     final active = ActivitySessionService().active.value;
  //     if (active != null && !active.isCompleted.value) {
  //       AppPages.push<dynamic>(Routes.timer, extra: active.sequence);
  //     }
  //   } else if (payload.startsWith('interval')) {
  //     final active = IntervalSessionService().active.value;
  //     if (active != null && !active.isCompleted.value) {
  //       AppPages.push<dynamic>(Routes.intervalTimer, extra: active.timer);
  //     }
  //   } else if (payload.startsWith('brew')) {
  //     final active = BrewSessionService().active.value;
  //     if (active != null && !active.isFinished.value) {
  //       AppPages.push<dynamic>(Routes.brew, extra: active.recipe);
  //     }
  //   }
  // }

  // Gene - Nov, 7, 2026: Synchronize or restore active session on notification tap and surface MainNavigation so the running floating pill appears immediately.
  // Gene - Nov, 8, 2026: Support notification action buttons (snooze_5m and dismiss_alarm) in onNotificationTapped and handlePayload.
  // static void onNotificationTapped(NotificationResponse response) {
  //   unawaited(handlePayload(response.payload));
  // }
  //
  // static Future<void> handlePayload(String? payload) async {
  //   if (payload == null) return;
  //   if (payload.startsWith('activity')) {
  //     final active = await ActivitySessionService().syncOrRestore();
  //     if (active != null && !active.isCompleted.value) {
  //       _surfaceMainNavigationWithFloater();
  //     }
  //   } else if (payload.startsWith('interval')) {
  //     final active = await IntervalSessionService().syncOrRestore();
  //     if (active != null && !active.isCompleted.value) {
  //       _surfaceMainNavigationWithFloater();
  //     }
  //   } else if (payload.startsWith('brew')) {
  //     final active = await BrewSessionService().syncOrRestore();
  //     if (active != null && !active.isFinished.value) {
  //       _surfaceMainNavigationWithFloater();
  //     }
  //   }
  // }
  static void onNotificationTapped(NotificationResponse response) {
    unawaited(
      handlePayload(response.payload, actionId: response.actionId),
    );
  }

  static Future<void> handlePayload(
    String? payload, {
    String? actionId,
  }) async {
    if (payload == null) return;

    if (actionId == snooze5mActionId) {
      if (payload.startsWith('activity')) {
        final active = await ActivitySessionService().snoozeActiveOrRestored(
          const Duration(minutes: 5),
        );
        if (active != null) {
          _surfaceMainNavigationWithFloater();
        }
        return;
      } else if (payload.startsWith('interval')) {
        final active = await IntervalSessionService().snoozeActiveOrRestored(
          const Duration(minutes: 5),
        );
        if (active != null) {
          _surfaceMainNavigationWithFloater();
        }
        return;
      }
    }

    if (actionId == dismissActionId) {
      if (payload.startsWith('activity')) {
        ActivitySessionService().clear();
        return;
      } else if (payload.startsWith('interval')) {
        IntervalSessionService().clear();
        return;
      } else if (payload.startsWith('brew')) {
        BrewSessionService().clear();
        return;
      }
    }

    if (payload.startsWith('activity')) {
      final active = await ActivitySessionService().syncOrRestore();
      if (active != null && !active.isCompleted.value) {
        _surfaceMainNavigationWithFloater();
      }
    } else if (payload.startsWith('interval')) {
      final active = await IntervalSessionService().syncOrRestore();
      if (active != null && !active.isCompleted.value) {
        _surfaceMainNavigationWithFloater();
      }
    } else if (payload.startsWith('brew')) {
      final active = await BrewSessionService().syncOrRestore();
      if (active != null && !active.isFinished.value) {
        _surfaceMainNavigationWithFloater();
      }
    }
  }

  static void _surfaceMainNavigationWithFloater() {
    final nav = UiMessenger().navigatorKey.currentState;
    if (nav != null && nav.canPop()) {
      nav.popUntil((route) => route.isFirst);
    }
  }

  // Gene - Nov, 06, 2026: Initialize notifications at app launch and check if app was opened via notification tap.
  static Future<void> initializeAndCheckLaunch({
    FlutterLocalNotificationsPlugin? plugin,
  }) async {
    final scheduler = LocalNotificationAlarmScheduler(plugin: plugin);
    await scheduler._init();
    final p = plugin ?? scheduler._plugin;
    final details = await p.getNotificationAppLaunchDetails();
    if (details?.didNotificationLaunchApp ?? false) {
      final payload = details?.notificationResponse?.payload;
      if (payload != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          handlePayload(payload);
        });
      }
    }
  }

  // Gene - Nov, 06, 2026: Preserved original _init implementation.
  // Future<void> _init() async {
  //   if (_initialized) {
  //     return;
  //   }
  //   tz_data.initializeTimeZones();
  //   await _plugin.initialize(
  //     settings: const InitializationSettings(
  //       android: AndroidInitializationSettings('@mipmap/launcher_icon'),
  //       // Permission is requested explicitly in ensurePermission() so the
  //       // prompt lands when the user starts a timer, not at cold start.
  //       iOS: DarwinInitializationSettings(
  //         requestAlertPermission: false,
  //         requestBadgePermission: false,
  //         requestSoundPermission: false,
  //       ),
  //     ),
  //   );
  //   await _installDarwinSounds();
  //   _initialized = true;
  // }

  // Gene - Nov, 06, 2026: Added onDidReceiveNotificationResponse callback in _init so user notification taps route back to active sessions.
  // Gene - Nov, 8, 2026: Also clean up legacy v1 Android notification channels so devices migrate cleanly to v2 sound-enabled channels.
  // Future<void> _init() async {
  //   if (_initialized) {
  //     return;
  //   }
  //   tz_data.initializeTimeZones();
  //   await _plugin.initialize(
  //     settings: const InitializationSettings(
  //       android: AndroidInitializationSettings('@mipmap/launcher_icon'),
  //       // Permission is requested explicitly in ensurePermission() so the
  //       // prompt lands when the user starts a timer, not at cold start.
  //       iOS: DarwinInitializationSettings(
  //         requestAlertPermission: false,
  //         requestBadgePermission: false,
  //         requestSoundPermission: false,
  //       ),
  //     ),
  //     onDidReceiveNotificationResponse: onNotificationTapped,
  //   );
  //   await _installDarwinSounds();
  //   _initialized = true;
  // }
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
      onDidReceiveNotificationResponse: onNotificationTapped,
    );
    await _cleanupLegacyAndroidChannels();
    await _installDarwinSounds();
    _initialized = true;
  }

  Future<void> _cleanupLegacyAndroidChannels() async {
    try {
      final android =
          _plugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >();
      if (android == null) {
        return;
      }
      await android.deleteNotificationChannel(channelId: channelId);
      await android.deleteNotificationChannel(channelId: '${channelId}_complete');
      for (final sound in AlarmSound.values) {
        await android.deleteNotificationChannel(
          channelId: '${channelId}_${sound.name}',
        );
      }
    } catch (_) {}
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

  // Gene - Nov, 06, 2026: Preserved original schedule implementation.
  // @override
  // Future<void> schedule(List<ScheduledAlarm> alarms) async {
  //   try {
  //     await _init();
  //     await cancelAll();
  //
  //     final now = DateTime.now();
  //     for (final alarm in alarms) {
  //       if (!alarm.at.isAfter(now)) {
  //         continue; // Already elapsed: the in-app cue covered it.
  //       }
  //       if (alarm.id < 0 || alarm.id >= idSpaceSize) {
  //         continue; // Outside this scheduler's block: never another's alarm.
  //       }
  //       await _plugin.zonedSchedule(
  //         id: idBase + alarm.id,
  //         title: alarm.title,
  //         body: alarm.body,
  //         scheduledDate: tz.TZDateTime.from(alarm.at, tz.local),
  //         notificationDetails: _detailsFor(alarm),
  //         // Exact timing is the entire point of a timer; inexact scheduling
  //         // would drift by minutes under Doze.
  //         androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
  //       );
  //       _pending.add(idBase + alarm.id);
  //     }
  //   } catch (_) {
  //     // Scheduling is best-effort; the in-app cue still fires.
  //   }
  // }

  // Gene - Nov, 06, 2026: Passed payload into zonedSchedule to attach session routing info to background notifications.
  // Gene - Nov, 8, 2026: Serialized schedule/cancelAll operations and recorded scheduled fire times so already-delivered notifications are never cancelled while their sound plays.
  // @override
  // Future<void> schedule(List<ScheduledAlarm> alarms) async {
  //   try {
  //     await _init();
  //     await cancelAll();
  //
  //     final now = DateTime.now();
  //     for (final alarm in alarms) {
  //       if (!alarm.at.isAfter(now)) {
  //         continue; // Already elapsed: the in-app cue covered it.
  //       }
  //       if (alarm.id < 0 || alarm.id >= idSpaceSize) {
  //         continue; // Outside this scheduler's block: never another's alarm.
  //       }
  //       await _plugin.zonedSchedule(
  //         id: idBase + alarm.id,
  //         title: alarm.title,
  //         body: alarm.body,
  //         scheduledDate: tz.TZDateTime.from(alarm.at, tz.local),
  //         notificationDetails: _detailsFor(alarm),
  //         // Exact timing is the entire point of a timer; inexact scheduling
  //         // would drift by minutes under Doze.
  //         androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
  //         payload:
  //             alarm.payload ??
  //             (idBase == activityIdBase
  //                 ? 'activity'
  //                 : (idBase == intervalIdBase ? 'interval' : 'brew')),
  //       );
  //       _pending.add(idBase + alarm.id);
  //     }
  //   } catch (_) {
  //     // Scheduling is best-effort; the in-app cue still fires.
  //   }
  // }
  @override
  Future<void> schedule(List<ScheduledAlarm> alarms) => _serialize(() async {
    try {
      await _init();
      await _cancelUnfiredPending();

      final now = _clock();
      for (final alarm in alarms) {
        if (!alarm.at.isAfter(now)) {
          continue; // Already elapsed: the in-app cue covered it.
        }
        if (alarm.id < 0 || alarm.id >= idSpaceSize) {
          continue; // Outside this scheduler's block: never another's alarm.
        }
        final notificationId = idBase + alarm.id;
        await _plugin.zonedSchedule(
          id: notificationId,
          title: alarm.title,
          body: alarm.body,
          scheduledDate: tz.TZDateTime.from(alarm.at, tz.local),
          notificationDetails: _detailsFor(alarm),
          // Exact timing is the entire point of a timer; inexact scheduling
          // would drift by minutes under Doze.
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          payload:
              alarm.payload ??
              (idBase == activityIdBase
                  ? 'activity'
                  : (idBase == intervalIdBase ? 'interval' : 'brew')),
        );
        _pending[notificationId] = alarm.at;
      }
    } catch (_) {
      // Scheduling is best-effort; the in-app cue still fires.
    }
  });

  // Gene - Nov, 8, 2026: Expose notification details builder for unit test verification of platform sound and banner settings.
  @visibleForTesting
  NotificationDetails detailsForTesting(ScheduledAlarm alarm) =>
      _detailsFor(alarm);

  /// The alarm's own cue, on both platforms, so a background alarm sounds
  /// like the one the routine was set up with.
  // Gene - Nov, 8, 2026: Explicitly enabled playSound, enableVibration, channelAction.update on Android and presentSound/presentBanner/presentList/presentAlert on iOS so notification toasts always play their sound.
  // NotificationDetails _detailsFor(ScheduledAlarm alarm) {
  //   final fileName =
  //       alarm.isCompletion
  //           ? AudioCuePlayer.completionSound
  //           : alarm.sound?.fileName;
  //
  //   return NotificationDetails(
  //     android: AndroidNotificationDetails(
  //       channelIdFor(alarm.sound, isCompletion: alarm.isCompletion),
  //       channelName,
  //       channelDescription: channelDescription,
  //       importance: Importance.max,
  //       priority: Priority.high,
  //       // An alarm should read as an alarm on the lock screen.
  //       category: AndroidNotificationCategory.alarm,
  //       fullScreenIntent: true,
  //       audioAttributesUsage: AudioAttributesUsage.alarm,
  //       sound:
  //           fileName == null
  //               ? null
  //               : RawResourceAndroidNotificationSound(
  //                 _rawResourceFor(fileName),
  //               ),
  //     ),
  //     iOS: DarwinNotificationDetails(
  //       interruptionLevel: InterruptionLevel.timeSensitive,
  //       sound: fileName,
  //     ),
  //   );
  // }
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
        playSound: true,
        enableVibration: true,
        channelAction: AndroidNotificationChannelAction.update,
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
        // Gene - Nov, 8, 2026: Attach Snooze 5m and Dismiss action buttons to alarm notifications.
        actions: const <AndroidNotificationAction>[
          AndroidNotificationAction(
            snooze5mActionId,
            'Snooze 5m',
            showsUserInterface: true,
          ),
          AndroidNotificationAction(
            dismissActionId,
            'Dismiss',
            cancelNotification: true,
            showsUserInterface: true,
          ),
        ],
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBanner: true,
        presentList: true,
        presentSound: true,
        interruptionLevel: InterruptionLevel.timeSensitive,
        sound: fileName,
      ),
    );
  }

  // Gene - Nov, 8, 2026: Only cancel unfired pending notifications so already-delivered notifications in the system tray keep playing their alarm sound.
  // @override
  // Future<void> cancelAll() async {
  //   try {
  //     await _init();
  //     // Notifications outlive the process, so a session killed mid-run
  //     // leaves alarms this in-memory set knows nothing about. Sweep the
  //     // whole owned block instead, or those orphans fire in the middle of
  //     // an unrelated session days later.
  //     final ids = <int>{..._pending};
  //     for (final request in await _plugin.pendingNotificationRequests()) {
  //       if (request.id >= idBase && request.id < idBase + idSpaceSize) {
  //         ids.add(request.id);
  //       }
  //     }
  //     for (final id in ids) {
  //       await _plugin.cancel(id: id);
  //     }
  //     _pending.clear();
  //   } catch (_) {}
  // }
  @override
  Future<void> cancelAll() => _serialize(() async {
    try {
      await _init();
      await _cancelUnfiredPending();
    } catch (_) {}
  });

  Future<void> _cancelUnfiredPending() async {
    final now = _clock();
    // Notifications outlive the process, so a session killed mid-run
    // leaves alarms this in-memory map knows nothing about. Sweep all
    // unfired pending requests in the owned block, plus any in-memory IDs
    // whose scheduled fire time is still in the future. Do NOT cancel IDs
    // whose fire time has already arrived, because _plugin.cancel(id) also
    // dismisses delivered notifications and cuts off their sound mid-playback.
    final ids = <int>{
      for (final entry in _pending.entries)
        if (entry.value.isAfter(now)) entry.key,
    };
    for (final request in await _plugin.pendingNotificationRequests()) {
      if (request.id >= idBase && request.id < idBase + idSpaceSize) {
        ids.add(request.id);
      }
    }
    for (final id in ids) {
      await _plugin.cancel(id: id);
    }
    _pending.clear();
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
