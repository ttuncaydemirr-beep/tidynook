import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tidy_nook/game/progress.dart';
import 'package:tidy_nook/monet/env.dart';
import 'package:tidy_nook/ui/app.dart';
import 'package:tidy_nook/ui/services.dart';
import 'package:tidy_nook/ui/sounds.dart';
import 'package:tidy_nook/ui/widgets.dart';

Future<void> _pumpApp(WidgetTester tester, Progress progress,
    {AppServices? services}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  tester.view.physicalSize = const Size(1080, 1920); // 360 x 640 dp
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    TidyNookApp(
      progress: progress,
      sounds: Sounds.silent(),
      services: services,
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _openSettings(WidgetTester tester) async {
  await tester.tap(find.byWidgetPredicate(
    (w) => w is CircleIconButton && w.label == 'Settings',
  ));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  testWidgets('plugins are off in widget tests', (WidgetTester tester) async {
    // Ads, billing, reminder, review and telemetry must all be no-ops here.
    SharedPreferences.setMockInitialValues(<String, Object>{});
    expect(MonetEnv.pluginsEnabled, isFalse);
    final services = AppServices.create(Progress());
    expect(services.ads.enabled, isFalse);
    expect(services.ads.rewardedReady, isFalse);
    expect(services.ads.privacyOptionsRequired, isFalse);
    expect(services.billing.available, isFalse);
    expect(services.billing.priceOf('remove_ads'), isNull);
    expect(
      await services.ads.maybeInterstitial(
          completedLevelIndex: 5, isDaily: false),
      isFalse,
    );
    services.dispose();
  });

  testWidgets('app starts and shows the brand', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final progress = await tester.runAsync(Progress.load);
    await _pumpApp(tester, progress!);

    expect(find.text('Tidy Nook'), findsOneWidget);

    // Dispose the app so its midnight timer is cancelled.
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('settings sheet shows the shop rows and the privacy page',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final progress = await tester.runAsync(Progress.load);
    await _pumpApp(tester, progress!);
    await _openSettings(tester);

    expect(find.text('Vibration'), findsOneWidget);
    expect(find.text('Daily reminder'), findsOneWidget);
    expect(find.text('Shop'), findsOneWidget);
    expect(find.text('Remove ads'), findsOneWidget);
    expect(find.text('Supporter Pack'), findsOneWidget);
    expect(find.text('Restore purchases'), findsOneWidget);
    // no price from Play in tests: the plain buy label
    expect(find.text('Buy'), findsNWidgets(2));
    // UMP does not require the privacy choices row off-device
    expect(find.text('Privacy choices'), findsNothing);

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

  testWidgets('owned products show Owned instead of a buy button',
      (WidgetTester tester) async {
    final progress = Progress(lang: 'en', supporter: true, adsRemoved: true);
    await _pumpApp(tester, progress);
    await _openSettings(tester);

    expect(find.text('Owned'), findsNWidgets(2));
    expect(find.text('Buy'), findsNothing);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('hint button offers an optional ad when no free hint is left',
      (WidgetTester tester) async {
    final now = DateTime.now();
    final today = '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
    final progress = Progress(lang: 'en', hintDay: today, hintsUsed: 3);
    expect(progress.hintsLeft(now), 0);
    await _pumpApp(tester, progress);

    // level 1 opens first (nothing is done yet)
    await tester.tap(find.text('Hint'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      find.text('No free hints left today. Watch a short ad for one more hint?'),
      findsOneWidget,
    );
    expect(find.text('Watch ad'), findsOneWidget);
    expect(find.text('No thanks'), findsOneWidget);

    // no rewarded ad is ready in tests: a short message, nothing granted
    await tester.tap(find.text('Watch ad'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('No ad available right now. Please try again later.'),
        findsOneWidget);
    expect(progress.extraHints, 0);
    expect(progress.hintsLeft(DateTime.now()), 0);

    await tester.pump(const Duration(seconds: 4));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a free hint is used without any offer',
      (WidgetTester tester) async {
    final progress = Progress(lang: 'en');
    await _pumpApp(tester, progress);

    await tester.tap(find.text('Hint'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Watch ad'), findsNothing);
    expect(progress.hintsLeft(DateTime.now()), 2);

    await tester.pump(const Duration(seconds: 2));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('rapid hint taps use only one free hint while it plays',
      (WidgetTester tester) async {
    final progress = Progress(lang: 'en');
    await _pumpApp(tester, progress);

    await tester.tap(find.text('Hint'));
    await tester.pump();
    await tester.tap(find.text('Hint'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('Hint'));
    await tester.pump(const Duration(milliseconds: 100));

    expect(progress.hintsLeft(DateTime.now()), 2);

    await tester.pump(const Duration(seconds: 2));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('bonus card is locked before 12 levels',
      (WidgetTester tester) async {
    final progress = Progress(lang: 'en', done: <int>{0, 1, 2});
    await _pumpApp(tester, progress);

    expect(find.text('Bonus boxes'), findsOneWidget);
    expect(find.text('Finish 12 levels to unlock bonus boxes'), findsOneWidget);
    expect(find.text('Play'), findsNothing);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('bonus card opens bonus box 1 when unlocked',
      (WidgetTester tester) async {
    final progress = Progress(
      lang: 'en',
      done: <int>{for (var i = 0; i < 12; i++) i},
    );
    await _pumpApp(tester, progress);

    expect(find.text('Bonus box 1'), findsOneWidget);
    expect(find.text('0/5 to a new style'), findsOneWidget);
    await tester.tap(find.text('Play'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // play screen: bonus title, no level dots
    expect(find.text('Bonus box 1'), findsOneWidget);
    expect(find.text('BONUS BOXES'), findsOneWidget);
    expect(find.text('Hint'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Arabic house and settings at 1.5x text fit 360 x 640',
      (WidgetTester tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final progress = Progress(
      lang: 'ar',
      done: <int>{for (var i = 0; i < 12; i++) i},
    );
    await _pumpApp(tester, progress);
    expect(tester.takeException(), isNull);

    // the settings button is the last round button of the top bar
    await tester.tap(find.byType(CircleIconButton).last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Supporter Pack'), findsNothing); // translated
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
  });
}
