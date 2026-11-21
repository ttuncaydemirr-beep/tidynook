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
// Schema 4 (1.2) adds "tasks" ({"day", "list"}), "chestSteps", "chestDay",
// "chestsOpened", "chestDecors", "winter" ({"season", "done"}), "snowman" and
// "mechanicTipSeen". A schema 3 save loads without loss: every schema 3 key
// keeps its value and the new keys start at their defaults (migration in
// fromJson; nothing is renamed or dropped).
//
// Schema 5 (1.3) adds "winterPack" (cached entitlement of the Winter Cozy
// Pack), "winterGift" and "winterGiftShown" (the free winter gift and whether
// its reveal was shown) and "winterOfferDay" (the last day the pack was
// offered on a card). A schema 4 save loads without loss, the new keys at
// their defaults. Stored styles may now be 3 (the winter style).
//
// The core logic (fromJson / toJson / every method) needs no plugin; only
// load() and save() touch shared_preferences.

import 'dart:async' show unawaited;
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'content.dart';
import 'daily.dart';

/// Free hints per local day (owner decision 2026-11-12); after that the hint
/// button offers an optional rewarded ad for one more ([Progress.grantHint]).
/// Unlimited with Remove ads or the Supporter Pack.
const int freeHintsPerDay = 3;

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
  static const int schemaVersion = 5;

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

  /// Day ("YYYY-MM-DD") of [hintsUsed]; the count starts over on a new day.
  String hintDay;

  /// Free hints used on [hintDay].
  int hintsUsed;

  /// Hints granted by rewarded ads and not used yet (kept across days).
  /// Claimed daily tasks and the task chest add to it too.
  int extraHints;

  // --- schema 4 (1.2) -------------------------------------------------------

  /// Day ("YYYY-MM-DD") of [tasks]; "" before the first tasks were made.
  String taskDay;

  /// The tasks of [taskDay] (see [tasksFor]).
  List<DailyTask> tasks;

  /// Filled steps of the task chest (0..[taskChestSteps]).
  int chestSteps;

  /// The day whose three finished tasks filled the last chest step.
  String chestDay;

  /// Task chests opened so far.
  int chestsOpened;

  /// Chest decor pieces owned (0..chestDecorCount-1).
  Set<int> chestDecors;

  /// Winter season ([winterSeasonOf]) that [winterDone] belongs to, 0 = none.
  int winterSeason;

  /// Winter boxes (0..[winterLevelCount]-1) finished in [winterSeason].
  Set<int> winterDone;

  /// The winter snowman was earned (kept forever, also after a reset).
  bool snowman;

  /// The drawer tip of the 1.2 mechanic was shown once.
  bool mechanicTipSeen;

  // --- schema 5 (1.3) -------------------------------------------------------

  /// Cached entitlement of the Winter Cozy Pack (written by billing through
  /// [setEntitlements]). Kept over a reset, like the other purchases.
  bool winterPack;

  /// The free winter gift (the little fir tree) was earned. Kept forever,
  /// also after a reset.
  bool winterGift;

  /// The reveal of the winter gift was shown ([markWinterGiftShown]).
  bool winterGiftShown;

  /// Day ("YYYY-MM-DD") the Winter Cozy Pack was last offered on a card
  /// ([markWinterPackOffered]), "" if never.
  String winterOfferDay;

  /// The clock used by methods that take no date (completeLevel,
  /// completeBonus, setStyle) to credit today's tasks. Tests replace it.
  DateTime Function() clock = DateTime.now;

  final List<int> _freshTasks = <int>[];
  bool _freshChestStep = false;
  bool _freshWinterGift = false;

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
    this.hintDay = '',
    this.hintsUsed = 0,
    this.extraHints = 0,
    this.taskDay = '',
    List<DailyTask>? tasks,
    this.chestSteps = 0,
    this.chestDay = '',
    this.chestsOpened = 0,
    Set<int>? chestDecors,
    this.winterSeason = 0,
    Set<int>? winterDone,
    this.snowman = false,
    this.mechanicTipSeen = false,
    this.winterPack = false,
    this.winterGift = false,
    this.winterGiftShown = false,
    this.winterOfferDay = '',
  })  : done = done ?? <int>{},
        styles = styles ?? <int, int>{},
        daily = daily ?? DailyState(),
        extraStyles = extraStyles ?? <int>{},
        tasks = tasks ?? <DailyTask>[],
        chestDecors = chestDecors ?? <int>{},
        winterDone = winterDone ?? <int>{};

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
          // 0..3 are kept (3 = winter style, schema 5); anything above
          // falls back to style C as in 1.1 / 1.2
          p.styles[i] = s < 0 ? 0 : (s > winterStyle ? styleCount - 1 : s);
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
    final hd = json['hintDay'];
    p.hintDay = hd is String && _dayFormat.hasMatch(hd) ? hd : '';
    p.hintsUsed = p.hintDay.isEmpty ? 0 : _nonNegative(json['hintsUsed']);
    p.extraHints = _nonNegative(json['extraHints']);
    // schema 4 fields (migration from 3: all absent, so all keep defaults)
    final rawTasks = json['tasks'];
    if (rawTasks is Map) {
      final td = rawTasks['day'];
      final list = rawTasks['list'];
      if (td is String && _dayFormat.hasMatch(td) && list is List) {
        final parsed = <DailyTask?>[
          for (final t in list) DailyTask.fromJson(t),
        ].whereType<DailyTask>().toList();
        if (parsed.length <= tasksPerDay) {
          p.taskDay = td;
          p.tasks = parsed;
        }
      }
    }
    final cs = _nonNegative(json['chestSteps']);
    p.chestSteps = cs > taskChestSteps ? taskChestSteps : cs;
    final cd = json['chestDay'];
    p.chestDay = cd is String && _dayFormat.hasMatch(cd) ? cd : '';
    p.chestsOpened = _nonNegative(json['chestsOpened']);
    final rawDecor = json['chestDecors'];
    if (rawDecor is List) {
      for (final d in rawDecor) {
        final i = _asInt(d);
        if (i != null && i >= 0 && i < chestDecorCount) {
          p.chestDecors.add(i);
        }
      }
    }
    final w = json['winter'];
    if (w is Map) {
      p.winterSeason = _nonNegative(w['season']);
      final wd = w['done'];
      if (p.winterSeason > 0 && wd is List) {
        for (final d in wd) {
          final i = _asInt(d);
          if (i != null && i >= 0 && i < winterLevelCount) {
            p.winterDone.add(i);
          }
        }
      }
    }
    p.snowman = _asBool(json['snowman']) ?? false;
    p.mechanicTipSeen = _asBool(json['mechanicTipSeen']) ?? false;
    // schema 5 fields (migration from 4: all absent, so all keep defaults)
    p.winterPack = _asBool(json['winterPack']) ?? false;
    p.winterGift = _asBool(json['winterGift']) ?? false;
    p.winterGiftShown = p.winterGift && (_asBool(json['winterGiftShown']) ?? false);
    final wo = json['winterOfferDay'];
    p.winterOfferDay = wo is String && _dayFormat.hasMatch(wo) ? wo : '';
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
        'hintDay': hintDay,
        'hintsUsed': hintsUsed,
        'extraHints': extraHints,
        'tasks': <String, dynamic>{
          'day': taskDay,
          'list': <Map<String, dynamic>>[for (final t in tasks) t.toJson()],
        },
        'chestSteps': chestSteps,
        'chestDay': chestDay,
        'chestsOpened': chestsOpened,
        'chestDecors': (chestDecors.toList()..sort()),
        'winter': <String, dynamic>{
          'season': winterSeason,
          'done': (winterDone.toList()..sort()),
        },
        'snowman': snowman,
        'mechanicTipSeen': mechanicTipSeen,
        'winterPack': winterPack,
        'winterGift': winterGift,
        'winterGiftShown': winterGiftShown,
        'winterOfferDay': winterOfferDay,
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

  /// Style shown for [level]: 0..2, or 3 (winter style, Winter Cozy Pack). A
  /// stored style that is no longer available (for example a refunded pack)
  /// shows as style 0; it comes back if the style becomes available again.
  int styleOf(int level) {
    final s = styles[level] ?? 0;
    if (s < 0 || s >= maxStyleCount) {
      return 0;
    }
    return styleAvailable(level, s) ? s : 0;
  }

  /// Chooses style [variant] (0..3) for [level] and saves. Ignored when that
  /// style is not available.
  void setStyle(int level, int variant) {
    if (!styleAvailable(level, variant)) {
      return;
    }
    final changed = styleOf(level) != variant;
    styles[level] = variant;
    if (changed) {
      _taskEvent(TaskType.style, clock());
    }
    _changed();
  }

  /// Styles 0 and 1 are always available; style 2 when it was unlocked for
  /// [level] ([extraStyles]) or with the Supporter Pack; style 3 (winter) for
  /// the pieces in [winterStylePieces] with the Winter Cozy Pack.
  bool styleAvailable(int level, int variant) {
    if (variant == 0 || variant == 1) {
      return true;
    }
    if (variant == 2) {
      return supporter || extraStyles.contains(level);
    }
    if (variant == winterStyle) {
      return winterPack && hasWinterStyle(level);
    }
    return false;
  }

  /// 1.3: number of style tiles the picker of [level] shows: 4 for a piece
  /// with a winter style when the Winter Cozy Pack is owned, else
  /// [styleCount] (3; style 2 may still be locked, as in 1.2).
  int styleCountOf(int level) =>
      winterPack && hasWinterStyle(level) ? maxStyleCount : styleCount;

  /// 1.3: the style indexes the picker of [level] shows, in order
  /// (0, 1, 2 and, with the pack, 3 for a piece with a winter style).
  List<int> styleChoices(int level) =>
      <int>[for (var v = 0; v < styleCountOf(level); v++) v];

  /// 1.3: the next available style of [level] after the current one, cycling
  /// over [styleChoices] (0 -> 1 -> 2 -> 3 -> 0, skipping locked ones). Use it
  /// for the tap-to-change on the house screen instead of looping over
  /// [styleCount].
  int nextStyleOf(int level) {
    final n = styleCountOf(level);
    final cur = styleOf(level);
    for (var k = 1; k <= n; k++) {
      final v = (cur + k) % n;
      if (styleAvailable(level, v)) {
        return v;
      }
    }
    return cur;
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
  ///
  /// 1.3: [winterPack] is the Winter Cozy Pack. Leaving it out (null, what
  /// 1.1 / 1.2 callers do) keeps the stored value, so an older caller can
  /// never take the pack away; billing passes true or false once it knows.
  void setEntitlements({
    required bool adsRemoved,
    required bool supporter,
    bool? winterPack,
  }) {
    final wp = winterPack ?? this.winterPack;
    if (this.adsRemoved == adsRemoved &&
        this.supporter == supporter &&
        this.winterPack == wp) {
      return;
    }
    this.adsRemoved = adsRemoved;
    this.supporter = supporter;
    this.winterPack = wp;
    _changed();
  }

  // ---------------------------------------------------------------------------
  // 1.3: the Winter Cozy Pack and the free winter gift
  // ---------------------------------------------------------------------------

  /// The Winter Cozy Pack is owned (its decor and winter styles show).
  bool get winterPackOwned => winterPack;

  /// The pack may be offered on a card now (the winter event card's "Cozy
  /// Pack" offer, the secondary line on the 7th winter box's win card): not
  /// owned, the winter event runs and it was not offered on a card today.
  /// The shop row in settings does not need this (always shown, "Owned" for
  /// owners). Call [markWinterPackOffered] when such an offer is shown.
  bool canOfferWinterPack(DateTime now) {
    if (winterPack || !winterActive(now)) {
      return false;
    }
    // "YYYY-MM-DD" sorts like dates; a later stored day (clock set back)
    // also counts as offered
    return winterOfferDay.compareTo(dayString(now)) < 0;
  }

  /// Remembers that the pack was offered on a card today (once per day) and
  /// saves. Returns false (and changes nothing) when it was already offered
  /// today.
  bool markWinterPackOffered(DateTime now) {
    final today = dayString(now);
    if (winterOfferDay.compareTo(today) >= 0) {
      return false;
    }
    winterOfferDay = today;
    _changed();
    return true;
  }

  /// The winter gift was earned and its reveal not shown yet: show the reveal
  /// card / toast (winterGiftTitle, winterGiftText, [winterGiftPreviewSvg])
  /// and sparkles at [winterGiftSpot], then call [markWinterGiftShown].
  /// Saved, so a reveal missed by closing the app comes back.
  bool get winterGiftToReveal => winterGift && !winterGiftShown;

  /// Marks the winter gift reveal as shown. True only the first time.
  bool markWinterGiftShown() {
    if (!winterGift || winterGiftShown) {
      return false;
    }
    winterGiftShown = true;
    _changed();
    return true;
  }

  /// True once right after [completeWinter] granted the winter gift (log the
  /// winter_gift_granted event then). Not saved.
  bool takeWinterGiftGranted() {
    final v = _freshWinterGift;
    _freshWinterGift = false;
    return v;
  }

  /// True when enough levels are done for the bonus boxes.
  bool get bonusUnlocked => done.length >= bonusUnlockLevels;

  /// Counts a finished bonus box. Every [bonusStyleEvery]-th box unlocks the
  /// 3rd style of a done piece ([nextExtraStyleCandidate] with the new count as
  /// seed); returns that level index, or -1 when nothing was unlocked.
  int completeBonus() {
    final mystery = bonusIsMystery(bonusDone);
    bonusDone += 1;
    final now = clock();
    _taskEvent(TaskType.boxes, now);
    _taskEvent(TaskType.bonus, now);
    if (mystery) {
      _taskEvent(TaskType.mystery, now);
    }
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

  /// Free hints used today (local day of [now]). A later day starts at 0; a
  /// clock set back keeps the count of the later day.
  int hintsUsedToday(DateTime now) {
    if (hintDay.isEmpty) {
      return 0;
    }
    return dayString(now).compareTo(hintDay) <= 0 ? hintsUsed : 0;
  }

  /// Hints the player can still take today without an ad (free ones left plus
  /// granted ones). -1 means unlimited (Remove ads / Supporter Pack).
  int hintsLeft(DateTime now) {
    if (noAds) {
      return -1;
    }
    final free = freeHintsPerDay - hintsUsedToday(now);
    return (free < 0 ? 0 : free) + extraHints;
  }

  /// Takes one hint: a free one while today's [freeHintsPerDay] last, then a
  /// granted one ([grantHint]). Always true with Remove ads or the Supporter
  /// Pack. Returns false (and changes nothing) when none is left, so the UI
  /// offers the optional rewarded ad.
  bool useFreeHint(DateTime now) {
    final used = hintsUsedToday(now);
    if (noAds || used < freeHintsPerDay) {
      final today = dayString(now);
      if (hintDay.compareTo(today) < 0) {
        hintDay = today;
      }
      hintsUsed = used + 1;
      _taskEvent(TaskType.hint, now);
      _changed();
      return true;
    }
    if (extraHints > 0) {
      extraHints -= 1;
      _taskEvent(TaskType.hint, now);
      _changed();
      return true;
    }
    return false;
  }

  /// After a rewarded ad: one more hint (the next [useFreeHint] takes it).
  void grantHint() {
    extraHints += 1;
    _changed();
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
    final now = clock();
    _taskEvent(TaskType.boxes, now);
    _taskEvent(fresh ? TaskType.newLevel : TaskType.replay, now);
    if (levels[level].mystery) {
      _taskEvent(TaskType.mystery, now);
    }
    if (levels[level].hasDrawers) {
      _taskEvent(TaskType.drawer, now);
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
    _taskEvent(TaskType.boxes, now);
    _taskEvent(TaskType.daily, now);
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
  ///
  /// 1.2: the daily tasks, the task chest (steps and decor) and this season's
  /// winter boxes start over too; the snowman (a seasonal keepsake that cannot
  /// be earned again until next winter) and the mechanic tip flag stay.
  ///
  /// 1.3: the Winter Cozy Pack (a purchase), the winter gift (a keepsake),
  /// its reveal flag and the last offer day stay too.
  void reset() {
    done = <int>{};
    styles = <int, int>{};
    daily = DailyState();
    level = 0;
    extraStyles = <int>{};
    bonusDone = 0;
    streakSaveDay = '';
    taskDay = '';
    tasks = <DailyTask>[];
    chestSteps = 0;
    chestDay = '';
    chestsOpened = 0;
    chestDecors = <int>{};
    winterSeason = 0;
    winterDone = <int>{};
    _freshTasks.clear();
    _freshChestStep = false;
    _freshWinterGift = false;
    _changed();
  }

  // ---------------------------------------------------------------------------
  // 1.2: daily tasks and the task chest
  // ---------------------------------------------------------------------------

  /// What the player can do now, for making the day's tasks.
  TaskContext taskContext(DateTime now) {
    final u = unlocked;
    var mystery = false;
    var drawer = false;
    for (var i = 0; i <= u && i < levels.length; i++) {
      mystery = mystery || levels[i].mystery;
      drawer = drawer || levels[i].hasDrawers;
    }
    return TaskContext(
      hasNewLevel: nextOpen >= 0,
      dailyOpen: !dailyDoneToday(now),
      bonusUnlocked: bonusUnlocked,
      hasDone: done.isNotEmpty,
      mysteryReachable: mystery,
      drawerReachable: drawer,
      winterOpen: winterAvailable(now),
    );
  }

  /// Makes today's tasks when the stored ones are from an earlier day. Kept
  /// as they are when they are from a later day (clock set back). Saves but
  /// does not notify, so it is safe to call while building.
  void _ensureTasks(DateTime now) {
    final today = dayString(now);
    if (taskDay == today || taskDay.compareTo(today) > 0) {
      return;
    }
    // hints of yesterday's finished tasks that were never claimed are not lost
    for (final t in tasks) {
      if (t.done && !t.claimed) {
        t.claimed = true;
        extraHints += taskHintReward;
      }
    }
    taskDay = today;
    tasks = generateDailyTasks(today, taskContext(now));
    _freshTasks.clear();
    if (_autoSave) {
      unawaited(save());
    }
  }

  /// Today's [tasksPerDay] tasks (made on first use each day from the date
  /// and the player's progress at that moment, then fixed for the day).
  /// Read-only view; safe to call in build().
  List<DailyTask> tasksFor(DateTime now) {
    _ensureTasks(now);
    return List<DailyTask>.unmodifiable(tasks);
  }

  /// True when all of today's tasks are finished.
  bool tasksAllDone(DateTime now) {
    final t = tasksFor(now);
    return t.isNotEmpty && t.every((x) => x.done);
  }

  /// Counts one [type] action for today's tasks. A task that gets finished is
  /// reported by [takeCompletedTasks] (its hint waits for [claimTask] or
  /// [doubleTask]); the last of the day's tasks also fills one chest step.
  /// Does not notify (callers do).
  void _taskEvent(TaskType type, DateTime now) {
    _ensureTasks(now);
    if (taskDay != dayString(now)) {
      return; // clock set back: the stored day is not today
    }
    for (var i = 0; i < tasks.length; i++) {
      final t = tasks[i];
      if (t.type != type || t.done) {
        continue;
      }
      t.progress += 1;
      if (t.done) {
        _freshTasks.add(i);
      }
    }
    if (tasks.isNotEmpty &&
        tasks.every((x) => x.done) &&
        chestDay != taskDay) {
      chestDay = taskDay;
      if (chestSteps < taskChestSteps) {
        chestSteps += 1;
        _freshChestStep = true;
      }
    }
  }

  /// Indexes (into [tasksFor]) of the tasks finished since the last call, for
  /// the UI to celebrate (log task_complete, offer "claim" / the `task_double`
  /// ad). Not saved.
  List<int> takeCompletedTasks() {
    final out = List<int>.of(_freshTasks);
    _freshTasks.clear();
    return out;
  }

  /// True once after a chest step was filled (since the last call). Not saved.
  bool takeChestStepEarned() {
    final v = _freshChestStep;
    _freshChestStep = false;
    return v;
  }

  /// Task [i] of today is finished and its hint not given yet.
  bool canClaimTask(int i, DateTime now) {
    final t = tasksFor(now);
    return i >= 0 && i < t.length && t[i].done && !t[i].claimed;
  }

  /// Gives task [i]'s hint ([taskHintReward]). Returns false (and changes
  /// nothing) when the task is not finished or was claimed already.
  bool claimTask(int i, DateTime now) {
    if (!canClaimTask(i, now)) {
      return false;
    }
    tasks[i].claimed = true;
    extraHints += taskHintReward;
    _changed();
    return true;
  }

  /// The optional rewarded doubling can be offered for task [i] of today
  /// (finished and not doubled yet; claimed or not).
  bool canDoubleTask(int i, DateTime now) {
    final t = tasksFor(now);
    return i >= 0 && i < t.length && t[i].done && !t[i].doubled;
  }

  /// After a rewarded ad (placement `task_double`): task [i] gives twice its
  /// hint in total (2 if it was not claimed yet, 1 more if it was).
  /// Returns false (and changes nothing) when it is not possible.
  bool doubleTask(int i, DateTime now) {
    if (!canDoubleTask(i, now)) {
      return false;
    }
    final t = tasks[i];
    extraHints += t.claimed ? taskHintReward : 2 * taskHintReward;
    t.claimed = true;
    t.doubled = true;
    _changed();
    return true;
  }

  /// The task chest is full and can be opened.
  bool get taskChestReady => chestSteps >= taskChestSteps;

  /// Opens a full task chest: the 3rd style of a done piece that does not have
  /// it yet, else the next chest decor piece, else [chestBonusHints] hints.
  /// The chest starts over at 0 steps. null (nothing changes) when not full.
  ChestReward? openTaskChest() {
    if (!taskChestReady) {
      return null;
    }
    ChestReward reward;
    final c = nextExtraStyleCandidate(chestsOpened * 7 + 3);
    if (c != null) {
      extraStyles.add(c);
      reward = ChestReward(ChestRewardKind.style, c);
    } else {
      var d = -1;
      for (var k = 0; k < chestDecorCount; k++) {
        if (!chestDecors.contains(k)) {
          d = k;
          break;
        }
      }
      if (d >= 0) {
        chestDecors.add(d);
        reward = ChestReward(ChestRewardKind.decor, d);
      } else {
        extraHints += chestBonusHints;
        reward = const ChestReward(ChestRewardKind.hints, chestBonusHints);
      }
    }
    chestSteps = 0;
    chestsOpened += 1;
    _changed();
    return reward;
  }

  /// Marks the drawer tip as shown. True only the first time (log the
  /// mechanic_tutorial_seen event then).
  bool markMechanicTipSeen() {
    if (mechanicTipSeen) {
      return false;
    }
    mechanicTipSeen = true;
    _changed();
    return true;
  }

  // ---------------------------------------------------------------------------
  // 1.2: the winter event
  // ---------------------------------------------------------------------------

  /// The winter card can be shown and its boxes played: the event runs and
  /// at least one level is done.
  bool winterAvailable(DateTime now) => winterActive(now) && done.isNotEmpty;

  /// Winter boxes finished in the season of [now] (an earlier season's boxes
  /// do not count; they can be played again next winter).
  Set<int> winterDoneIn(DateTime now) {
    return winterSeason == winterSeasonOf(now)
        ? Set<int>.unmodifiable(winterDone)
        : const <int>{};
  }

  int winterDoneCount(DateTime now) => winterDoneIn(now).length;

  bool winterBoxDone(int i, DateTime now) => winterDoneIn(now).contains(i);

  /// First winter box not finished this season, -1 when all are done.
  int winterNext(DateTime now) {
    final d = winterDoneIn(now);
    for (var i = 0; i < winterLevelCount; i++) {
      if (!d.contains(i)) {
        return i;
      }
    }
    return -1;
  }

  /// Marks winter box [i] finished for the season of [now] (a box opened on
  /// 15 January and finished after midnight still counts for that season).
  /// [fresh]: newly finished this season; [snowman]: the snowman was earned
  /// by this box. Counts for the daily tasks like any box.
  ({bool fresh, bool snowman}) completeWinter(int i, DateTime now) {
    if (i < 0 || i >= winterLevelCount) {
      return (fresh: false, snowman: false);
    }
    final season = winterSeasonOf(now);
    if (winterSeason != season) {
      winterSeason = season;
      winterDone = <int>{};
    }
    final fresh = winterDone.add(i);
    // 1.3: the first finished winter box gives the free winter gift (kept
    // forever); see winterGiftToReveal / takeWinterGiftGranted
    if (!winterGift) {
      winterGift = true;
      winterGiftShown = false;
      _freshWinterGift = true;
    }
    var got = false;
    if (winterDone.length >= winterLevelCount && !snowman) {
      snowman = true;
      got = true;
    }
    _taskEvent(TaskType.boxes, now);
    _taskEvent(TaskType.winter, now);
    _changed();
    return (fresh: fresh, snowman: got);
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
