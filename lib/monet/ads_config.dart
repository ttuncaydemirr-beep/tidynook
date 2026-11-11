// AdMob ad unit IDs and the Play product IDs, all in one place (ported from Arrowtile's ads_config.dart).
//
// TODO(owner): Tidy Nook has no AdMob app yet, so every ID below is one of Google's public TEST IDs
// (https://developers.google.com/admob/flutter/test-ads). Test ads are safe to show to real players
// (they earn nothing and break no policy), so a release that still has them simply earns nothing.
// When the AdMob app and its three ad units exist (docs/MONETIZATION.md, "Owner checklist"):
//   1. paste the three unit IDs into [releaseInterstitialId], [releaseRewardedId], [releaseBannerId];
//   2. paste the AdMob APP ID (the one with "~") into android/app/src/main/res/values/ads.xml.
// Debug and profile builds ALWAYS use the test units (clicking your own real ads gets AdMob accounts closed).
import 'package:flutter/foundation.dart';

class AdsConfig {
  AdsConfig._();

  // Google's official test ad units (Android).
  static const String testInterstitialId = 'ca-app-pub-3940256099942544/1033173712';
  static const String testRewardedId = 'ca-app-pub-3940256099942544/5224354917';
  static const String testBannerId = 'ca-app-pub-3940256099942544/9214589741'; // adaptive banner test unit

  // TODO(owner): replace with the real unit IDs from AdMob (used only by release builds).
  static const String releaseInterstitialId = 'ca-app-pub-3940256099942544/1033173712';
  static const String releaseRewardedId = 'ca-app-pub-3940256099942544/5224354917';
  static const String releaseBannerId = 'ca-app-pub-3940256099942544/9214589741';

  static String get interstitialId => kReleaseMode ? releaseInterstitialId : testInterstitialId;
  static String get rewardedId => kReleaseMode ? releaseRewardedId : testRewardedId;
  static String get bannerId => kReleaseMode ? releaseBannerId : testBannerId;

  static bool isTestUnit(String id) => id.startsWith('ca-app-pub-3940256099942544/');

  /// True while a release build still uses Google's test units (no revenue). Only used for logging.
  static bool get usingTestIdsInRelease =>
      kReleaseMode &&
      (isTestUnit(releaseInterstitialId) || isTestUnit(releaseRewardedId) || isTestUnit(releaseBannerId));

  /// To see the EEA consent form outside the EEA in a DEBUG build:
  /// `flutter run --dart-define=UMP_DEBUG_EEA=true`. No effect in release builds.
  static const bool umpDebugGeographyEea = bool.fromEnvironment('UMP_DEBUG_EEA');

  /// Optional hashed test-device id printed by UMP in logcat (debug builds only).
  static const String umpTestDeviceId = '';
}
