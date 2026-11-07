import 'gen/app_localizations.dart';

/// Index-based access to the numbered translation keys.
extension TidyL10n on AppLocalizations {
  String levelName(int i) {
    switch (i) {
      case 0:
        return levelName0;
      case 1:
        return levelName1;
      case 2:
        return levelName2;
      case 3:
        return levelName3;
      case 4:
        return levelName4;
      case 5:
        return levelName5;
      case 6:
        return levelName6;
      case 7:
        return levelName7;
      case 8:
        return levelName8;
      case 9:
        return levelName9;
      case 10:
        return levelName10;
      case 11:
        return levelName11;
      case 12:
        return levelName12;
      case 13:
        return levelName13;
      case 14:
        return levelName14;
      case 15:
        return levelName15;
      case 16:
        return levelName16;
      default:
        return levelName17;
    }
  }

  String decorName(int i) {
    switch (i) {
      case 0:
        return decorName0;
      case 1:
        return decorName1;
      case 2:
        return decorName2;
      case 3:
        return decorName3;
      case 4:
        return decorName4;
      case 5:
        return decorName5;
      case 6:
        return decorName6;
      case 7:
        return decorName7;
      case 8:
        return decorName8;
      case 9:
        return decorName9;
      case 10:
        return decorName10;
      case 11:
        return decorName11;
      case 12:
        return decorName12;
      case 13:
        return decorName13;
      case 14:
        return decorName14;
      case 15:
        return decorName15;
      case 16:
        return decorName16;
      default:
        return decorName17;
    }
  }

  String roomName(int i) {
    switch (i) {
      case 0:
        return roomName0;
      case 1:
        return roomName1;
      case 2:
        return roomName2;
      case 3:
        return roomName3;
      case 4:
        return roomName4;
      default:
        return roomName5;
    }
  }

  String winTitle(int i) {
    switch (i) {
      case 0:
        return winTitle0;
      case 1:
        return winTitle1;
      default:
        return winTitle2;
    }
  }

  String petName(int i) {
    switch (i) {
      case 0:
        return petName0;
      case 1:
        return petName1;
      default:
        return petName2;
    }
  }

  String dailyTheme(int i) {
    switch (i) {
      case 0:
        return dailyTheme0;
      case 1:
        return dailyTheme1;
      case 2:
        return dailyTheme2;
      case 3:
        return dailyTheme3;
      default:
        return dailyTheme4;
    }
  }

  List<String> get roomNames => <String>[
        roomName0,
        roomName1,
        roomName2,
        roomName3,
        roomName4,
        roomName5,
      ];
}
