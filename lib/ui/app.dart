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

class _TidyNookAppState extends State<TidyNookApp> {
  late final GameController _ctl;
  final ThemeData _light = buildTheme(Brightness.light);
  final ThemeData _dark = buildTheme(Brightness.dark);

  @override
  void initState() {
    super.initState();
    _ctl = GameController(
      progress: widget.progress,
      sounds: widget.sounds ??
          Sounds(enabled: () => widget.progress.sound),
    );
    _ctl.start();
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  Locale? _chosen() {
    final l = widget.progress.lang;
    return l == null ? null : Locale(l);
  }

  static Locale _resolve(Locale? device, Iterable<Locale> supported) {
    if (device != null) {
      for (final s in supported) {
        if (s.languageCode == device.languageCode) {
          return s;
        }
      }
    }
    return const Locale('tr');
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
        localeResolutionCallback: _resolve,
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
