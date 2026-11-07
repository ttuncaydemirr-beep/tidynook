import 'package:flutter/material.dart';
import 'package:tidy_nook/game/progress.dart';
import 'package:tidy_nook/ui/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final progress = await Progress.load();
  runApp(TidyNookApp(progress: progress));
}
