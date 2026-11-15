import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:tidy_nook/game/content.dart';
import 'package:tidy_nook/l10n/gen/app_localizations.dart';
import 'package:tidy_nook/l10n/l10n_ext.dart';
import 'package:tidy_nook/monet/ad_rules.dart' show kPlacementTaskDouble;

import 'clock.dart';
import 'controller.dart';
import 'rewarded.dart';
import 'theme.dart';
import 'widgets.dart';

const String _ns = 'xmlns="http://www.w3.org/2000/svg"';

/// The task chest (closed), painted like the daily and bonus box icons.
const String chestSvg = '<svg $_ns width="40" height="40" viewBox="0 0 40 40">'
    '<rect x="4" y="17" width="32" height="19" rx="3" fill="#B98A5E"/>'
    '<path d="M4 18c0-7 5-11 16-11s16 4 16 11z" fill="#D9A877"/>'
    '<rect x="4" y="17" width="32" height="4" fill="#8A6040"/>'
    '<rect x="9" y="8.5" width="3.5" height="27.5" fill="#F2C14E"/>'
    '<rect x="27.5" y="8.5" width="3.5" height="27.5" fill="#F2C14E"/>'
    '<rect x="16.5" y="17" width="7" height="8" rx="1.5" fill="#F2C14E" stroke="#B07D2A" stroke-width=".8"/>'
    '<circle cx="20" cy="21" r="1.3" fill="#8A6040"/></svg>';

/// The task chest, open, with a soft glow (the reward reveal).
const String chestOpenSvg = '<svg $_ns width="72" height="72" viewBox="0 0 40 40">'
    '<circle cx="20" cy="16" r="14" fill="#F6D26B" opacity=".35"/>'
    '<path d="M6 13l3-9h22l3 9z" fill="#D9A877"/>'
    '<rect x="9.5" y="4" width="3" height="9" fill="#F2C14E"/>'
    '<rect x="27.5" y="4" width="3" height="9" fill="#F2C14E"/>'
    '<rect x="4" y="17" width="32" height="19" rx="3" fill="#B98A5E"/>'
    '<rect x="4" y="17" width="32" height="4" fill="#8A6040"/>'
    '<rect x="9" y="17" width="3.5" height="19" fill="#F2C14E"/>'
    '<rect x="27.5" y="17" width="3.5" height="19" fill="#F2C14E"/>'
    '<path d="M14 15l1.2 2.4 2.6.4-1.9 1.8.5 2.6-2.4-1.3-2.3 1.3.4-2.6-1.9-1.8 2.6-.4z" fill="#FFF3C4"/>'
    '<path d="M26 12l.9 1.8 2 .3-1.4 1.4.3 2-1.8-1-1.8 1 .4-2-1.5-1.4 2-.3z" fill="#FFF3C4"/></svg>';

/// A small "play" mark for the optional ad button.
String playSvg(Color c) => '<svg $_ns width="14" height="14" viewBox="0 0 14 14">'
    '<path d="M4 2.5v9l7.5-4.5z" fill="${hexOf(c)}"/></svg>';

/// Daily tasks and the task chest, as a bottom sheet (opened from the house
/// card). [onReward] runs after a chest reward was revealed (the house
/// sparkles where the new piece went).
Future<void> showTasksSheet(
  BuildContext context,
  GameController controller, {
  void Function(ChestReward reward)? onReward,
}) {
  final c = TidyColors.of(context);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: false,
    backgroundColor: c.surface,
    barrierColor: c.scrim,
    elevation: 0,
    constraints: const BoxConstraints(maxWidth: 520),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
    ),
    builder: (sheetContext) => ListenableBuilder(
      listenable: controller,
      builder: (ctx, _) => TasksPanel(controller: controller, onReward: onReward),
    ),
  );
}

/// Content of the tasks sheet (public for tests).
class TasksPanel extends StatefulWidget {
  const TasksPanel({super.key, required this.controller, this.onReward});

  final GameController controller;
  final void Function(ChestReward reward)? onReward;

  @override
  State<TasksPanel> createState() => _TasksPanelState();
}

class _TasksPanelState extends State<TasksPanel> {
  bool _busy = false;
  String? _msg;
  Timer? _msgTimer;

  GameController get _ctl => widget.controller;

  @override
  void dispose() {
    _msgTimer?.cancel();
    super.dispose();
  }

  /// Short message inside the sheet (a toast would sit under the sheet).
  void _say(String text) {
    if (!mounted) {
      return;
    }
    setState(() => _msg = text);
    _msgTimer?.cancel();
    _msgTimer = Timer(const Duration(milliseconds: 2600), () {
      if (mounted) {
        setState(() => _msg = null);
      }
    });
  }

  void _claim(int i) {
    final t = AppLocalizations.of(context);
    final p = _ctl.progress;
    if (!p.claimTask(i, appNow())) {
      return;
    }
    _ctl.sounds.play('deco');
    if (!p.noAds) {
      _say(t.taskReward);
    }
  }

  /// Optional rewarded ad (placement task_double): one more hint for task [i].
  Future<void> _double(int i) async {
    if (_busy) {
      return;
    }
    final t = AppLocalizations.of(context);
    final c = TidyColors.of(context);
    _ctl.sounds.play('pick');
    _busy = true;
    bool ok;
    try {
      ok = await offerRewarded(
        context,
        _ctl.services,
        placement: kPlacementTaskDouble,
        title: t.taskDoubleTitle,
        text: t.taskDoubleText,
        iconSvg: bulbSvg(c.accent),
        onMessage: _say,
      );
    } finally {
      _busy = false;
    }
    if (!ok) {
      return;
    }
    if (_ctl.progress.doubleTask(i, appNow()) && mounted) {
      _ctl.sounds.play('deco');
      _say(t.taskDoubled);
    }
  }

  Future<void> _openChest() async {
    if (_busy) {
      return;
    }
    final p = _ctl.progress;
    final reward = p.openTaskChest();
    if (reward == null) {
      return;
    }
    try {
      _ctl.services.telemetry
          .logTaskChestOpen(reward.kind.name, n: p.chestsOpened);
    } catch (_) {}
    if (reward.kind == ChestRewardKind.style) {
      p.setStyle(reward.value, 2); // show the new style right away
    }
    _ctl.sounds.play('win');
    _busy = true;
    try {
      await showChestReveal(context, reward);
    } finally {
      _busy = false;
    }
    widget.onReward?.call(reward);
  }

  @override
  Widget build(BuildContext context) {
    final c = TidyColors.of(context);
    final t = AppLocalizations.of(context);
    final p = _ctl.progress;
    final now = appNow();
    final tasks = p.tasksFor(now);
    final doneCount = tasks.where((x) => x.done).length;
    final allDone = tasks.isNotEmpty && doneCount == tasks.length;

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsetsDirectional.fromSTEB(20, 18, 20, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Semantics(
                        header: true,
                        child: Text(
                          t.tasksTitle,
                          style: tx(26, w: 800, color: c.fg, height: 1.15),
                        ),
                      ),
                      Text(
                        allDone
                            ? t.tasksAllDone
                            : t.tasksProgress(doneCount, tasks.length),
                        style: tx(14, color: c.muted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                CircleIconButton(
                  label: t.close,
                  onTap: () => Navigator.of(context).maybePop(),
                  child: svgIcon(closeSvg(c.fg), size: 18),
                ),
              ],
            ),
            const SizedBox(height: 12),
            AnimatedSize(
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 200),
              alignment: Alignment.topCenter,
              child: _msg == null
                  ? const SizedBox(width: double.infinity)
                  : Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Semantics(
                        liveRegion: true,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: c.fg,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            _msg!,
                            textAlign: TextAlign.center,
                            style: tx(14, w: 700, color: c.bg),
                          ),
                        ),
                      ),
                    ),
            ),
            for (var i = 0; i < tasks.length; i++) ...<Widget>[
              if (i > 0) const SizedBox(height: 8),
              _TaskRow(
                index: i,
                controller: _ctl,
                onClaim: () => _claim(i),
                onDouble: () => unawaited(_double(i)),
              ),
            ],
            const SizedBox(height: 16),
            _ChestBlock(
              steps: p.chestSteps,
              ready: p.taskChestReady,
              onOpen: () => unawaited(_openChest()),
            ),
          ],
        ),
      ),
    );
  }
}

class _TaskRow extends StatelessWidget {
  const _TaskRow({
    required this.index,
    required this.controller,
    required this.onClaim,
    required this.onDouble,
  });

  final int index;
  final GameController controller;
  final VoidCallback onClaim;
  final VoidCallback onDouble;

  @override
  Widget build(BuildContext context) {
    final c = TidyColors.of(context);
    final t = AppLocalizations.of(context);
    final p = controller.progress;
    final task = p.tasksFor(appNow())[index];
    final noAds = p.noAds;
    final text = t.taskText(task.type.index, task.target);
    final sep = sepOf(context);

    String sub;
    if (!task.done) {
      sub = '${t.taskProgress(task.progress, task.target)}$sep${t.taskReward}';
    } else if (noAds) {
      sub = t.taskLabelDone;
    } else if (task.claimed) {
      sub = task.doubled ? t.taskDoubled : t.taskClaimed;
    } else {
      sub = t.taskReward;
    }

    final status = Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: task.done ? c.mint : null,
        border: Border.all(color: task.done ? c.mint : c.toggleOff, width: 2),
      ),
      child: task.done
          ? svgIcon(checkSvg(c.mintInk), size: 16)
          : Text(
              '${task.progress}',
              style: tx(13, w: 800, color: c.muted, height: 1.1),
            ),
    );

    Widget? trailing;
    if (task.done && !task.claimed && !noAds) {
      trailing = PillButton(
        label: t.taskClaim,
        small: true,
        semanticLabel: '${t.taskClaim}. ${t.taskReward}',
        onTap: onClaim,
      );
    } else if (task.done) {
      trailing = Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: c.mint, width: 1.5),
        ),
        child: Text(t.taskLabelDone, style: tx(13, w: 700, color: c.fg)),
      );
    }

    final canDouble = !noAds && task.claimed && !task.doubled;

    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 10, 10),
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: task.done ? c.mint : c.line, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              ExcludeSemantics(child: status),
              const SizedBox(width: 10),
              Expanded(
                child: Semantics(
                  container: true,
                  label: '$text. $sub',
                  excludeSemantics: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(text,
                          style: tx(15, w: 700, color: c.fg, height: 1.2)),
                      Text(sub, style: tx(13, color: c.muted, height: 1.3)),
                    ],
                  ),
                ),
              ),
              if (trailing != null) ...<Widget>[
                const SizedBox(width: 8),
                trailing,
              ],
            ],
          ),
          if (canDouble) ...<Widget>[
            const SizedBox(height: 6),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: PillButton(
                label: t.taskDoubleOffer,
                kind: PillKind.secondary,
                small: true,
                icon: svgIcon(playSvg(c.accent), size: 14),
                onTap: onDouble,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The 7 steps of the task chest and its Open button.
class _ChestBlock extends StatelessWidget {
  const _ChestBlock({
    required this.steps,
    required this.ready,
    required this.onOpen,
  });

  final int steps;
  final bool ready;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final c = TidyColors.of(context);
    final t = AppLocalizations.of(context);
    final shown = steps.clamp(0, taskChestSteps).toInt();
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ready ? c.accent : c.line, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              ExcludeSemantics(
                child: SvgPicture.string(chestSvg, width: 40, height: 40),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(t.chestTitle,
                        style: tx(16, w: 700, color: c.fg, height: 1.2)),
                    Text(
                      ready
                          ? t.chestReady
                          : t.chestProgress(shown, taskChestSteps),
                      style: tx(13, color: c.muted, height: 1.3),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Semantics(
            label: t.chestProgress(shown, taskChestSteps),
            excludeSemantics: true,
            child: Row(
              children: <Widget>[
                for (var k = 0; k < taskChestSteps; k++) ...<Widget>[
                  if (k > 0) const SizedBox(width: 6),
                  Expanded(
                    child: Container(
                      height: 12,
                      decoration: BoxDecoration(
                        color: k < shown ? c.mint : null,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                            color: k < shown ? c.mint : c.toggleOff,
                            width: 1.5),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          if (ready)
            Center(
              child: PillButton(
                label: t.chestOpen,
                icon: svgIcon(giftSvg(c.accentInk, c.accent), size: 18),
                onTap: onOpen,
              ),
            )
          else
            Text(t.chestHint, style: tx(12.5, color: c.muted)),
        ],
      ),
    );
  }
}

/// The reward reveal of the task chest: a calm card with the open chest,
/// the new piece and one button.
Future<void> showChestReveal(BuildContext context, ChestReward reward) {
  final c = TidyColors.of(context);
  final t = AppLocalizations.of(context);
  String text;
  Widget preview;
  switch (reward.kind) {
    case ChestRewardKind.style:
      text = t.newStyleFor(t.decorName(reward.value));
      preview = _RewardTile(svg: decorPreviewSvg(reward.value, 2));
    case ChestRewardKind.decor:
      text = t.chestGotDecor(t.chestDecorName(reward.value));
      preview = _RewardTile(svg: chestDecorPreviewSvg(reward.value));
    case ChestRewardKind.hints:
      text = t.chestGotHints(reward.value);
      preview = Container(
        width: 72,
        height: 72,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: c.bg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: c.accent, width: 2),
        ),
        child: svgIcon(bulbSvg(c.accent), size: 36),
      );
  }
  return showDialog<void>(
    context: context,
    barrierColor: c.scrim,
    builder: (ctx) => Dialog(
      backgroundColor: c.surface,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(26),
        side: BorderSide(color: c.line),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 20),
          child: PopIn(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Semantics(
                  header: true,
                  child: Text(
                    t.chestTitle,
                    textAlign: TextAlign.center,
                    style: tx(22, w: 800, color: c.fg, height: 1.2),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    ExcludeSemantics(
                      child:
                          SvgPicture.string(chestOpenSvg, width: 72, height: 72),
                    ),
                    const SizedBox(width: 14),
                    ExcludeSemantics(child: preview),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  text,
                  textAlign: TextAlign.center,
                  style: tx(17, w: 700, color: c.fg, height: 1.3),
                ),
                const SizedBox(height: 16),
                Center(
                  child: PillButton(
                    label: t.chestThanks,
                    minWidth: 140,
                    onTap: () => Navigator.of(ctx).pop(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _RewardTile extends StatelessWidget {
  const _RewardTile({required this.svg});

  final String svg;

  @override
  Widget build(BuildContext context) {
    final c = TidyColors.of(context);
    return Container(
      width: 72,
      height: 72,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.accent, width: 2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: SvgPicture.string(svg, fit: BoxFit.cover),
      ),
    );
  }
}
