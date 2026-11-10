import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tidy_nook/game/progress.dart';
import 'package:tidy_nook/ui/app.dart';
import 'package:tidy_nook/ui/sounds.dart';
import 'package:tidy_nook/ui/widgets.dart';

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

    // Dispose the app so its midnight timer is cancelled.
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('settings sheet shows the privacy row and opens the page',
      (WidgetTester tester) async {
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

    await tester.tap(find.byWidgetPredicate(
      (w) => w is CircleIconButton && w.label == 'Settings',
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    final row = find.text('Privacy policy');
    expect(row, findsOneWidget);

    await tester.ensureVisible(row);
    await tester.tap(row);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(AppBar), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text('Privacy policy'),
      ),
      findsOneWidget,
    );
    expect(find.byType(SelectableText), findsWidgets);
    expect(find.byType(BackButton), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });
}
