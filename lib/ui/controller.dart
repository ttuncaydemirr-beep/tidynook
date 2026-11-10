import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:tidy_nook/game/content.dart';
import 'package:tidy_nook/game/daily.dart';
import 'package:tidy_nook/game/progress.dart';

import 'sounds.dart';

enum AppScreen { house, play }

/// What the house screen should celebrate when it opens.
class HouseEvents {
  const HouseEvents({this.decor = -1, this.pet = -1, this.toastRoom = -1});
  final int decor;
  final int pet;
  final int toastRoom;
}

/// Navigation and game flow (build(), goHouse(), start(), win bookkeeping of the HTML).
class GameController extends ChangeNotifier {
  GameController({required this.progress, required this.sounds}) {
    progress.addListener(_onProgress);
  }

  final Progress progress;
  final Sounds sounds;

  AppScreen screen = AppScreen.house;
  bool isDaily = false;
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

  final math.Random random = math.Random();

  void _onProgress() => notifyListeners();

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

  void _buildLevel(int i) {
    isDaily = false;
    levelIndex = i;
    progress.level = i;
    current = levels[i];
    playSerial++;
    screen = AppScreen.play;
  }

  void _openHouse() {
    isDaily = false;
    screen = AppScreen.house;
    houseSerial++;
  }

  void buildLevel(int i) {
    _buildLevel(i);
    progress.setLevel(i);
    notifyListeners();
  }

  void startDaily() {
    final now = DateTime.now();
    if (progress.dailyDoneToday(now)) {
      return;
    }
    isDaily = true;
    final day = dayString(now);
    _dailyDay = day;
    final level = dailyLevel(day);
    dailyTheme = level.theme;
    current = level;
    playSerial++;
    screen = AppScreen.play;
    notifyListeners();
  }

  /// Home button / back: leave the level without announcing a new piece.
  void goHome() {
    freshDecor = -1;
    goHouse();
  }

  void goHouse() {
    _openHouse();
    notifyListeners();
  }

  /// Next level button, "continue" button and the reset.
  void playNext() {
    final nx = progress.nextOpen;
    buildLevel(nx < 0 ? 0 : nx);
  }

  /// Bookkeeping when the last item is placed.
  void recordWin() {
    if (isDaily) {
      freshPet = progress.completeDaily(DateTime.now(), day: _dailyDay);
    } else {
      final r = progress.completeLevel(levelIndex);
      if (r >= 0) {
        freshDecor = r;
      }
    }
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
    final ev = HouseEvents(decor: freshDecor, pet: freshPet, toastRoom: toast);
    freshDecor = -1;
    freshPet = -1;
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

  void resetAll() {
    progress.reset();
    progress.level = 0;
    freshDecor = -1;
    freshPet = -1;
    buildLevel(0);
  }

  @override
  void dispose() {
    progress.removeListener(_onProgress);
    sounds.dispose();
    super.dispose();
  }
}
