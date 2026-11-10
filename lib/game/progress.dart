// Saved progress. Same JSON shape as the HTML game's save() so a save made on
// web can be read here and the other way round:
//
//   {"lang":"de","level":4,"done":[0,1,2],"sound":true,"styles":{"3":1},
//    "daily":{"last":"2026-11-06","streak":2,"total":5,"days":["2026-11-06"]}}
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
  static const int schemaVersion = 2;

  /// null = follow the device (tr if the device language is not one of the four).
  String? lang;
  bool sound;

  /// Last opened level.
  int level;
  Set<int> done;

  /// Level index -> 0/1.
  Map<int, int> styles;
  DailyState daily;

  bool _autoSave = false;

  Progress({
    this.lang,
    this.sound = true,
    this.level = 0,
    Set<int>? done,
    Map<int, int>? styles,
    DailyState? daily,
  })  : done = done ?? <int>{},
        styles = styles ?? <int, int>{},
        daily = daily ?? DailyState();

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
        if (i != null && s != null) {
          p.styles[i] = s == 0 ? 0 : 1;
        }
      });
    }
    p.daily = DailyState.fromJson(json['daily']);
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

  int styleOf(int level) => styles[level] ?? 0;

  void setStyle(int level, int variant) {
    styles[level] = variant == 0 ? 0 : 1;
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
  /// over; language and sound stay.
  void reset() {
    done = <int>{};
    styles = <int, int>{};
    daily = DailyState();
    level = 0;
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
