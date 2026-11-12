import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:tidy_nook/l10n/gen/app_localizations.dart';

import 'services.dart';
import 'theme.dart';
import 'widgets.dart';

/// Short message at the bottom of the screen (never for ads that just did
/// not load, except the one-line [AppLocalizations.adNotReady]).
void showToast(BuildContext context, String text) {
  final m = ScaffoldMessenger.maybeOf(context);
  if (m == null) {
    return;
  }
  m.hideCurrentSnackBar();
  m.showSnackBar(SnackBar(
    content: Text(text),
    duration: const Duration(milliseconds: 2600),
  ));
}

/// A small, calm two-choice dialog (title, text, yes / no). Completes true
/// only when the player chose [yes].
Future<bool> askChoice(
  BuildContext context, {
  String? title,
  required String text,
  required String yes,
  required String no,
  String? iconSvg,
}) async {
  final c = TidyColors.of(context);
  final r = await showDialog<bool>(
    context: context,
    barrierColor: c.scrim,
    builder: (ctx) => Dialog(
      backgroundColor: c.surface,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: c.line),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (iconSvg != null) ...<Widget>[
                Center(
                  child: ExcludeSemantics(
                    child: SvgPicture.string(iconSvg, width: 44, height: 44),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              if (title != null) ...<Widget>[
                Semantics(
                  header: true,
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    style: tx(21, w: 800, color: c.fg, height: 1.2),
                  ),
                ),
                const SizedBox(height: 6),
              ],
              Text(
                text,
                textAlign: TextAlign.center,
                style: tx(15, color: c.fg, height: 1.35),
              ),
              const SizedBox(height: 16),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  PillButton(
                    label: no,
                    kind: PillKind.secondary,
                    onTap: () => Navigator.of(ctx).pop(false),
                  ),
                  PillButton(
                    label: yes,
                    onTap: () => Navigator.of(ctx).pop(true),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
  return r ?? false;
}

/// The optional rewarded flow: "Watch ad" / "No thanks". When the player
/// chooses to watch and no ad is ready, shows [AppLocalizations.adNotReady]
/// and grants nothing. Completes true only when the reward was earned.
Future<bool> offerRewarded(
  BuildContext context,
  AppServices services, {
  required String placement,
  String? title,
  required String text,
  String? iconSvg,
}) async {
  final t = AppLocalizations.of(context);
  final yes = await askChoice(
    context,
    title: title,
    text: text,
    yes: t.watchAd,
    no: t.noThanks,
    iconSvg: iconSvg,
  );
  if (!yes) {
    try {
      services.telemetry.logRewarded(placement, 'declined');
    } catch (_) {}
    return false;
  }
  if (!services.ads.rewardedReady) {
    try {
      services.telemetry.logRewarded(placement, 'unavailable');
    } catch (_) {}
    services.ads.preload();
    if (context.mounted) {
      showToast(context, t.adNotReady);
    }
    return false;
  }
  var ok = false;
  try {
    ok = await services.ads.showRewarded(placement);
  } catch (_) {
    ok = false;
  }
  try {
    services.telemetry.logRewarded(placement, ok ? 'rewarded' : 'closed');
  } catch (_) {}
  return ok;
}
