import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tidy_nook/game/content.dart';
import 'package:tidy_nook/game/daily.dart';
import 'package:tidy_nook/game/progress.dart';
import 'package:tidy_nook/monet/env.dart';
import 'package:tidy_nook/ui/app.dart';
import 'package:tidy_nook/ui/clock.dart';
import 'package:tidy_nook/ui/controller.dart';
import 'package:tidy_nook/ui/services.dart';
import 'package:tidy_nook/ui/sounds.dart';
import 'package:tidy_nook/ui/tasks_sheet.dart';
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

/// Runs the app (and Progress) on a fixed local date.
void _fixDate(Progress progress, DateTime at) {
  appNow = () => at;
  progress.clock = () => at;
  addTearDown(() => appNow = DateTime.now);
}

Future<void> _openTasks(WidgetTester tester) async {
  final card = find.text('Daily tasks');
  await tester.ensureVisible(card);
  await tester.tap(card);
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


  testWidgets('tasks card opens the tasks; claim adds a hint, no ad = no double',
      (WidgetTester tester) async {
    final at = DateTime(2026, 6, 10, 12);
    final progress = Progress(lang: 'en', done: <int>{0, 1, 2});
    _fixDate(progress, at);
    final tasks = progress.tasksFor(at);
    expect(tasks.length, 3);
    progress.tasks[0].progress = progress.tasks[0].target;
    await _pumpApp(tester, progress);

    expect(find.text('Daily tasks'), findsOneWidget);
    expect(find.text('Claim'), findsOneWidget); // on the card
    await _openTasks(tester);

    final panel = find.byType(TasksPanel);
    expect(panel, findsOneWidget);
    final claim =
        find.descendant(of: panel, matching: find.text('Claim'));
    expect(claim, findsOneWidget);
    expect(find.descendant(of: panel, matching: find.text('Task chest')),
        findsOneWidget);
    await tester.tap(claim);
    await tester.pump();
    expect(progress.extraHints, 1);
    expect(progress.tasks[0].claimed, isTrue);
    expect(find.text('Hint added'), findsOneWidget);

    // optional double: Watch ad / No thanks; no ad ready -> message, nothing granted
    final dbl = find.text('+1 hint for an ad');
    expect(dbl, findsOneWidget);
    await tester.tap(dbl);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Double your hint'), findsOneWidget);
    expect(find.text('No thanks'), findsOneWidget);
    await tester.tap(find.text('Watch ad'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('No ad available right now. Please try again later.'),
        findsOneWidget);
    expect(progress.extraHints, 1);
    expect(progress.tasks[0].doubled, isFalse);
    expect(tester.takeException(), isNull);

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a task finished during play shows a chip on the play screen',
      (WidgetTester tester) async {
    final at = DateTime(2026, 6, 10, 12);
    final progress = Progress(
      lang: 'en',
      taskDay: dayString(at),
      tasks: <DailyTask>[
        DailyTask(type: TaskType.hint),
        DailyTask(type: TaskType.boxes, target: 2),
        DailyTask(type: TaskType.newLevel),
      ],
    );
    _fixDate(progress, at);
    await _pumpApp(tester, progress); // level 1 opens first

    await tester.tap(find.text('Hint'));
    await tester.pump();
    expect(find.text('Task done!'), findsNothing); // queued behind the lid
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text('Task done!'), findsOneWidget);
    expect(progress.tasks[0].done, isTrue);
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('Task done!'), findsNothing);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('supporters see tasks without claim or ad buttons',
      (WidgetTester tester) async {
    final at = DateTime(2026, 6, 10, 12);
    final progress =
        Progress(lang: 'en', done: <int>{0, 1, 2}, supporter: true);
    _fixDate(progress, at);
    progress.tasksFor(at);
    progress.tasks[0].progress = progress.tasks[0].target;
    await _pumpApp(tester, progress);
    await _openTasks(tester);

    expect(find.text('Claim'), findsNothing);
    expect(find.text('+1 hint for an ad'), findsNothing);
    expect(find.descendant(
            of: find.byType(TasksPanel), matching: find.text('Done')),
        findsWidgets);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a full task chest opens with a reward reveal',
      (WidgetTester tester) async {
    final at = DateTime(2026, 6, 10, 12);
    final progress =
        Progress(lang: 'en', done: <int>{0, 1, 2}, chestSteps: 7);
    _fixDate(progress, at);
    await _pumpApp(tester, progress);
    await _openTasks(tester);

    expect(find.text('Your task chest is full!'), findsWidgets);
    final open = find.descendant(
        of: find.byType(TasksPanel), matching: find.text('Open'));
    expect(open, findsOneWidget);
    await tester.ensureVisible(open);
    await tester.tap(open);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(progress.chestSteps, 0);
    expect(progress.chestsOpened, 1);
    expect(progress.extraStyles.length, 1);
    final lvl = progress.extraStyles.first;
    expect(progress.styleOf(lvl), 2);
    expect(find.textContaining('New style for the'), findsOneWidget);
    await tester.tap(find.text('Lovely!'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Lovely!'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('winter card only during the event; it opens a winter box',
      (WidgetTester tester) async {
    final summer = Progress(lang: 'en', done: <int>{0});
    _fixDate(summer, DateTime(2026, 6, 10, 12));
    await _pumpApp(tester, summer);
    expect(find.text('Winter boxes'), findsNothing);
    await tester.pumpWidget(const SizedBox());

    final progress = Progress(lang: 'en', done: <int>{0});
    _fixDate(progress, DateTime(2026, 12, 20, 12));
    await _pumpApp(tester, progress);
    final card = find.text('Winter boxes');
    expect(card, findsOneWidget);
    expect(find.textContaining('0/7 done'), findsOneWidget);
    await tester.ensureVisible(card);
    await tester.tap(card);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Mitten Basket'), findsOneWidget);
    expect(find.text('Winter box: a little gift for the season'),
        findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('winter win is recorded; the 7th box brings the snowman',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final at = DateTime(2026, 12, 20, 12);
    final progress = Progress(
        lang: 'en', done: <int>{0}, winterSeason: 2026,
        winterDone: <int>{0, 1, 2, 3, 4, 5});
    _fixDate(progress, at);
    final ctl = GameController(progress: progress, sounds: Sounds.silent());
    addTearDown(ctl.dispose);
    ctl.startWinter();
    expect(ctl.isWinter, isTrue);
    expect(ctl.winterIndex, 6);
    ctl.recordWin();
    expect(progress.winterBoxDone(6, at), isTrue);
    expect(ctl.freshSnowman, isTrue);
    expect(progress.snowman, isTrue);
    expect(ctl.nextWinterBox(), -1);
    final ev = ctl.takeHouseEvents();
    expect(ev.snowman, isTrue);
    expect(ctl.takeHouseEvents().snowman, isFalse);
  });

  testWidgets('a drawer level shows the drawer tip and the drawer counter',
      (WidgetTester tester) async {
    final progress = Progress(
      lang: 'en',
      done: <int>{for (var i = 0; i < 30; i++) i},
    );
    _fixDate(progress, DateTime(2026, 6, 10, 12));
    expect(levels[30].hasDrawers, isTrue);
    await _pumpApp(tester, progress);

    await tester.tap(find.textContaining('Continue'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Drawer: fill the outside first, then it opens'),
        findsOneWidget);
    expect(progress.mechanicTipSeen, isTrue);
    final keys = drawerKeys(levels[30], 0).length;
    expect(find.text('$keys more to open'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('house draws snow, snowman and chest decor without errors',
      (WidgetTester tester) async {
    final progress = Progress(
      lang: 'en',
      done: <int>{for (var i = 0; i < 45; i++) i},
      snowman: true,
      chestDecors: <int>{0, 1, 2, 3},
    );
    _fixDate(progress, DateTime(2027, 1, 3, 12));
    await _pumpApp(tester, progress);
    expect(find.text('Winter boxes'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  test('preview clock: only with ?winter=1 or ?date=', () {
    addTearDown(() {
      appNow = DateTime.now;
      previewClockActive = false;
    });
    installPreviewClock(url: Uri.parse('http://localhost/'));
    expect(previewClockActive, isFalse);
    installPreviewClock(url: Uri.parse('http://localhost/?winter=1'));
    expect(previewClockActive, isTrue);
    expect(winterActive(appNow()), isTrue);
    expect(appNow().month, 12);
    installPreviewClock(url: Uri.parse('http://localhost/?date=2027-01-15'));
    expect(dayString(appNow()), '2027-01-15');
  });

  testWidgets('Arabic house and settings at 1.5x text fit 360 x 640',
      (WidgetTester tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final progress = Progress(
      lang: 'ar',
      done: <int>{for (var i = 0; i < 12; i++) i},
      chestSteps: 3,
    );
    _fixDate(progress, DateTime(2026, 12, 20, 12));
    progress.tasksFor(DateTime(2026, 12, 20, 12));
    progress.tasks[1].progress = progress.tasks[1].target;
    await _pumpApp(tester, progress);
    expect(tester.takeException(), isNull);

    // tasks sheet in Arabic at 1.5x: no overflow
    final tasksCard = find.text('مهام اليوم');
    await tester.ensureVisible(tasksCard);
    await tester.tap(tasksCard);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(TasksPanel), findsOneWidget);
    expect(tester.takeException(), isNull);
    Navigator.of(tester.element(find.byType(TasksPanel))).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // the settings button is the last round button of the top bar
    await tester.tap(find.byType(CircleIconButton).last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Supporter Pack'), findsNothing); // translated
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
  });
}
