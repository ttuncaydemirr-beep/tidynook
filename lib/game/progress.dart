// Saved progress. Same JSON shape as the HTML game's save() so a save made on
// web can be read here and the other way round:
//
//   {"lang":"de","level":4,"done":[0,1,2],"sound":true,"styles":{"3":1},
//    "daily":{"last":"2026-11-06","streak":2,"total":5,"days":["2026-11-06"]}}
//
// Schema 3 (1.1) adds, next to those keys: "extraStyles", "adsRemoved",
// "supporter", "bonusDone", "vibration", "reminderOn", "reminderAsked",
// "reviewAsked", "adCounter", "lastAdMs" and "streakSaveDay". Saves without
// them (schema 2, or the web shape without "v") load with the defaults.
//
// The core logic (fromJson / toJson / every method) needs no plugin; only
// load() and save() touch shared_preferences.

import 'dart:async' show unawaited;
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'content.dart';
import 'daily.dart';

/// Languages the game ships with.
const List<String> supportedLanguages = <String>['tr', 'en', 'de', 'ar'];

/// State of the daily box rewards.
class DailyState {
  /// Day ("YYYY-MM-DD") of the last finished daily box, "" if none.
  String last;
  int streak;

  /// Number of daily boxes finished in total.
  int total;

  /// The last (up to) 30 finished days.
  List<String> days;

  DailyState({
    this.last = '',
    this.streak = 0,
    this.total = 0,
    List<String>? days,
  }) : days = days ?? <String>[];

  factory DailyState.fromJson(Object? json) {
    if (json is! Map) {
      return DailyState();
    }
    final rawDays = json['days'];
    return DailyState(
      last: json['last'] is String ? json['last'] as String : '',
      streak: _asInt(json['streak']) ?? 0,
      total: _asInt(json['total']) ?? 0,
      days: rawDays is List
          ? rawDays.whereType<String>().toList()
          : <String>[],
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'last': last,
        'streak': streak,
        'total': total,
        'days': List<String>.of(days),
      };

  void clear() {
    last = '';
    streak = 0;
    total = 0;
    days = <String>[];
  }
}

bool? _asBool(Object? v) => v is bool ? v : null;

int _nonNegative(Object? v) {
  final i = _asInt(v);
  return i == null || i < 0 ? 0 : i;
}

int? _asInt(Object? v) {
  if (v is int) {
    return v;
  }
  if (v is num) {
    return v.toInt();
  }
  return null;
}

class Progress extends ChangeNotifier {
  /// The key used in shared_preferences (and in the web game's localStorage).
  static const String storageKey = 'tidynook-v1';

  /// Where the raw text of an unreadable save is kept before starting fresh.
  static const String corruptKey = 'tidynook-v1-corrupt';

  /// Schema version written as "v" in the saved JSON (files without it are
  /// still read).
  static const int schemaVersion = 3;

  /// null = follow the device (tr if the device language is not one of the four).
  String? lang;
  bool sound;

  /// Last opened level.
  int level;
  Set<int> done;

  /// Level index -> chosen style 0..2 (as stored; see [styleOf]).
  Map<int, int> styles;
  DailyState daily;

  /// Levels whose 3rd style (index 2) is unlocked (bonus boxes, surprise box).
  Set<int> extraStyles;

  /// Cached entitlements, written by billing ([setEntitlements]).
  bool adsRemoved;
  bool supporter;

  /// Finished bonus boxes.
  int bonusDone;

  /// Settings: haptic tick on snap, daily reminder, and whether the reminder
  /// and the in-app review were asked already.
  bool vibration;
  bool reminderOn;
  bool reminderAsked;
  bool reviewAsked;

  /// Boxes completed since the last interstitial.
  int interstitialCounter;

  /// Epoch milliseconds of the last full-screen ad (interstitial or rewarded).
  int lastFullScreenAdMs;

  /// The day ("YYYY-MM-DD") that the last streak save filled in, "" if none.
  /// A save is only possible when the last finished day was really played.
  String streakSaveDay;

  bool _autoSave = false;

  Progress({
    this.lang,
    this.sound = true,
    this.level = 0,
    Set<int>? done,
    Map<int, int>? styles,
    DailyState? daily,
    Set<int>? extraStyles,
    this.adsRemoved = false,
    this.supporter = false,
    this.bonusDone = 0,
    this.vibration = true,
    this.reminderOn = false,
    this.reminderAsked = false,
    this.reviewAsked = false,
    this.interstitialCounter = 0,
    this.lastFullScreenAdMs = 0,
    this.streakSaveDay = '',
  })  : done = done ?? <int>{},
        styles = styles ?? <int, int>{},
        daily = daily ?? DailyState(),
        extraStyles = extraStyles ?? <int>{};

  /// Builds a Progress from a decoded save (the web shape). Unknown or wrongly
  /// typed fields fall back to their defaults.
  factory Progress.fromJson(Map<String, dynamic> json) {
    final p = Progress();
    final lang = json['lang'];
    if (lang is String && supportedLanguages.contains(lang)) {
      p.lang = lang;
    }
    if (json['sound'] is bool) {
      p.sound = json['sound'] as bool;
    }
    final lv = _asInt(json['level']) ?? 0;
    p.level = lv < 0 ? 0 : (lv > levels.length - 1 ? levels.length - 1 : lv);
    final rawDone = json['done'];
    if (rawDone is List) {
      for (final d in rawDone) {
        final i = _asInt(d);
        if (i != null && i >= 0 && i < levels.length) {
          p.done.add(i);
        }
      }
    }
    final rawStyles = json['styles'];
    if (rawStyles is Map) {
      rawStyles.forEach((k, v) {
        final i = k is int ? k : int.tryParse(k.toString());
        final s = _asInt(v);
        if (i != null && s != null && i >= 0 && i < levels.length) {
          p.styles[i] = s < 0 ? 0 : (s > styleCount - 1 ? styleCount - 1 : s);
        }
      });
    }
    p.daily = DailyState.fromJson(json['daily']);
    // schema 3 fields; missing or wrongly typed ones keep their defaults
    final rawExtra = json['extraStyles'];
    if (rawExtra is List) {
      for (final d in rawExtra) {
        final i = _asInt(d);
        if (i != null && i >= 0 && i < levels.length) {
          p.extraStyles.add(i);
        }
      }
    }
    p.adsRemoved = _asBool(json['adsRemoved']) ?? false;
    p.supporter = _asBool(json['supporter']) ?? false;
    p.bonusDone = _nonNegative(json['bonusDone']);
    p.vibration = _asBool(json['vibration']) ?? true;
    p.reminderOn = _asBool(json['reminderOn']) ?? false;
    p.reminderAsked = _asBool(json['reminderAsked']) ?? false;
    p.reviewAsked = _asBool(json['reviewAsked']) ?? false;
    p.interstitialCounter = _nonNegative(json['adCounter']);
    p.lastFullScreenAdMs = _nonNegative(json['lastAdMs']);
    final ssd = json['streakSaveDay'];
    p.streakSaveDay = ssd is String && _dayFormat.hasMatch(ssd) ? ssd : '';
    return p;
  }

  /// Parses a saved JSON string; null or invalid text gives a fresh Progress.
  factory Progress.fromJsonString(String? raw) => parseSaved(raw).progress;

  /// Pure helper behind load(): parses [raw] and, when it is non-empty but
  /// unreadable (not JSON, or not a JSON object), also returns it as
  /// [corruptRaw] so the caller can keep a copy before starting fresh.
  /// null or empty [raw] is a normal first start (corruptRaw is null).
  static ({Progress progress, String? corruptRaw}) parseSaved(String? raw) {
    if (raw == null || raw.isEmpty) {
      return (progress: Progress(), corruptRaw: null);
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return (progress: Progress.fromJson(decoded), corruptRaw: null);
      }
    } catch (_) {
      // fall through to a fresh game, keeping the raw text
    }
    return (progress: Progress(), corruptRaw: raw);
  }

  /// The web save() shape.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'v': schemaVersion,
        'lang': lang,
        'level': level,
        'done': done.toList(),
        'sound': sound,
        'styles': <String, dynamic>{
          for (final e in styles.entries) '${e.key}': e.value,
        },
        'daily': daily.toJson(),
        'extraStyles': (extraStyles.toList()..sort()),
        'adsRemoved': adsRemoved,
        'supporter': supporter,
        'bonusDone': bonusDone,
        'vibration': vibration,
        'reminderOn': reminderOn,
        'reminderAsked': reminderAsked,
        'reviewAsked': reviewAsked,
        'adCounter': interstitialCounter,
        'lastAdMs': lastFullScreenAdMs,
        'streakSaveDay': streakSaveDay,
      };

  /// Loads the saved progress (shared_preferences, key "tidynook-v1"). Never
  /// throws: on any error a fresh Progress is returned. The returned object
  /// saves itself after every change made through its methods.
  static Future<Progress> load() async {
    Progress p;
    try {
      final prefs = await SharedPreferences.getInstance();
      String? raw;
      String? unreadable;
      try {
        raw = prefs.getString(storageKey);
      } catch (_) {
        // stored with a wrong type: keep what is there as the backup
        final v = prefs.get(storageKey);
        unreadable = v?.toString();
      }
      final parsed = parseSaved(raw);
      p = parsed.progress;
      final backup = parsed.corruptRaw ?? unreadable;
      if (backup != null && backup.isNotEmpty) {
        try {
          // keep the first backup; never overwrite an earlier one
          if (!prefs.containsKey(corruptKey)) {
            await prefs.setString(corruptKey, backup);
          }
        } catch (_) {
          // the backup is best effort
        }
      }
    } catch (_) {
      p = Progress();
    }
    p._autoSave = true;
    return p;
  }

  /// Writes the progress to shared_preferences. Never throws.
  Future<void> save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(storageKey, jsonEncode(toJson()));
    } catch (_) {
      // storage is a convenience; the game keeps working without it
    }
  }

  void _changed() {
    if (_autoSave) {
      unawaited(save());
    }
    notifyListeners();
  }

  /// Sets the language (null = follow the device) and saves.
  void setLang(String? value) {
    lang = value != null && supportedLanguages.contains(value) ? value : null;
    _changed();
  }

  /// Turns the sound on or off and saves.
  void setSound(bool value) {
    sound = value;
    _changed();
  }

  /// Remembers the last opened level and saves.
  void setLevel(int value) {
    level = value < 0 ? 0 : (value > levels.length - 1 ? levels.length - 1 : value);
    _changed();
  }

  /// As unlocked() in the HTML: the highest level that may be opened.
  int get unlocked {
    final n = levels.length;
    var u = 0;
    while (u < n - 1 && done.contains(u)) {
      u++;
    }
    var best = u;
    for (final d in done) {
      final v = d + 1 < n - 1 ? d + 1 : n - 1;
      if (v > best) {
        best = v;
      }
    }
    return best;
  }

  /// First level not done, -1 if all are done.
  int get nextOpen {
    for (var i = 0; i < levels.length; i++) {
      if (!done.contains(i)) {
        return i;
      }
    }
    return -1;
  }

  /// Style shown for [level]: 0..2. A stored 3rd style that is no longer
  /// available (for example a refunded Supporter Pack) shows as style 0; it
  /// comes back if the style becomes available again.
  int styleOf(int level) {
    final s = styles[level] ?? 0;
    if (s < 0 || s >= styleCount) {
      return 0;
    }
    return styleAvailable(level, s) ? s : 0;
  }

  /// Chooses style [variant] (0..2) for [level] and saves. Ignored when that
  /// style is not available.
  void setStyle(int level, int variant) {
    if (!styleAvailable(level, variant)) {
      return;
    }
    styles[level] = variant;
    _changed();
  }

  /// Styles 0 and 1 are always available; style 2 when it was unlocked for
  /// [level] ([extraStyles]) or with the Supporter Pack.
  bool styleAvailable(int level, int variant) {
    if (variant == 0 || variant == 1) {
      return true;
    }
    if (variant == 2) {
      return supporter || extraStyles.contains(level);
    }
    return false;
  }

  /// Unlocks the 3rd style of [level]. Returns [level] if it was newly
  /// unlocked, else -1.
  int unlockExtraStyle(int level) {
    if (level < 0 || level >= levels.length || extraStyles.contains(level)) {
      return -1;
    }
    extraStyles.add(level);
    _changed();
    return level;
  }

  /// A done level whose 3rd style is not available yet, chosen by [seed]
  /// (deterministic), or null when there is none.
  int? nextExtraStyleCandidate(int seed) {
    final c = <int>[
      for (final d in done)
        if (!styleAvailable(d, 2)) d,
    ]..sort();
    if (c.isEmpty) {
      return null;
    }
    return c[seed.abs() % c.length];
  }

  /// No interstitials and no banner: Remove ads or the Supporter Pack.
  bool get noAds => adsRemoved || supporter;

  /// Stores the entitlements reported by billing and saves when they changed.
  void setEntitlements({required bool adsRemoved, required bool supporter}) {
    if (this.adsRemoved == adsRemoved && this.supporter == supporter) {
      return;
    }
    this.adsRemoved = adsRemoved;
    this.supporter = supporter;
    _changed();
  }

  /// True when enough levels are done for the bonus boxes.
  bool get bonusUnlocked => done.length >= bonusUnlockLevels;

  /// Counts a finished bonus box. Every [bonusStyleEvery]-th box unlocks the
  /// 3rd style of a done piece ([nextExtraStyleCandidate] with the new count as
  /// seed); returns that level index, or -1 when nothing was unlocked.
  int completeBonus() {
    bonusDone += 1;
    var got = -1;
    if (bonusDone % bonusStyleEvery == 0) {
      final c = nextExtraStyleCandidate(bonusDone);
      if (c != null) {
        extraStyles.add(c);
        got = c;
      }
    }
    _changed();
    return got;
  }

  /// The streak a rewarded streak save would keep, or 0 when no save is
  /// possible. A save is possible when exactly one day was missed (the last
  /// box was finished the day before yesterday), the streak was at least 2
  /// and that last day was really played (not filled in by an earlier save).
  int streakAtRisk(DateTime now) {
    final last = daily.last;
    if (last.isEmpty || daily.streak < 2) {
      return 0;
    }
    final yesterday = _yesterdayString(now);
    if (last != _dayBefore(yesterday)) {
      return 0;
    }
    if (streakSaveDay.isNotEmpty && streakSaveDay == last) {
      return 0;
    }
    return daily.streak;
  }

  /// After a rewarded ad: fills in the missed day (yesterday) so the streak
  /// continues with today's box. The streak value and the box total stay as
  /// they are. Returns false (and changes nothing) when no save is possible.
  bool saveStreak(DateTime now) {
    if (streakAtRisk(now) == 0) {
      return false;
    }
    final yesterday = _yesterdayString(now);
    daily.last = yesterday;
    streakSaveDay = yesterday;
    _changed();
    return true;
  }

  void setVibration(bool value) {
    vibration = value;
    _changed();
  }

  void setReminderOn(bool value) {
    reminderOn = value;
    _changed();
  }

  void setReminderAsked(bool value) {
    reminderAsked = value;
    _changed();
  }

  void setReviewAsked(bool value) {
    reviewAsked = value;
    _changed();
  }

  void setInterstitialCounter(int value) {
    interstitialCounter = value < 0 ? 0 : value;
    _changed();
  }

  void setLastFullScreenAdMs(int value) {
    lastFullScreenAdMs = value < 0 ? 0 : value;
    _changed();
  }

  /// True when every level of [room] is done.
  bool roomComplete(int room) {
    for (var i = 0; i < levelRoom.length; i++) {
      if (levelRoom[i] == room && !done.contains(i)) {
        return false;
      }
    }
    return true;
  }

  /// Marks [level] done. Returns the level index if it was newly earned, else -1.
  int completeLevel(int level) {
    if (level < 0 || level >= levels.length) {
      return -1;
    }
    final fresh = !done.contains(level);
    if (fresh) {
      done.add(level);
    }
    _changed();
    return fresh ? level : -1;
  }

  /// As dailyWin() in the HTML: counts a box (once per day), updates the
  /// streak and returns the pet index (0 cat, 1 fishbowl, 2 garden) newly
  /// earned by this box, else -1.
  ///
  /// [day] ("YYYY-MM-DD") is the day the box was OPENED; when given it is
  /// credited instead of today, so a box opened at 23:59 and finished at 00:01
  /// still counts for the opening day. Returns -1 and changes nothing when that
  /// day is already counted or when the last finished day is AFTER it (clock set
  /// back, or travelling west): the streak is never reset by that.
  int completeDaily(DateTime now, {String? day}) {
    final credited =
        day != null && _dayFormat.hasMatch(day) ? day : dayString(now);
    // "YYYY-MM-DD" strings sort like dates
    if (daily.last.compareTo(credited) >= 0) {
      return -1;
    }
    daily.streak = daily.last == _dayBefore(credited) ? daily.streak + 1 : 1;
    daily.last = credited;
    daily.total += 1;
    final all = <String>[...daily.days, credited];
    daily.days = all.length > 30 ? all.sublist(all.length - 30) : all;
    _changed();
    return milestones.indexOf(daily.total);
  }

  /// True when today's box is counted, or a later day is (clock set back).
  bool dailyDoneToday(DateTime now) => daily.last.compareTo(dayString(now)) >= 0;

  /// Streak that is still alive: a finished box of today, yesterday or a later
  /// day (clock set back, travelling west) keeps it.
  int liveStreak(DateTime now) {
    final last = daily.last;
    if (last.isEmpty) {
      return 0;
    }
    return last.compareTo(_yesterdayString(now)) >= 0 ? daily.streak : 0;
  }

  /// As the settings reset in the HTML: levels, styles and daily rewards start
  /// over (also bonus boxes, unlocked 3rd styles and the streak save); language,
  /// sound, the other settings, purchases and the ad pacing stay.
  void reset() {
    done = <int>{};
    styles = <int, int>{};
    daily = DailyState();
    level = 0;
    extraStyles = <int>{};
    bonusDone = 0;
    streakSaveDay = '';
    _changed();
  }
}

final RegExp _dayFormat = RegExp(r'^\d{4}-\d{2}-\d{2}$');

/// The calendar day before [day] ("YYYY-MM-DD"), by date arithmetic (never by
/// subtracting 24 hours, so DST changes cannot break it).
String _dayBefore(String day) {
  final y = int.parse(day.substring(0, 4));
  final m = int.parse(day.substring(5, 7));
  final d = int.parse(day.substring(8, 10));
  return dayString(DateTime(y, m, d - 1));
}

String _yesterdayString(DateTime now) {
  return dayString(DateTime(now.year, now.month, now.day - 1));
}
