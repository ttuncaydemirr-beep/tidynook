// Adds the Baloo Bhaijaan 2 font license (SIL Open Font License 1.1, assets/fonts/OFL.txt) to Flutter's
// LicenseRegistry, so it appears on the licenses page (showLicensePage / AboutDialog).
// Call registerFontLicense() once from main(), before runApp. Safe on every platform; never throws.
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const String kFontLicenseAsset = 'assets/fonts/OFL.txt';

bool _registered = false;

/// Registers the font license once (later calls do nothing). The text is loaded lazily, only when
/// the licenses page is opened.
void registerFontLicense() {
  if (_registered) {
    return;
  }
  _registered = true;
  LicenseRegistry.addLicense(() async* {
    String text;
    try {
      text = await rootBundle.loadString(kFontLicenseAsset);
    } catch (_) {
      text = 'Baloo Bhaijaan 2 - SIL Open Font License, Version 1.1 (https://openfontlicense.org)';
    }
    yield LicenseEntryWithLineBreaks(const <String>['Baloo Bhaijaan 2'], text);
  });
}
