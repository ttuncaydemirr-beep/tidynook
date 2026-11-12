// Optional daily reminder at 19:00 local time (Settings > Daily reminder; asked once after the first
// daily box win). Local notifications only: nothing leaves the device.
//
//  - Schedules one-shot notifications for the next 7 evenings (inexact "allow while idle": NO
//    exact-alarm permission). Today's is skipped when today's daily box is already done or 19:00 has passed.
//  - Call [Reminder.reschedule] on every app start / return to the foreground and after a daily box win,
//    so the 7-day window keeps moving and today's reminder disappears once the box is done.
//  - Each evening is scheduled as an absolute instant computed from the device's local clock
//    (DateTime(y, m, d, 19)), so no time-zone database or extra plugin is needed; rescheduling on each
//    start follows DST and travel.
//  - Android 13+: asks for POST_NOTIFICATIONS in [Reminder.requestAndEnable].
//  - Title and body come in already translated (AppLocalizations notifTitle / notifBody).
// Everything is a no-op on the web, in tests and off Android; nothing throws.
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../monet/env.dart';

const int kReminderHour = 19;
const int kReminderDays = 7;

/// Notification ids used by the reminder (kReminderBaseId .. kReminderBaseId + 7).
const int kReminderBaseId = 7100;

/// The local times the reminder fires at (pure, unit-tested): the next [count] evenings at [hour]:00,
/// starting today, skipping today when [dailyDoneToday] or when that time is not in the future.
List<DateTime> reminderTimes(
  DateTime now, {
  required bool dailyDoneToday,
  int count = kReminderDays,
  int hour = kReminderHour,
}) {
  final out = <DateTime>[];
  for (var d = 0; out.length < count && d <= count; d++) {
    // calendar arithmetic (never "+ 24 h"), so DST changes cannot shift the hour
    final t = DateTime(now.year, now.month, now.day + d, hour);
    if (d == 0 && (dailyDoneToday || !t.isAfter(now))) {
      continue;
    }
    out.add(t);
  }
  return out;
}

class Reminder {
  Reminder({bool? enabled}) : _enabled = enabled ?? MonetEnv.pluginsEnabled;

  final bool _enabled;
  FlutterLocalNotificationsPlugin? _plugin;
  bool _initDone = false;

  static const String _channelId = 'daily_reminder';

  /// Small monochrome icon (android/app/src/main/res/drawable/ic_stat_notify.xml).
  static const String _icon = 'ic_stat_notify';

  static void _log(String m) {
    if (kDebugMode) {
      debugPrint('Reminder: $m');
    }
  }

  Future<FlutterLocalNotificationsPlugin?> _ready() async {
    if (!_enabled) {
      return null;
    }
    final existing = _plugin;
    if (existing != null && _initDone) {
      return existing;
    }
    try {
      final p = existing ?? FlutterLocalNotificationsPlugin();
      _plugin = p;
      await p.initialize(
        settings: const InitializationSettings(android: AndroidInitializationSettings(_icon)),
      );
      _initDone = true;
      return p;
    } catch (e) {
      _log('initialize: $e');
      return null;
    }
  }

  AndroidFlutterLocalNotificationsPlugin? _android(FlutterLocalNotificationsPlugin p) =>
      p.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  /// The player said yes: asks for the notification permission (Android 13+) and schedules.
  /// Returns true when notifications are allowed (the caller then stores reminderOn = true).
  Future<bool> requestAndEnable({
    required String title,
    required String body,
    required bool dailyDoneToday,
    String channelName = 'Daily reminder',
    DateTime? now,
  }) async {
    final p = await _ready();
    if (p == null) {
      return false;
    }
    var allowed = false;
    try {
      final android = _android(p);
      final granted = await android?.requestNotificationsPermission();
      allowed = granted ?? (await android?.areNotificationsEnabled() ?? false);
    } catch (e) {
      _log('permission: $e');
      allowed = false;
    }
    if (!allowed) {
      return false;
    }
    await reschedule(
      enabled: true,
      title: title,
      body: body,
      dailyDoneToday: dailyDoneToday,
      channelName: channelName,
      now: now,
    );
    return true;
  }

  /// Turns the reminder off (cancels everything that is scheduled).
  Future<void> disable() async {
    final p = await _ready();
    if (p == null) {
      return;
    }
    for (var i = 0; i <= kReminderDays; i++) {
      try {
        await p.cancel(id: kReminderBaseId + i);
      } catch (_) {}
    }
  }

  /// Replaces the scheduled reminders. With [enabled] false it only cancels them.
  /// Call at app start, on resume and after a daily box win.
  Future<void> reschedule({
    required bool enabled,
    required String title,
    required String body,
    required bool dailyDoneToday,
    String channelName = 'Daily reminder',
    DateTime? now,
  }) async {
    if (!_enabled) {
      return;
    }
    await disable();
    if (!enabled) {
      return;
    }
    final p = await _ready();
    if (p == null) {
      return;
    }
    try {
      final android = _android(p);
      if (android != null && !(await android.areNotificationsEnabled() ?? true)) {
        return; // the player turned notifications off in system settings
      }
    } catch (_) {}
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        channelName,
        icon: _icon,
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        category: AndroidNotificationCategory.reminder,
      ),
    );
    final times = reminderTimes(now ?? DateTime.now(), dailyDoneToday: dailyDoneToday);
    for (var i = 0; i < times.length; i++) {
      try {
        await p.zonedSchedule(
          id: kReminderBaseId + i,
          title: title,
          body: body,
          scheduledDate: tz.TZDateTime.from(times[i].toUtc(), tz.UTC),
          notificationDetails: details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      } catch (e) {
        _log('zonedSchedule: $e');
      }
    }
  }
}
