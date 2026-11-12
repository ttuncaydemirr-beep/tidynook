// Picked by env.dart on platforms that have dart:io (Android, desktop, tests).
import 'dart:io' show Platform;

/// True inside `flutter test` (the test runner sets FLUTTER_TEST).
bool get runningInFlutterTest {
  try {
    return Platform.environment.containsKey('FLUTTER_TEST');
  } catch (_) {
    return false;
  }
}

bool get isAndroidDevice {
  try {
    return Platform.isAndroid;
  } catch (_) {
    return false;
  }
}
