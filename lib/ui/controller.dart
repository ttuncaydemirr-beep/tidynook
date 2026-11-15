import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:tidy_nook/game/content.dart';
import 'package:tidy_nook/game/daily.dart';
import 'package:tidy_nook/game/progress.dart';
import 'package:tidy_nook/monet/ad_rules.dart';

import 'clock.dart';
import 'services.dart';
import 'sounds.dart';

enum AppScreen { house, play }

/// What the house screen should celebrate when it opens.
class HouseEvents {
  const HouseEvents({
    this.decor = -1,
    this.pet = -1,
    this.toastRoom = -1,
    this.askReminder = false,
    this.snowman = false,
    this.chestDecor = -1,
    this.tasksDone = 0,
  });
  final int decor;
  final int pet;
  final int toastRoom;

  /// The 7th winter box was just won: the snowman arrives in the garden.
  final bool snowman;

  /// A task chest just gave this chest decor piece (-1 none).
  final int chestDecor;

  /// Daily tasks finished and not announced yet (toast "Task done!").
  final int tasksDone;

  /// The first daily box was just won: ask once about the reminder.
  final bool askReminder;
}

/// Navigation and game flow (build(), goHouse(), start(), win bookkeeping of the HTML).
class GameController extends ChangeNotifier {
  GameController({
    required this.progress,
    required this.sounds,
    AppServices? services,
  })  : services = services ?? AppServices.create(progress),
        _ownsServices = services == null {
    progress.addListener(_onProgress);
  }

  final bool _ownsServices;

  final Progress progress;
  final Sounds sounds;
  final AppServices services;

  AppScreen screen = AppScreen.house;
  bool isDaily = false;

  /// A bonus box is being played ([bonusIndex] = its 0-based number).
  bool isBonus = false;
  int bonusIndex = 0;

  /// A winter event box is being played ([winterIndex] = 0..6).
  bool isWinter = false;
  int winterIndex = 0;
  DateTime _winterOpened = DateTime(2000);

  /// The winter box just won earned the snowman.
  bool freshSnowman = false;

  /// The winter box just won was finished for the first time this season.
  bool winterFresh = false;

  /// Daily tasks finished by the box just won (win card chip).
  int winTasksDone = 0;

  /// Chest decor piece the task chest just gave (house sparkles), else -1.
  int freshChestDecor = -1;

  /// Daily tasks finished since the last announcement.
  int _taskToasts = 0;

  int levelIndex = 0;
  Level? current;
  int dailyTheme = 0;

  /// dayString captured when the daily box was opened (credited on win).
  String? _dailyDay;

  /// Changes whenever a level or the daily box is (re)built: resets the board.
  int playSerial = 0;

  /// Changes whenever the house screen is opened.
  int houseSerial = 0;

  int freshDecor = -1;
  int freshPet = -1;

  /// Level whose 3rd style the bonus box just won unlocked, else -1.
  int freshBonusStyle = -1;

  /// The settings sheet is open (purchase messages are shown inside it then).
  bool settingsOpen = false;

  /// Called after a daily box win (the app reschedules the reminder).
  VoidCallback? onDailyWin;

  bool _askReminder = false;
  bool _justWon = false;
  bool _leaving = false;
  DateTime _startedAt = DateTime.now();

  final math.Random random = math.Random();

  void _onProgress() {
    _collectTasks();
    notifyListeners();
  }

  /// Picks up tasks finished by the last Progress call (any box, a style
  /// change, a hint) and logs them; the UI announces them later.
  void _collectTasks() {
    final fresh = progress.takeCompletedTasks();
    if (fresh.isNotEmpty) {
      _taskToasts += fresh.length;
      final list = progress.tasksFor(appNow());
      for (final i in fresh) {
        if (i < 0 || i >= list.length) {
          continue;
        }
        try {
          services.telemetry.logTaskComplete(list[i].type.name, slot: i);
        } catch (_) {}
      }
    }
    progress.takeChestStepEarned();
  }

  /// Number of finished tasks not announced yet (and forgets them).
  int takeTaskToasts() {
    final n = _taskToasts;
    _taskToasts = 0;
    return n;
  }

  void refresh() => notifyListeners();

  /// As start() in the HTML (no notification: called before the first build).
  void start() {
    unawaited(sounds.preload());
    if (progress.done.isEmpty) {
      _buildLevel(0);
    } else {
      levelIndex = math.min(progress.level, levels.length - 1);
      _openHouse();
    }
  }

  void _began() {
    _startedAt = DateTime.now();
    _justWon = false;
    freshBonusStyle = -1;
    freshSnowman = false;
    winterFresh = false;
    winTasksDone = 0;
  }

  int _seconds() {
    final s = DateTime.now().difference(_startedAt).inSeconds;
    return s < 0 ? 0 : s;
  }

  void _buildLevel(int i) {
    isDaily = false;
    isBonus = false;
    isWinter = false;
    levelIndex = i;
    progress.level = i;
    current = levels[i];
    playSerial++;
    screen = AppScreen.play;
    _began();
    try {
      services.telemetry.logLevelStart(i, mystery: levels[i].mystery);
    } catch (_) {}
    // the drawer tip is the eyebrow of every drawer level; log it once
    if (levels[i].hasDrawers && progress.markMechanicTipSeen()) {
      try {
        services.telemetry.logMechanicTutorialSeen('drawer', level: i);
      } catch (_) {}
    }
  }

  void _openHouse() {
    isDaily = false;
    isBonus = false;
    isWinter = false;
    screen = AppScreen.house;
    houseSerial++;
    if (_justWon) {
      _justWon = false;
      _maybeReview();
    }
  }

  void _maybeReview() {
    try {
      unawaited(services.review
          .maybeAsk(
            alreadyAsked: progress.reviewAsked,
            completedLevels: progress.done.length,
            lastFullScreenAdMs: progress.lastFullScreenAdMs,
            markAsked: () => progress.setReviewAsked(true),
          )
          .catchError((Object _) => false));
    } catch (_) {}
  }

  void buildLevel(int i) {
    _buildLevel(i);
    progress.setLevel(i);
    notifyListeners();
  }

  void startDaily() {
    final now = appNow();
    if (progress.dailyDoneToday(now)) {
      return;
    }
    isDaily = true;
    isBonus = false;
    isWinter = false;
    final day = dayString(now);
    _dailyDay = day;
    final level = dailyLevel(day);
    dailyTheme = level.theme;
    current = level;
    playSerial++;
    screen = AppScreen.play;
    _began();
    services.ads.preload();
    notifyListeners();
  }

  /// Plays the next bonus box (number [Progress.bonusDone]) on the play screen.
  void startBonus() {
    if (!progress.bonusUnlocked) {
      return;
    }
    isDaily = false;
    isBonus = true;
    isWinter = false;
    bonusIndex = progress.bonusDone;
    current = bonusLevel(bonusIndex);
    playSerial++;
    screen = AppScreen.play;
    _began();
    services.ads.preload();
    notifyListeners();
  }

  /// Plays winter box [i] (default: the first one not done this season).
  /// Only while the event runs.
  void startWinter([int? i]) {
    final now = appNow();
    if (!progress.winterAvailable(now)) {
      return;
    }
    var k = i ?? progress.winterNext(now);
    if (k < 0) {
      k = 0; // all done: replay the first one (counts for tasks)
    }
    isDaily = false;
    isBonus = false;
    isWinter = true;
    winterIndex = k.clamp(0, winterLevelCount - 1).toInt();
    _winterOpened = now;
    current = winterLevel(winterIndex);
    playSerial++;
    screen = AppScreen.play;
    _began();
    services.ads.preload();
    notifyListeners();
  }

  /// The winter box after the one just won that is not done yet, else -1.
  int nextWinterBox() {
    final now = appNow();
    if (!progress.winterAvailable(now)) {
      return -1;
    }
    return progress.winterNext(now);
  }

  /// Home button / back: leave the level without announcing a new piece.
  void goHome() {
    freshDecor = -1;
    goHouse();
  }

  void goHouse() {
    _openHouse();
    services.consent.retryPending();
    notifyListeners();
  }

  /// Next level button, "continue" button and the reset.
  void playNext() {
    final nx = progress.nextOpen;
    buildLevel(nx < 0 ? 0 : nx);
  }

  /// The player leaves a win card with Next ([next] true) or See house.
  /// The ONLY place an interstitial may appear: after a regular level or a
  /// bonus box, never after the daily box. Never waits for a load: when no
  /// ad is ready it returns at once and the game continues.
  Future<void> leaveWin({required bool next, bool toBonus = false}) async {
    if (_leaving) {
      return;
    }
    _leaving = true;
    final serial = playSerial;
    final daily = isDaily;
    final bonus = isBonus;
    final winter = isWinter;
    try {
      if (!daily) {
        // bonus and winter boxes count like a box after the 4th level
        await services.ads.maybeInterstitial(
          completedLevelIndex:
              (bonus || winter) ? kBonusBoxLevelIndex : levelIndex,
          isDaily: false,
        );
      }
    } catch (_) {
      // an ad problem never stops the game
    } finally {
      _leaving = false;
    }
    if (serial != playSerial || screen != AppScreen.play) {
      return; // the player already went somewhere else
    }
    if (winter) {
      final nx = nextWinterBox();
      if (next && nx >= 0) {
        startWinter(nx);
      } else {
        goHouse();
      }
    } else if (toBonus && !daily) {
      startBonus();
    } else if (next && bonus) {
      startBonus();
    } else if (next && !daily) {
      playNext();
    } else {
      goHouse();
    }
  }

  /// Bookkeeping when the last item is placed.
  void recordWin() {
    final secs = _seconds();
    _justWon = true;
    final now = appNow();
    if (isWinter) {
      // a box opened on the last event day and finished after midnight still counts
      final at = winterActive(now) ? now : _winterOpened;
      final r = progress.completeWinter(winterIndex, at);
      freshSnowman = r.snowman;
      winterFresh = r.fresh;
      try {
        services.telemetry.logEventBoxComplete(winterIndex,
            seconds: secs, fresh: r.fresh, snowman: r.snowman);
      } catch (_) {}
    } else if (isDaily) {
      final first = progress.daily.total == 0;
      freshPet = progress.completeDaily(now, day: _dailyDay);
      if (first && progress.daily.total > 0 && !progress.reminderAsked) {
        _askReminder = true;
      }
      try {
        services.telemetry.logDaily(
          streak: progress.daily.streak,
          total: progress.daily.total,
          seconds: secs,
        );
      } catch (_) {}
      try {
        onDailyWin?.call();
      } catch (_) {}
    } else if (isBonus) {
      freshBonusStyle = progress.completeBonus();
      try {
        services.telemetry.logBonus(bonusIndex, seconds: secs);
      } catch (_) {}
    } else {
      final r = progress.completeLevel(levelIndex);
      if (r >= 0) {
        freshDecor = r;
      }
      try {
        services.telemetry.logLevelComplete(
          levelIndex,
          seconds: secs,
          first: r >= 0,
          mystery: levels[levelIndex].mystery,
        );
      } catch (_) {}
    }
    winTasksDone = takeTaskToasts();
  }

  /// Consumes the pending celebrations for the house screen.
  HouseEvents takeHouseEvents() {
    var toast = -1;
    if (freshDecor >= 0) {
      final ri = levelRoom[freshDecor];
      if (progress.roomComplete(ri)) {
        toast = ri;
      }
    }
    final ev = HouseEvents(
      decor: freshDecor,
      pet: freshPet,
      toastRoom: toast,
      askReminder: _askReminder && !progress.reminderAsked,
      snowman: freshSnowman,
      chestDecor: freshChestDecor,
      tasksDone: takeTaskToasts(),
    );
    freshDecor = -1;
    freshPet = -1;
    freshSnowman = false;
    freshChestDecor = -1;
    _askReminder = false;
    return ev;
  }

  void toggleSound() {
    progress.setSound(!progress.sound);
    if (progress.sound) {
      sounds.play('pick');
    }
  }

  void setLang(String code) {
    progress.setLang(code);
  }

  void setStyle(int level, int variant) {
    progress.setStyle(level, variant);
  }

  /// The next style of [level] that is available (cycles 0 -> 1 -> 2 -> 0).
  int nextStyle(int level) {
    final cur = progress.styleOf(level);
    for (var k = 1; k <= styleCount; k++) {
      final v = (cur + k) % styleCount;
      if (progress.styleAvailable(level, v)) {
        return v;
      }
    }
    return cur;
  }

  void resetAll() {
    progress.reset();
    progress.level = 0;
    freshDecor = -1;
    freshPet = -1;
    freshBonusStyle = -1;
    freshSnowman = false;
    freshChestDecor = -1;
    _taskToasts = 0;
    buildLevel(0);
  }

  @override
  void dispose() {
    progress.removeListener(_onProgress);
    sounds.dispose();
    if (_ownsServices) {
      services.dispose();
    }
    super.dispose();
  }
}
