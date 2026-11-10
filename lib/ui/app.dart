import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tidy_nook/game/progress.dart';
import 'package:tidy_nook/l10n/gen/app_localizations.dart';

import 'controller.dart';
import 'house_screen.dart';
import 'play_screen.dart';
import 'sounds.dart';
import 'theme.dart';
import 'top_bar.dart';

class TidyNookApp extends StatefulWidget {
  const TidyNookApp({super.key, required this.progress, this.sounds});

  final Progress progress;

  /// Replace the audio (tests use Sounds.silent()).
  final Sounds? sounds;

  @override
  State<TidyNookApp> createState() => _TidyNookAppState();
}

class _TidyNookAppState extends State<TidyNookApp>
    with WidgetsBindingObserver {
  late final GameController _ctl;
  final ThemeData _light = buildTheme(Brightness.light);
  final ThemeData _dark = buildTheme(Brightness.dark);
  Timer? _midnight;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ctl = GameController(
      progress: widget.progress,
      sounds: widget.sounds ??
          Sounds(enabled: () => widget.progress.sound),
    );
    _ctl.start();
    _scheduleMidnight();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _midnight?.cancel();
    _ctl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // The date may have changed while the app was in the background.
      _ctl.refresh();
      _scheduleMidnight();
    }
  }

  /// Wakes up just after the next local midnight so the house card, the daily
  /// box and the streak text follow the new date.
  void _scheduleMidnight() {
    _midnight?.cancel();
    final now = DateTime.now();
    final next = DateTime(now.year, now.month, now.day + 1);
    final wait = next.difference(now) + const Duration(seconds: 1);
    _midnight = Timer(wait, () {
      if (!mounted) {
        return;
      }
      _ctl.refresh();
      _scheduleMidnight();
    });
  }

  Locale? _chosen() {
    final l = widget.progress.lang;
    return l == null ? null : Locale(l);
  }

  /// First language in the user's list that we support, otherwise English.
  static Locale _resolve(List<Locale>? preferred, Iterable<Locale> supported) {
    for (final p in preferred ?? const <Locale>[]) {
      for (final s in supported) {
        if (s.languageCode == p.languageCode) {
          return s;
        }
      }
    }
    return const Locale('en');
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _ctl,
      builder: (context, _) => MaterialApp(
        debugShowCheckedModeBanner: false,
        onGenerateTitle: (ctx) => AppLocalizations.of(ctx).appTitle,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: _chosen(),
        localeListResolutionCallback: _resolve,
        builder: (context, child) => MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.5,
          child: child ?? const SizedBox.shrink(),
        ),
        theme: _light,
        darkTheme: _dark,
        themeMode: ThemeMode.system,
        home: GameShell(controller: _ctl),
      ),
    );
  }
}

/// Page background, top bar and the current screen, with the back-button rules.
class GameShell extends StatelessWidget {
  const GameShell({super.key, required this.controller});

  final GameController controller;

  @override
  Widget build(BuildContext context) {
    final c = TidyColors.of(context);
    final onPlay = controller.screen == AppScreen.play;
    final overlay = c.dark
        ? SystemUiOverlayStyle.light.copyWith(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: c.bg,
          )
        : SystemUiOverlayStyle.dark.copyWith(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: c.bg,
          );
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlay,
      child: PopScope(
        canPop: !onPlay,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop && onPlay) {
            controller.goHome();
          }
        },
        child: Scaffold(
          backgroundColor: c.bg,
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      TopBar(controller: controller),
                      const SizedBox(height: 6),
                      Expanded(
                        child: onPlay
                            ? PlayScreen(
                                key: ValueKey<String>(
                                    'play${controller.playSerial}'),
                                controller: controller,
                              )
                            : HouseScreen(
                                key: ValueKey<String>(
                                    'house${controller.houseSerial}'),
                                controller: controller,
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
