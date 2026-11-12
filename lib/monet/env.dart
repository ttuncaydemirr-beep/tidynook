// Where the monetization and service plugins may run.
//
// Every plugin call in lib/monet and lib/services is behind [MonetEnv.pluginsEnabled]:
// it is true only on a real Android device. On the web, on desktop and inside
// `flutter test` everything is a silent no-op, so no platform channel is
// called and no retry timer is left pending in widget tests.
import 'package:flutter/foundation.dart';

import 'env_stub.dart' if (dart.library.io) 'env_io.dart' as env;

class MonetEnv {
  MonetEnv._();

  /// Tests can force the answer (null = detect).
  @visibleForTesting
  static bool? debugPluginsEnabled;

  /// True only on an Android device outside `flutter test`.
  static bool get pluginsEnabled {
    final forced = debugPluginsEnabled;
    if (forced != null) {
      return forced;
    }
    if (kIsWeb) {
      return false;
    }
    return env.isAndroidDevice && !env.runningInFlutterTest;
  }

  /// True inside `flutter test`.
  static bool get inTest => !kIsWeb && env.runningInFlutterTest;
}
