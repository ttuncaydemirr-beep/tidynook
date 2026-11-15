import 'package:flutter/material.dart';
import 'package:tidy_nook/game/progress.dart';
import 'package:tidy_nook/services/licenses.dart';
import 'package:tidy_nook/ui/app.dart';
import 'package:tidy_nook/ui/clock.dart';
import 'package:tidy_nook/ui/services.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  registerFontLicense();
  // Never throws; with broken or missing storage a fresh game starts.
  final progress = await Progress.load();
  // Web preview only: ?winter=1 / ?date=YYYY-MM-DD shift the date (no effect on Android).
  installPreviewClock();
  progress.clock = () => appNow();
  // Ads (after the consent answer), billing and analytics start after the
  // first frame inside the app and never block the start or need a network.
  final services = AppServices.create(progress);
  runApp(TidyNookApp(progress: progress, services: services));
}
