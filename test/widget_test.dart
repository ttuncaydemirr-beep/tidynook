import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tidy_nook/game/progress.dart';
import 'package:tidy_nook/ui/app.dart';
import 'package:tidy_nook/ui/sounds.dart';

void main() {
  testWidgets('app starts and shows the brand', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final progress = await tester.runAsync(Progress.load);
    await tester.pumpWidget(
      TidyNookApp(progress: progress!, sounds: Sounds.silent()),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Tidy Nook'), findsOneWidget);
  });
}
