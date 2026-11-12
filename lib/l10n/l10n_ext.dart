import 'gen/app_localizations.dart';

/// Index-based access to the numbered translation keys.
///
/// Every helper is safe for out-of-range indexes: the index is clamped to the
/// first or last entry instead of throwing.
extension TidyL10n on AppLocalizations {
  /// 30 level names (levelName0..levelName29).
  List<String> get levelNames => <String>[
        levelName0,
        levelName1,
        levelName2,
        levelName3,
        levelName4,
        levelName5,
        levelName6,
        levelName7,
        levelName8,
        levelName9,
        levelName10,
        levelName11,
        levelName12,
        levelName13,
        levelName14,
        levelName15,
        levelName16,
        levelName17,
        levelName18,
        levelName19,
        levelName20,
        levelName21,
        levelName22,
        levelName23,
        levelName24,
        levelName25,
        levelName26,
        levelName27,
        levelName28,
        levelName29,
      ];

  /// 30 furniture names (decorName0..decorName29).
  List<String> get decorNames => <String>[
        decorName0,
        decorName1,
        decorName2,
        decorName3,
        decorName4,
        decorName5,
        decorName6,
        decorName7,
        decorName8,
        decorName9,
        decorName10,
        decorName11,
        decorName12,
        decorName13,
        decorName14,
        decorName15,
        decorName16,
        decorName17,
        decorName18,
        decorName19,
        decorName20,
        decorName21,
        decorName22,
        decorName23,
        decorName24,
        decorName25,
        decorName26,
        decorName27,
        decorName28,
        decorName29,
      ];

  /// 10 room names (roomName0..roomName9).
  List<String> get roomNames => <String>[
        roomName0,
        roomName1,
        roomName2,
        roomName3,
        roomName4,
        roomName5,
        roomName6,
        roomName7,
        roomName8,
        roomName9,
      ];

  /// 6 pet names (petName0..petName5).
  List<String> get petNames => <String>[
        petName0,
        petName1,
        petName2,
        petName3,
        petName4,
        petName5,
      ];

  /// 3 win titles.
  List<String> get winTitles => <String>[winTitle0, winTitle1, winTitle2];

  /// 5 daily box themes.
  List<String> get dailyThemes => <String>[
        dailyTheme0,
        dailyTheme1,
        dailyTheme2,
        dailyTheme3,
        dailyTheme4,
      ];

  String levelName(int i) => _pick(levelNames, i);

  String decorName(int i) => _pick(decorNames, i);

  String roomName(int i) => _pick(roomNames, i);

  String winTitle(int i) => _pick(winTitles, i);

  String petName(int i) => _pick(petNames, i);

  String dailyTheme(int i) => _pick(dailyThemes, i);
}

String _pick(List<String> list, int i) {
  if (i < 0) return list.first;
  if (i >= list.length) return list.last;
  return list[i];
}
