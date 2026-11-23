import 'dart:async';
import 'dart:io';

// Gene - Nov, 06, 2026: Commented out unnecessary foundation.dart import since widgets.dart already exports foundation elements.
// Gene - Nov, 22, 2026: Expose MethodChannel and visibleForTesting alongside PlatformException/rootBundle for timezone lookup, system settings launch, and test resets.
// // Gene - Nov, 15, 2026: Import TargetPlatform and defaultTargetPlatform for Android exact-alarm capability probing.
// // import 'package:flutter/foundation.dart';
// import 'package:flutter/foundation.dart'
//     show TargetPlatform, defaultTargetPlatform;
// // Gene - Nov, 15, 2026: Expose PlatformException alongside rootBundle so exact-alarm denial on Android falls back to inexact scheduling.
// // import 'package:flutter/services.dart' show rootBundle;
// import 'package:flutter/services.dart' show PlatformException, rootBundle;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, visibleForTesting;
import 'package:flutter/services.dart'
    show MethodChannel, PlatformException, rootBundle;
// Gene - Nov, 06, 2026: Added widgets, routes, and session service imports to support notification tap handling.
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:path_provider/path_provider.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../models/alarm_sound.dart';
// Gene - Nov, 22, 2026: Read user sound and vibration preferences for OS notifications.
import '../models/settings.dart';
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

// Gene - Nov, 22, 2026: Expose current OS notification & exact alarm permission status for SettingsScreen.
@immutable
class NotificationPermissionStatus {
  const NotificationPermissionStatus({
    this.notificationsEnabled,
    this.exactAlarmsEnabled,
  });

  final bool? notificationsEnabled;
  final bool? exactAlarmsEnabled;

  bool get needsAttention =>
      notificationsEnabled == false || exactAlarmsEnabled == false;
}

/// The production scheduler, backed by OS local notifications.
// Gene - Nov, 22, 2026: Added foreground deferral state, permission deduplication, and per-block clocks to _PluginScheduleState.
// // Gene - Nov, 15, 2026: Shared per-plugin serialization and pending-ID state so cross-instance cancelAll() calls from an ending controller never race ahead of or wipe a newly started session's alarms.
// class _PluginScheduleState {
//   bool initialized = false;
//   Future<void> opChain = Future<void>.value();
//   final Map<int, Map<int, DateTime>> pendingByBlock =
//       <int, Map<int, DateTime>>{};
//
//   Map<int, DateTime> pendingFor(int idBase) =>
//       pendingByBlock.putIfAbsent(idBase, () => <int, DateTime>{});
// }
class _PluginScheduleState {
  bool initialized = false;
  Future<void> opChain = Future<void>.value();
  final Map<int, Map<int, DateTime>> pendingByBlock =
      <int, Map<int, DateTime>>{};
  bool appInForeground = false;
  final Map<int, List<ScheduledAlarm>> deferredAlarmsByBlock =
      <int, List<ScheduledAlarm>>{};
  final Map<int, DateTime Function()> clockByBlock =
      <int, DateTime Function()>{};
  Future<bool>? permissionRequestInFlight;
  bool permissionGranted = false;

  Map<int, DateTime> pendingFor(int idBase) =>
      pendingByBlock.putIfAbsent(idBase, () => <int, DateTime>{});
}

class LocalNotificationAlarmScheduler implements AlarmScheduler {
  // Gene - Nov, 8, 2026: Added optional clock parameter, operation serialization, and scheduled fire-time tracking so cancelAll never silences already-delivered notifications.
  // LocalNotificationAlarmScheduler({
  //   FlutterLocalNotificationsPlugin? plugin,
  //   this.idBase = activityIdBase,
  // }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin();
  // Gene - Nov, 15, 2026: Route default plugin calls through a single shared _defaultPlugin so separate controller schedulers serialize on the same Expando-backed state.
  // LocalNotificationAlarmScheduler({
  //   FlutterLocalNotificationsPlugin? plugin,
  //   this.idBase = activityIdBase,
  //   DateTime Function()? clock,
  // }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin(),
  //      _clock = clock ?? DateTime.now;
  LocalNotificationAlarmScheduler({
    FlutterLocalNotificationsPlugin? plugin,
    this.idBase = activityIdBase,
    DateTime Function()? clock,
  }) : _plugin = plugin ?? _defaultPlugin,
       _clock = clock ?? DateTime.now;

  static const String channelId = 'activity_timer_alarms';
  // Gene - Nov, 8, 2026: Versioned Android notification channel prefix so devices with previously cached silent channels create fresh channels with sound bound.
  static const String channelIdV2 = '${channelId}_v2';
  // Gene - Nov, 22, 2026: Versioned channel prefix _v3 with proactive createIfNotExists channel registration and mute/vibrate variants.
  static const String channelIdV3 = '${channelId}_v3';
  static const String channelName = 'Timer alarms';
  static const String channelDescription =
      'Fires when a timer, interval, or brew step reaches its end.';
  static const MethodChannel _platformChannel = MethodChannel(
    'dev.genexis.activitytimer/platform',
  );
  // Gene - Nov, 8, 2026: Added notification action identifiers for Snooze (+5m) and Dismiss.
  static const String snooze5mActionId = 'snooze_5m';
  static const String dismissActionId = 'dismiss_alarm';
  // Gene - Nov, 14, 2026: Added iOS notification category identifiers so Snooze/Dismiss action buttons appear on Darwin notifications and Brew alerts omit Snooze.
  static const String alarmCategoryId = 'alarm_actions';
  static const String brewCategoryId = 'brew_actions';

  /// How many notification ids one session type owns. Every scheduler gets
  /// its own block because an activity routine, a brew, and an interval
  /// schedule can all be live at once (each has its own floater in
  /// `MainNavigation`) and each numbers its alarms from zero — one shared
  /// block would let a brew's step alarm quietly replace a routine's.
  static const int idSpaceSize = 1000;
  // Gene - Nov, 15, 2026: Bound queued OS notifications per session to 20 so 3 concurrent sessions (<= 60) stay below iOS's 64-notification per-app limit and Android's 500-alarm cap.
  static const int maxPendingPerSession = 20;

  static final FlutterLocalNotificationsPlugin _defaultPlugin =
      FlutterLocalNotificationsPlugin();
  static final Expando<_PluginScheduleState> _pluginStates =
      Expando<_PluginScheduleState>('LocalNotificationAlarmSchedulerState');

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

  // Gene - Nov, 15, 2026: Back _initialized, _pending, and _opChain by per-plugin Expando state so separate controller instances serialize safely.
  // bool _initialized = false;
  // // Gene - Nov, 8, 2026: Replaced Set<int> _pending with Map<int, DateTime> _pending to track each notification's scheduled fire time and avoid cancelling delivered notifications whose sound is playing.
  // // final Set<int> _pending = <int>{};
  // final Map<int, DateTime> _pending = <int, DateTime>{};
  // Future<void> _opChain = Future<void>.value();
  //
  // Future<T> _serialize<T>(Future<T> Function() action) {
  //   final completer = Completer<T>();
  //   _opChain = _opChain.then((_) async {
  //     try {
  //       completer.complete(await action());
  //     } catch (e, st) {
  //       completer.completeError(e, st);
  //     }
  //   });
  //   return completer.future;
  // }
  _PluginScheduleState get _state =>
      _pluginStates[_plugin] ??= _PluginScheduleState();
  bool get _initialized => _state.initialized;
  set _initialized(bool value) => _state.initialized = value;
  Map<int, DateTime> get _pending => _state.pendingFor(idBase);

  Future<T> _serialize<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    final state = _state;
    state.opChain = state.opChain.then((_) async {
      try {
        completer.complete(await action());
      } catch (e, st) {
        completer.completeError(e, st);
      }
    });
    return completer.future;
  }

  // Gene - Nov, 22, 2026: Reset Expando state cleanly between automated tests.
  @visibleForTesting
  static void resetForTesting({FlutterLocalNotificationsPlugin? plugin}) {
    final target = plugin ?? _defaultPlugin;
    final state = _pluginStates[target];
    if (state != null) {
      state.initialized = false;
      state.opChain = Future<void>.value();
      state.pendingByBlock.clear();
      state.appInForeground = false;
      state.deferredAlarmsByBlock.clear();
      state.clockByBlock.clear();
      state.permissionRequestInFlight = null;
      state.permissionGranted = false;
    }
  }

  // Gene - Nov, 22, 2026: Track app foreground state so Android suppresses redundant OS notifications while active in foreground and flushes them to AlarmManager on background transition.
  static void setAppInForeground(
    bool inForeground, {
    FlutterLocalNotificationsPlugin? plugin,
  }) {
    final target = plugin ?? _defaultPlugin;
    final state = _pluginStates[target] ??= _PluginScheduleState();
    state.appInForeground = inForeground;
  }

  static Future<void> onAppForegrounded({
    FlutterLocalNotificationsPlugin? plugin,
  }) async {
    final target = plugin ?? _defaultPlugin;
    final state = _pluginStates[target] ??= _PluginScheduleState();
    if (state.appInForeground) {
      return;
    }
    state.appInForeground = true;
    if (defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    for (final blockBase in const <int>[
      activityIdBase,
      brewIdBase,
      intervalIdBase,
    ]) {
      final blockScheduler = LocalNotificationAlarmScheduler(
        plugin: target,
        idBase: blockBase,
        clock: state.clockByBlock[blockBase],
      );
      await blockScheduler._serialize(() async {
        try {
          await blockScheduler._init();
          await blockScheduler._cancelUnfiredPending();
        } catch (_) {}
      });
    }
  }

  static Future<void> onAppBackgrounded({
    FlutterLocalNotificationsPlugin? plugin,
  }) async {
    final target = plugin ?? _defaultPlugin;
    final state = _pluginStates[target] ??= _PluginScheduleState();
    final wasForeground = state.appInForeground;
    state.appInForeground = false;
    if (!wasForeground || defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    final entries = state.deferredAlarmsByBlock.entries.toList();
    for (final entry in entries) {
      if (entry.value.isEmpty) {
        continue;
      }
      final blockScheduler = LocalNotificationAlarmScheduler(
        plugin: target,
        idBase: entry.key,
        clock: state.clockByBlock[entry.key],
      );
      await blockScheduler._serialize(() async {
        try {
          await blockScheduler._init();
          await blockScheduler._scheduleAlarmsLocked(entry.value);
        } catch (_) {}
      });
    }
  }

  // Gene - Nov, 22, 2026: Inspect OS notification and exact alarm permissions, request permissions from Settings, or deep-link to system notification settings.
  static Future<NotificationPermissionStatus> checkNotificationStatus({
    FlutterLocalNotificationsPlugin? plugin,
  }) async {
    final target = plugin ?? _defaultPlugin;
    try {
      final android =
          target
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >();
      if (android != null) {
        bool? enabled;
        bool? exact;
        try {
          enabled = await android.areNotificationsEnabled();
        } catch (_) {}
        try {
          exact = await android.canScheduleExactNotifications();
        } catch (_) {}
        return NotificationPermissionStatus(
          notificationsEnabled: enabled,
          exactAlarmsEnabled: exact,
        );
      }
      final ios =
          target
              .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin
              >();
      if (ios != null) {
        NotificationsEnabledOptions? perms;
        try {
          perms = await ios.checkPermissions();
        } catch (_) {}
        return NotificationPermissionStatus(
          notificationsEnabled:
              perms == null
                  ? null
                  : (perms.isEnabled || perms.isProvisionalEnabled),
          exactAlarmsEnabled: null,
        );
      }
    } catch (_) {}
    return const NotificationPermissionStatus();
  }

  static Future<bool> requestPermissionsFromSettings({
    FlutterLocalNotificationsPlugin? plugin,
  }) async {
    final target = plugin ?? _defaultPlugin;
    final scheduler = LocalNotificationAlarmScheduler(plugin: target);
    scheduler._state.permissionGranted = false;
    final granted = await scheduler.ensurePermission();
    try {
      final android =
          target
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >();
      if (android != null) {
        final canExact = await android.canScheduleExactNotifications();
        if (canExact == false) {
          await android.requestExactAlarmsPermission();
        }
      }
    } catch (_) {}
    return granted;
  }

  static Future<bool> openSystemNotificationSettings() async {
    try {
      final opened = await _platformChannel.invokeMethod<bool>(
        'openNotificationSettings',
      );
      return opened ?? false;
    } catch (_) {
      return false;
    }
  }

  /// iOS plays notification audio only from the app bundle or the app
  /// container's Library/Sounds directory — a Flutter asset is neither. So
  /// the cues are copied there once, which keeps the sounds in `assets/`
  /// as the single source of truth instead of duplicating them into the
  /// Xcode project.
  // Gene - Nov, 22, 2026: Verify exact asset byte length before skipping copy in Library/Sounds and remove obsolete .mp3 files replaced by .wav.
  // Future<void> _installDarwinSounds() async {
  //   if (!Platform.isIOS && !Platform.isMacOS) {
  //     return;
  //   }
  //   try {
  //     final library = await getLibraryDirectory();
  //     final sounds = Directory('${library.path}/Sounds');
  //     if (!sounds.existsSync()) {
  //       sounds.createSync(recursive: true);
  //     }
  //     for (final fileName in _cueFileNames) {
  //       final target = File('${sounds.path}/$fileName');
  //       // Gene - Nov, 8, 2026: Ensure existing sound file is non-empty before skipping copy so a partial/0-byte file never silences iOS notifications.
  //       // if (target.existsSync()) {
  //       //   continue;
  //       // }
  //       if (target.existsSync() && target.lengthSync() > 0) {
  //         continue;
  //       }
  //       final data = await rootBundle.load('assets/sounds/$fileName');
  //       await target.writeAsBytes(
  //         data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
  //         flush: true,
  //       );
  //     }
  //   } catch (_) {
  //     // Without the copy iOS falls back to the default alert sound.
  //   }
  // }
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
      for (final legacyMp3 in const <String>[
        'bell.mp3',
        'chime.mp3',
        'digital.mp3',
        'gentle.mp3',
      ]) {
        final legacyFile = File('${sounds.path}/$legacyMp3');
        if (legacyFile.existsSync()) {
          legacyFile.deleteSync();
        }
      }
      for (final fileName in _cueFileNames) {
        final target = File('${sounds.path}/$fileName');
        final data = await rootBundle.load('assets/sounds/$fileName');
        if (target.existsSync() && target.lengthSync() == data.lengthInBytes) {
          continue;
        }
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
  // Gene - Nov, 22, 2026: Versioned Android channels to _v3 and branched channel IDs by sound/vibration settings so Sound Alerts & Vibration toggles work on Android 8+.
  // static String channelIdFor(AlarmSound? sound, {required bool isCompletion}) {
  //   if (isCompletion) {
  //     return '${channelIdV2}_complete';
  //   }
  //   return sound == null ? channelIdV2 : '${channelIdV2}_${sound.name}';
  // }
  static String channelIdFor(
    AlarmSound? sound, {
    required bool isCompletion,
    bool playSound = true,
    bool enableVibration = true,
  }) {
    if (!playSound && !enableVibration) {
      return '${channelIdV3}_silent';
    }
    if (!playSound && enableVibration) {
      return '${channelIdV3}_vibrate';
    }
    final vibSuffix = enableVibration ? '' : '_novib';
    if (isCompletion) {
      return '${channelIdV3}_complete$vibSuffix';
    }
    return sound == null
        ? '$channelIdV3$vibSuffix'
        : '${channelIdV3}_${sound.name}$vibSuffix';
  }

  static String _channelNameFor(
    AlarmSound? sound, {
    required bool isCompletion,
    bool playSound = true,
    bool enableVibration = true,
  }) {
    if (!playSound && !enableVibration) {
      return 'Timer alarms (Silent)';
    }
    if (!playSound && enableVibration) {
      return 'Timer alarms (Vibrate only)';
    }
    final vibLabel = enableVibration ? '' : ', no vibrate';
    if (isCompletion) {
      return 'Timer alarms (Complete$vibLabel)';
    }
    if (sound != null) {
      return 'Timer alarms (${sound.displayName}$vibLabel)';
    }
    return enableVibration ? channelName : '$channelName (No vibrate)';
  }

  static String _rawResourceFor(String fileName) =>
      fileName.split('.').first.toLowerCase().replaceAll('-', '_');

  // Gene - Nov, 22, 2026: Forward notification ID, parse entity ID from payload, cancel delivered notifications on Snooze/Dismiss, and allow cold-start actions before restoreSessionIfActive deletes completed snapshots.
  // static void onNotificationTapped(NotificationResponse response) {
  //   unawaited(
  //     handlePayload(response.payload, actionId: response.actionId),
  //   );
  // }
  //
  // static Future<void> handlePayload(
  //   String? payload, {
  //   String? actionId,
  // }) async {
  //   if (payload == null) return;
  //
  //   if (actionId == snooze5mActionId) {
  //     if (payload.startsWith('activity')) {
  //       final active = await ActivitySessionService().snoozeActiveOrRestored(
  //         const Duration(minutes: 5),
  //       );
  //       if (active != null) {
  //         _surfaceMainNavigationWithFloater();
  //       }
  //       return;
  //     } else if (payload.startsWith('interval')) {
  //       final active = await IntervalSessionService().snoozeActiveOrRestored(
  //         const Duration(minutes: 5),
  //       );
  //       if (active != null) {
  //         _surfaceMainNavigationWithFloater();
  //       }
  //       return;
  //     }
  //   }
  //
  //   if (actionId == dismissActionId) {
  //     if (payload.startsWith('activity')) {
  //       ActivitySessionService().clear();
  //       return;
  //     } else if (payload.startsWith('interval')) {
  //       IntervalSessionService().clear();
  //       return;
  //     } else if (payload.startsWith('brew')) {
  //       BrewSessionService().clear();
  //       return;
  //     }
  //   }
  //
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
      handlePayload(
        response.payload,
        actionId: response.actionId,
        notificationId: response.id,
      ),
    );
  }

  static Future<void> handlePayload(
    String? payload, {
    String? actionId,
    int? notificationId,
    FlutterLocalNotificationsPlugin? plugin,
  }) async {
    if (payload == null) return;
    final parts = payload.split(':');
    final entityId =
        parts.length > 1 && parts[1].isNotEmpty
            ? parts.sublist(1).join(':')
            : null;
    final p = plugin ?? _defaultPlugin;

    if (actionId == snooze5mActionId) {
      if (notificationId != null) {
        // Gene - Nov, 23, 2026: Await p.cancel inside try/catch so async platform errors cannot escape handlePayload.
        // try {
        //   unawaited(p.cancel(id: notificationId));
        // } catch (_) {}
        try {
          await p.cancel(id: notificationId);
        } catch (_) {}
      }
      if (payload.startsWith('activity')) {
        final active = await ActivitySessionService().snoozeActiveOrRestored(
          const Duration(minutes: 5),
          sequenceId: entityId,
        );
        if (active != null) {
          _surfaceMainNavigationWithFloater();
        }
        return;
      } else if (payload.startsWith('interval')) {
        final active = await IntervalSessionService().snoozeActiveOrRestored(
          const Duration(minutes: 5),
          timerId: entityId,
        );
        if (active != null) {
          _surfaceMainNavigationWithFloater();
        }
        return;
      }
    }

    if (actionId == dismissActionId) {
      if (notificationId != null) {
        // Gene - Nov, 23, 2026: Await p.cancel inside try/catch so async platform errors cannot escape handlePayload.
        // try {
        //   unawaited(p.cancel(id: notificationId));
        // } catch (_) {}
        try {
          await p.cancel(id: notificationId);
        } catch (_) {}
      }
      if (payload.startsWith('activity')) {
        ActivitySessionService().clear();
        return;
      } else if (payload.startsWith('interval')) {
        IntervalSessionService().clear(timerId: entityId);
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

  // Gene - Nov, 22, 2026: Split cold-start plugin initialization from launch action handling so main() can process Snooze 5m / Dismiss before restoreSessionIfActive deletes completed sessions.
  static Future<NotificationAppLaunchDetails?> initializeAndGetLaunchDetails({
    FlutterLocalNotificationsPlugin? plugin,
  }) async {
    final scheduler = LocalNotificationAlarmScheduler(plugin: plugin);
    await scheduler._init();
    final p = plugin ?? scheduler._plugin;
    return p.getNotificationAppLaunchDetails();
  }

  static Future<bool> handleLaunchDetailsBeforeRestore(
    NotificationAppLaunchDetails? details, {
    FlutterLocalNotificationsPlugin? plugin,
  }) async {
    if (!(details?.didNotificationLaunchApp ?? false)) {
      return false;
    }
    final response = details?.notificationResponse;
    final payload = response?.payload;
    final actionId = response?.actionId;
    if (payload == null) {
      return false;
    }
    if (actionId == snooze5mActionId || actionId == dismissActionId) {
      await handlePayload(
        payload,
        actionId: actionId,
        notificationId: response?.id,
        plugin: plugin,
      );
      return true;
    }
    return false;
  }

  static Future<void> initializeAndCheckLaunch({
    FlutterLocalNotificationsPlugin? plugin,
  }) async {
    final details = await initializeAndGetLaunchDetails(plugin: plugin);
    if (details?.didNotificationLaunchApp ?? false) {
      final response = details?.notificationResponse;
      final payload = response?.payload;
      final actionId = response?.actionId;
      final notificationId = response?.id;
      if (payload != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          unawaited(
            handlePayload(
              payload,
              actionId: actionId,
              notificationId: notificationId,
              plugin: plugin,
            ),
          );
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
  // Gene - Nov, 14, 2026: Register Darwin notification categories for activity/interval (Snooze 5m + Dismiss) and brew (Dismiss only).
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
  //   await _cleanupLegacyAndroidChannels();
  //   await _installDarwinSounds();
  //   _initialized = true;
  // }
  // Gene - Nov, 22, 2026: Configure local timezone, use monochrome ic_stat_timer icon, clean up legacy v1/v2 channels, proactively create v3 Android channels, deduplicate ensurePermission, defer Android alarms while foregrounded, respect Sound/Vibration settings, add lockscreen visibility & cancelNotification on Snooze 5m.
  // Future<void> _init() async {
  //   if (_initialized) {
  //     return;
  //   }
  //   tz_data.initializeTimeZones();
  //   await _plugin.initialize(
  //     settings: InitializationSettings(
  //       android: const AndroidInitializationSettings('@mipmap/launcher_icon'),
  //       // Permission is requested explicitly in ensurePermission() so the
  //       // prompt lands when the user starts a timer, not at cold start.
  //       iOS: DarwinInitializationSettings(
  //         requestAlertPermission: false,
  //         requestBadgePermission: false,
  //         requestSoundPermission: false,
  //         notificationCategories: <DarwinNotificationCategory>[
  //           DarwinNotificationCategory(
  //             alarmCategoryId,
  //             actions: <DarwinNotificationAction>[
  //               DarwinNotificationAction.plain(
  //                 snooze5mActionId,
  //                 'Snooze 5m',
  //                 options: <DarwinNotificationActionOption>{
  //                   DarwinNotificationActionOption.foreground,
  //                 },
  //               ),
  //               // Gene - Nov, 15, 2026: Ensure iOS Dismiss action wakes the foreground notification response handler reliably.
  //               // DarwinNotificationAction.plain(
  //               //   dismissActionId,
  //               //   'Dismiss',
  //               //   options: <DarwinNotificationActionOption>{
  //               //     DarwinNotificationActionOption.destructive,
  //               //   },
  //               // ),
  //               DarwinNotificationAction.plain(
  //                 dismissActionId,
  //                 'Dismiss',
  //                 options: <DarwinNotificationActionOption>{
  //                   DarwinNotificationActionOption.destructive,
  //                   DarwinNotificationActionOption.foreground,
  //                 },
  //               ),
  //             ],
  //           ),
  //           DarwinNotificationCategory(
  //             brewCategoryId,
  //             actions: <DarwinNotificationAction>[
  //               // Gene - Nov, 15, 2026: Ensure iOS Brew Dismiss action wakes the foreground notification response handler reliably.
  //               // DarwinNotificationAction.plain(
  //               //   dismissActionId,
  //               //   'Dismiss',
  //               //   options: <DarwinNotificationActionOption>{
  //               //     DarwinNotificationActionOption.destructive,
  //               //   },
  //               // ),
  //               DarwinNotificationAction.plain(
  //                 dismissActionId,
  //                 'Dismiss',
  //                 options: <DarwinNotificationActionOption>{
  //                   DarwinNotificationActionOption.destructive,
  //                   DarwinNotificationActionOption.foreground,
  //                 },
  //               ),
  //             ],
  //           ),
  //         ],
  //       ),
  //     ),
  //     onDidReceiveNotificationResponse: onNotificationTapped,
  //   );
  //   await _cleanupLegacyAndroidChannels();
  //   await _installDarwinSounds();
  //   _initialized = true;
  // }
  Future<void> _init() async {
    if (_initialized) {
      return;
    }
    tz_data.initializeTimeZones();
    await _configureLocalTimeZone();
    await _plugin.initialize(
      settings: InitializationSettings(
        android: const AndroidInitializationSettings('ic_stat_timer'),
        // Permission is requested explicitly in ensurePermission() so the
        // prompt lands when the user starts a timer, not at cold start.
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
          notificationCategories: <DarwinNotificationCategory>[
            DarwinNotificationCategory(
              alarmCategoryId,
              actions: <DarwinNotificationAction>[
                DarwinNotificationAction.plain(
                  snooze5mActionId,
                  'Snooze 5m',
                  options: <DarwinNotificationActionOption>{
                    DarwinNotificationActionOption.foreground,
                  },
                ),
                DarwinNotificationAction.plain(
                  dismissActionId,
                  'Dismiss',
                  options: <DarwinNotificationActionOption>{
                    DarwinNotificationActionOption.destructive,
                    DarwinNotificationActionOption.foreground,
                  },
                ),
              ],
            ),
            DarwinNotificationCategory(
              brewCategoryId,
              actions: <DarwinNotificationAction>[
                DarwinNotificationAction.plain(
                  dismissActionId,
                  'Dismiss',
                  options: <DarwinNotificationActionOption>{
                    DarwinNotificationActionOption.destructive,
                    DarwinNotificationActionOption.foreground,
                  },
                ),
              ],
            ),
          ],
        ),
      ),
      onDidReceiveNotificationResponse: onNotificationTapped,
    );
    await _cleanupLegacyAndroidChannels();
    await _createAndroidChannels();
    await _installDarwinSounds();
    _initialized = true;
  }

  Future<void> _configureLocalTimeZone() async {
    try {
      final tzName = await _platformChannel.invokeMethod<String>(
        'getLocalTimezone',
      );
      if (tzName != null && tzName.isNotEmpty) {
        tz.setLocalLocation(tz.getLocation(tzName));
      }
    } catch (_) {
      // Falls back safely to timezone database default in unit tests or unsupported hosts.
    }
  }

  // Gene - Nov, 22, 2026: Delete legacy v1 & broken v2 channels, and proactively register v3 channels with proper sounds & vibration.
  // Future<void> _cleanupLegacyAndroidChannels() async {
  //   try {
  //     final android =
  //         _plugin
  //             .resolvePlatformSpecificImplementation<
  //               AndroidFlutterLocalNotificationsPlugin
  //             >();
  //     if (android == null) {
  //       return;
  //     }
  //     await android.deleteNotificationChannel(channelId: channelId);
  //     await android.deleteNotificationChannel(channelId: '${channelId}_complete');
  //     for (final sound in AlarmSound.values) {
  //       await android.deleteNotificationChannel(
  //         channelId: '${channelId}_${sound.name}',
  //       );
  //     }
  //   } catch (_) {}
  // }
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
      for (final prefix in const <String>[channelId, channelIdV2]) {
        await android.deleteNotificationChannel(channelId: prefix);
        await android.deleteNotificationChannel(channelId: '${prefix}_complete');
        for (final sound in AlarmSound.values) {
          await android.deleteNotificationChannel(
            channelId: '${prefix}_${sound.name}',
          );
        }
      }
    } catch (_) {}
  }

  Future<void> _createAndroidChannels() async {
    try {
      final android =
          _plugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >();
      if (android == null) {
        return;
      }
      for (final enableVibration in const <bool>[true, false]) {
        for (final sound in AlarmSound.values) {
          await android.createNotificationChannel(
            AndroidNotificationChannel(
              channelIdFor(
                sound,
                isCompletion: false,
                playSound: true,
                enableVibration: enableVibration,
              ),
              _channelNameFor(
                sound,
                isCompletion: false,
                playSound: true,
                enableVibration: enableVibration,
              ),
              description: channelDescription,
              importance: Importance.max,
              playSound: true,
              enableVibration: enableVibration,
              audioAttributesUsage: AudioAttributesUsage.alarm,
              sound: RawResourceAndroidNotificationSound(
                _rawResourceFor(sound.fileName),
              ),
            ),
          );
        }
        await android.createNotificationChannel(
          AndroidNotificationChannel(
            channelIdFor(
              null,
              isCompletion: true,
              playSound: true,
              enableVibration: enableVibration,
            ),
            _channelNameFor(
              null,
              isCompletion: true,
              playSound: true,
              enableVibration: enableVibration,
            ),
            description: channelDescription,
            importance: Importance.max,
            playSound: true,
            enableVibration: enableVibration,
            audioAttributesUsage: AudioAttributesUsage.alarm,
            sound: RawResourceAndroidNotificationSound(
              _rawResourceFor(AudioCuePlayer.completionSound),
            ),
          ),
        );
        await android.createNotificationChannel(
          AndroidNotificationChannel(
            channelIdFor(
              null,
              isCompletion: false,
              playSound: true,
              enableVibration: enableVibration,
            ),
            _channelNameFor(
              null,
              isCompletion: false,
              playSound: true,
              enableVibration: enableVibration,
            ),
            description: channelDescription,
            importance: Importance.max,
            playSound: true,
            enableVibration: enableVibration,
            audioAttributesUsage: AudioAttributesUsage.alarm,
          ),
        );
      }
      await android.createNotificationChannel(
        AndroidNotificationChannel(
          channelIdFor(
            null,
            isCompletion: false,
            playSound: false,
            enableVibration: true,
          ),
          _channelNameFor(
            null,
            isCompletion: false,
            playSound: false,
            enableVibration: true,
          ),
          description: channelDescription,
          importance: Importance.high,
          playSound: false,
          enableVibration: true,
        ),
      );
      await android.createNotificationChannel(
        AndroidNotificationChannel(
          channelIdFor(
            null,
            isCompletion: false,
            playSound: false,
            enableVibration: false,
          ),
          _channelNameFor(
            null,
            isCompletion: false,
            playSound: false,
            enableVibration: false,
          ),
          description: channelDescription,
          importance: Importance.defaultImportance,
          playSound: false,
          enableVibration: false,
        ),
      );
    } catch (_) {}
  }

  // Gene - Nov, 22, 2026: Deduplicate concurrent ensurePermission requests and check existing granted status before re-prompting.
  // @override
  // Future<bool> ensurePermission() async {
  //   try {
  //     await _init();
  //     final android =
  //         _plugin
  //             .resolvePlatformSpecificImplementation<
  //               AndroidFlutterLocalNotificationsPlugin
  //             >();
  //     if (android != null) {
  //       final granted = await android.requestNotificationsPermission();
  //       return granted ?? false;
  //     }
  //     final ios =
  //         _plugin
  //             .resolvePlatformSpecificImplementation<
  //               IOSFlutterLocalNotificationsPlugin
  //             >();
  //     if (ios != null) {
  //       final granted = await ios.requestPermissions(alert: true, sound: true);
  //       return granted ?? false;
  //     }
  //     return false;
  //   } catch (_) {
  //     // No notifications is a degraded mode, never a crash.
  //     return false;
  //   }
  // }
  @override
  Future<bool> ensurePermission() {
    final inFlight = _state.permissionRequestInFlight;
    if (inFlight != null) {
      return inFlight;
    }
    final request = _performEnsurePermission();
    _state.permissionRequestInFlight = request;
    return request.whenComplete(() {
      if (identical(_state.permissionRequestInFlight, request)) {
        _state.permissionRequestInFlight = null;
      }
    });
  }

  Future<bool> _performEnsurePermission() async {
    try {
      await _init();
      final android =
          _plugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >();
      if (android != null) {
        bool? alreadyEnabled;
        try {
          alreadyEnabled = await android.areNotificationsEnabled();
        } catch (_) {}
        if (alreadyEnabled == true) {
          _state.permissionGranted = true;
          return true;
        }
        if (alreadyEnabled == null && _state.permissionGranted) {
          return true;
        }
        final granted = await android.requestNotificationsPermission() ?? false;
        _state.permissionGranted = granted;
        return granted;
      }
      final ios =
          _plugin
              .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin
              >();
      if (ios != null) {
        NotificationsEnabledOptions? existing;
        try {
          existing = await ios.checkPermissions();
        } catch (_) {}
        if (existing != null &&
            (existing.isEnabled || existing.isProvisionalEnabled)) {
          _state.permissionGranted = true;
          return true;
        }
        if (existing == null && _state.permissionGranted) {
          return true;
        }
        final granted =
            await ios.requestPermissions(alert: true, sound: true) ?? false;
        _state.permissionGranted = granted;
        return granted;
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
  // Gene - Nov, 15, 2026: Cap queued alarms to maxPendingPerSession, upsert before pruning stale IDs, normalize sub-second trigger timestamps, and fall back to inexactAllowWhileIdle if Android exact alarms are denied.
  // @override
  // Future<void> schedule(List<ScheduledAlarm> alarms) => _serialize(() async {
  //   try {
  //     await _init();
  //     await _cancelUnfiredPending();
  //
  //     final now = _clock();
  //     for (final alarm in alarms) {
  //       if (!alarm.at.isAfter(now)) {
  //         continue; // Already elapsed: the in-app cue covered it.
  //       }
  //       if (alarm.id < 0 || alarm.id >= idSpaceSize) {
  //         continue; // Outside this scheduler's block: never another's alarm.
  //       }
  //       final notificationId = idBase + alarm.id;
  //       await _plugin.zonedSchedule(
  //         id: notificationId,
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
  //       _pending[notificationId] = alarm.at;
  //     }
  //   } catch (_) {
  //     // Scheduling is best-effort; the in-app cue still fires.
  //   }
  // });
  // Gene - Nov, 22, 2026: Defer Android OS scheduling while active in foreground (CuePlayer handles foreground cues) and flush cached alarms immediately upon entering background.
  @override
  Future<void> schedule(List<ScheduledAlarm> alarms) => _serialize(() async {
    try {
      await _init();
      _state.clockByBlock[idBase] = _clock;
      _state.deferredAlarmsByBlock[idBase] = List<ScheduledAlarm>.from(alarms);
      if (defaultTargetPlatform == TargetPlatform.android &&
          _state.appInForeground) {
        await _cancelUnfiredPending();
        return;
      }
      await _scheduleAlarmsLocked(alarms);
    } catch (_) {
      // Scheduling is best-effort; the in-app cue still fires.
    }
  });

  Future<void> _scheduleAlarmsLocked(List<ScheduledAlarm> alarms) async {
    final now = _clock();
    final eligible = <ScheduledAlarm>[
      for (final alarm in alarms)
        if (alarm.at.isAfter(now) &&
            alarm.id >= 0 &&
            alarm.id < idSpaceSize)
          alarm,
    ];
    eligible.sort((a, b) => a.at.compareTo(b.at));
    final window = eligible.take(maxPendingPerSession).toList();

    var scheduleMode = await _resolveAndroidScheduleMode();
    final scheduledIds = <int>{};

    for (final alarm in window) {
      final notificationId = idBase + alarm.id;
      final fireAt = _normalizeTriggerTime(alarm.at, now);
      final payload =
          alarm.payload ??
          (idBase == activityIdBase
              ? 'activity'
              : (idBase == intervalIdBase ? 'interval' : 'brew'));
      final details = _detailsFor(alarm);

      try {
        await _plugin.zonedSchedule(
          id: notificationId,
          title: alarm.title,
          body: alarm.body,
          scheduledDate: tz.TZDateTime.from(fireAt, tz.local),
          notificationDetails: details,
          androidScheduleMode: scheduleMode,
          payload: payload,
        );
        scheduledIds.add(notificationId);
        _pending[notificationId] = fireAt;
      } on PlatformException catch (_) {
        if (scheduleMode != AndroidScheduleMode.inexactAllowWhileIdle) {
          scheduleMode = AndroidScheduleMode.inexactAllowWhileIdle;
          try {
            await _plugin.zonedSchedule(
              id: notificationId,
              title: alarm.title,
              body: alarm.body,
              scheduledDate: tz.TZDateTime.from(fireAt, tz.local),
              notificationDetails: details,
              androidScheduleMode: scheduleMode,
              payload: payload,
            );
            scheduledIds.add(notificationId);
            _pending[notificationId] = fireAt;
          } catch (_) {
            // Best-effort per alarm; keep scheduling remaining alarms.
          }
        }
      } catch (_) {
        // Best-effort per alarm; keep scheduling remaining alarms.
      }
    }

    await _cancelUnfiredPending(keepIds: scheduledIds);
  }

  Future<AndroidScheduleMode> _resolveAndroidScheduleMode() async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return AndroidScheduleMode.exactAllowWhileIdle;
    }
    try {
      final android =
          _plugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >();
      final canExact = await android?.canScheduleExactNotifications();
      if (canExact == false) {
        return AndroidScheduleMode.inexactAllowWhileIdle;
      }
    } catch (_) {
      // Fall back to exact and recover per-call if the OS rejects it.
    }
    return AndroidScheduleMode.exactAllowWhileIdle;
  }

  static DateTime _truncateToSecond(DateTime value) =>
      value.isUtc
          ? DateTime.utc(
            value.year,
            value.month,
            value.day,
            value.hour,
            value.minute,
            value.second,
          )
          : DateTime(
            value.year,
            value.month,
            value.day,
            value.hour,
            value.minute,
            value.second,
          );

  /// Rounds sub-second triggers up to the next whole second so platforms using
  /// second-granularity triggers (e.g. iOS UNCalendarNotificationTrigger) never
  /// truncate a near-future deadline into the past.
  static DateTime _normalizeTriggerTime(DateTime target, DateTime now) {
    final hasSubSecond = target.millisecond > 0 || target.microsecond > 0;
    var normalized = _truncateToSecond(target);
    if (hasSubSecond) {
      normalized = normalized.add(const Duration(seconds: 1));
    }
    final comparableNow = target.isUtc ? now.toUtc() : now.toLocal();
    final nextWholeSecond = _truncateToSecond(
      comparableNow,
    ).add(const Duration(seconds: 1));
    if (normalized.isBefore(nextWholeSecond)) {
      normalized = nextWholeSecond;
    }
    return normalized;
  }

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
  // Gene - Nov, 14, 2026: Omit Snooze 5m on brew notifications (which lack snooze handling) and attach Darwin categoryIdentifier on iOS.
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
  //       playSound: true,
  //       enableVibration: true,
  //       channelAction: AndroidNotificationChannelAction.update,
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
  //       // Gene - Nov, 8, 2026: Attach Snooze 5m and Dismiss action buttons to alarm notifications.
  //       actions: const <AndroidNotificationAction>[
  //         AndroidNotificationAction(
  //           snooze5mActionId,
  //           'Snooze 5m',
  //           showsUserInterface: true,
  //         ),
  //         AndroidNotificationAction(
  //           dismissActionId,
  //           'Dismiss',
  //           cancelNotification: true,
  //           showsUserInterface: true,
  //         ),
  //       ],
  //     ),
  //     iOS: DarwinNotificationDetails(
  //       presentAlert: true,
  //       presentBanner: true,
  //       presentList: true,
  //       presentSound: true,
  //       interruptionLevel: InterruptionLevel.timeSensitive,
  //       sound: fileName,
  //     ),
  //   );
  // }
  // Gene - Nov, 22, 2026: Respect AppSettings sound/vibration preferences, use AndroidNotificationChannelAction.createIfNotExists, set NotificationVisibility.public on lock screen, and cancel notification on Snooze 5m.
  // NotificationDetails _detailsFor(ScheduledAlarm alarm) {
  //   final fileName =
  //       alarm.isCompletion
  //           ? AudioCuePlayer.completionSound
  //           : alarm.sound?.fileName;
  //   final isBrew =
  //       idBase == brewIdBase || (alarm.payload?.startsWith('brew') ?? false);
  //
  //   return NotificationDetails(
  //     android: AndroidNotificationDetails(
  //       channelIdFor(alarm.sound, isCompletion: alarm.isCompletion),
  //       channelName,
  //       channelDescription: channelDescription,
  //       importance: Importance.max,
  //       priority: Priority.high,
  //       playSound: true,
  //       enableVibration: true,
  //       channelAction: AndroidNotificationChannelAction.update,
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
  //       // Gene - Nov, 8, 2026: Attach Snooze 5m and Dismiss action buttons to alarm notifications.
  //       actions: <AndroidNotificationAction>[
  //         if (!isBrew)
  //           const AndroidNotificationAction(
  //             snooze5mActionId,
  //             'Snooze 5m',
  //             showsUserInterface: true,
  //           ),
  //         const AndroidNotificationAction(
  //           dismissActionId,
  //           'Dismiss',
  //           cancelNotification: true,
  //           showsUserInterface: true,
  //         ),
  //       ],
  //     ),
  //     iOS: DarwinNotificationDetails(
  //       presentAlert: true,
  //       presentBanner: true,
  //       presentList: true,
  //       presentSound: true,
  //       interruptionLevel: InterruptionLevel.timeSensitive,
  //       categoryIdentifier: isBrew ? brewCategoryId : alarmCategoryId,
  //       sound: fileName,
  //     ),
  //   );
  // }
  NotificationDetails _detailsFor(ScheduledAlarm alarm) {
    final fileName =
        alarm.isCompletion
            ? AudioCuePlayer.completionSound
            : alarm.sound?.fileName;
    final isBrew =
        idBase == brewIdBase || (alarm.payload?.startsWith('brew') ?? false);
    final settings = AppSettings();
    final soundEnabled = settings.soundEnabled;
    final vibrationEnabled = settings.vibrationEnabled;
    final silent = !soundEnabled && !vibrationEnabled;

    return NotificationDetails(
      android: AndroidNotificationDetails(
        channelIdFor(
          alarm.sound,
          isCompletion: alarm.isCompletion,
          playSound: soundEnabled,
          enableVibration: vibrationEnabled,
        ),
        _channelNameFor(
          alarm.sound,
          isCompletion: alarm.isCompletion,
          playSound: soundEnabled,
          enableVibration: vibrationEnabled,
        ),
        channelDescription: channelDescription,
        importance:
            soundEnabled
                ? Importance.max
                : (vibrationEnabled
                    ? Importance.high
                    : Importance.defaultImportance),
        priority: silent ? Priority.defaultPriority : Priority.high,
        playSound: soundEnabled,
        enableVibration: vibrationEnabled,
        silent: silent,
        channelAction: AndroidNotificationChannelAction.createIfNotExists,
        visibility: NotificationVisibility.public,
        // An alarm should read as an alarm on the lock screen.
        category: AndroidNotificationCategory.alarm,
        fullScreenIntent: true,
        audioAttributesUsage: AudioAttributesUsage.alarm,
        sound:
            soundEnabled && fileName != null
                ? RawResourceAndroidNotificationSound(_rawResourceFor(fileName))
                : null,
        actions: <AndroidNotificationAction>[
          if (!isBrew)
            const AndroidNotificationAction(
              snooze5mActionId,
              'Snooze 5m',
              cancelNotification: true,
              showsUserInterface: true,
            ),
          const AndroidNotificationAction(
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
        presentSound: soundEnabled,
        interruptionLevel: InterruptionLevel.timeSensitive,
        categoryIdentifier: isBrew ? brewCategoryId : alarmCategoryId,
        sound: soundEnabled ? fileName : null,
      ),
    );
  }

  // Gene - Nov, 22, 2026: Also clear deferred foreground alarm cache on cancelAll so cancelled sessions never flush later.
  // @override
  // Future<void> cancelAll() => _serialize(() async {
  //   try {
  //     await _init();
  //     await _cancelUnfiredPending();
  //   } catch (_) {}
  // });
  @override
  Future<void> cancelAll() => _serialize(() async {
    try {
      _state.deferredAlarmsByBlock.remove(idBase);
      await _init();
      await _cancelUnfiredPending();
    } catch (_) {}
  });

  // Gene - Nov, 15, 2026: Preserved original _cancelUnfiredPending without keepIds pruning support.
  // Future<void> _cancelUnfiredPending() async {
  //   final now = _clock();
  //   // Notifications outlive the process, so a session killed mid-run
  //   // leaves alarms this in-memory map knows nothing about. Sweep all
  //   // unfired pending requests in the owned block, plus any in-memory IDs
  //   // whose scheduled fire time is still in the future. Do NOT cancel IDs
  //   // whose fire time has already arrived, because _plugin.cancel(id) also
  //   // dismisses delivered notifications and cuts off their sound mid-playback.
  //   final ids = <int>{
  //     for (final entry in _pending.entries)
  //       if (entry.value.isAfter(now)) entry.key,
  //   };
  //   for (final request in await _plugin.pendingNotificationRequests()) {
  //     if (request.id >= idBase && request.id < idBase + idSpaceSize) {
  //       ids.add(request.id);
  //     }
  //   }
  //   for (final id in ids) {
  //     await _plugin.cancel(id: id);
  //   }
  //   _pending.clear();
  // }
  Future<void> _cancelUnfiredPending({
    Set<int> keepIds = const <int>{},
  }) async {
    final now = _clock();
    // Notifications outlive the process, so a session killed mid-run
    // leaves alarms this in-memory map knows nothing about. Sweep all
    // unfired pending requests in the owned block not in [keepIds], plus any
    // in-memory IDs whose scheduled fire time is still in the future and not
    // in [keepIds]. Do NOT cancel IDs whose fire time has already arrived,
    // because _plugin.cancel(id) also dismisses delivered notifications and
    // cuts off their sound mid-playback.
    final ids = <int>{
      for (final entry in _pending.entries)
        if (entry.value.isAfter(now) && !keepIds.contains(entry.key))
          entry.key,
    };
    for (final request in await _plugin.pendingNotificationRequests()) {
      if (request.id >= idBase &&
          request.id < idBase + idSpaceSize &&
          !keepIds.contains(request.id)) {
        ids.add(request.id);
      }
    }
    for (final id in ids) {
      await _plugin.cancel(id: id);
      _pending.remove(id);
    }
    _pending.removeWhere(
      (id, fireAt) => !keepIds.contains(id) && !fireAt.isAfter(now),
    );
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
