import 'package:flutter/foundation.dart';

/// The app's "now". Always [DateTime.now] on Android and in tests; only the
/// web preview may shift it (see [installPreviewClock]).
DateTime Function() appNow = DateTime.now;

/// True when the web preview runs with a shifted date.
bool previewClockActive = false;

/// Web preview only (never on Android, iOS or desktop): lets testers try the
/// winter event and date-based features outside their dates.
///
///  * `?winter=1` -> the app thinks it is 20 December of this year (same time of day);
///  * `?date=YYYY-MM-DD` -> that date (same time of day).
///
/// Progress saved in the browser then belongs to that date; open the preview
/// without the parameter (or reset progress) to go back.
void installPreviewClock({Uri? url}) {
  if (!kIsWeb && url == null) {
    return;
  }
  Map<String, String> q;
  try {
    q = (url ?? Uri.base).queryParameters;
  } catch (_) {
    return;
  }
  final now = DateTime.now();
  DateTime? target;
  final date = q['date'];
  if (date != null) {
    final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(date);
    if (m != null) {
      final y = int.parse(m[1]!);
      final mo = int.parse(m[2]!);
      final d = int.parse(m[3]!);
      if (mo >= 1 && mo <= 12 && d >= 1 && d <= 31) {
        target = DateTime(y, mo, d, now.hour, now.minute, now.second);
      }
    }
  }
  if (target == null && q['winter'] == '1') {
    target = DateTime(now.year, 12, 20, now.hour, now.minute, now.second);
  }
  if (target == null) {
    return;
  }
  final offset = target.difference(now);
  appNow = () => DateTime.now().add(offset);
  previewClockActive = true;
}
