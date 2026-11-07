import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:tidy_nook/l10n/gen/app_localizations.dart';

import 'controller.dart';
import 'settings_sheet.dart';
import 'theme.dart';
import 'widgets.dart';

class TopBar extends StatelessWidget {
  const TopBar({super.key, required this.controller});

  final GameController controller;

  @override
  Widget build(BuildContext context) {
    final c = TidyColors.of(context);
    final t = AppLocalizations.of(context);
    final on = controller.progress.sound;
    return Row(
      children: <Widget>[
        Expanded(
          child: Row(
            children: <Widget>[
              ExcludeSemantics(
                child: SvgPicture.string(brandSvg(c), width: 22, height: 22),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  'Tidy Nook',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tx(18, w: 800, color: c.fg),
                ),
              ),
            ],
          ),
        ),
        CircleIconButton(
          label: t.sound,
          toggled: on,
          onTap: controller.toggleSound,
          child: svgIcon(on ? soundOnSvg(c.fg) : soundOffSvg(c.fg), size: 20),
        ),
        const SizedBox(width: 10),
        CircleIconButton(
          label: t.settings,
          onTap: () {
            controller.sounds.play('pick');
            showSettingsSheet(context, controller);
          },
          child: svgIcon(gearSvg(c.fg, c.surface), size: 20),
        ),
      ],
    );
  }
}
