import 'package:flutter/material.dart';
import 'package:tidy_nook/l10n/gen/app_localizations.dart';

import 'theme.dart';

/// Full-screen privacy policy. Works offline: the text ships in the app.
class PrivacyPage extends StatelessWidget {
  const PrivacyPage({super.key, required this.email});

  final String email;

  static Future<void> open(BuildContext context, String email) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => PrivacyPage(email: email)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = TidyColors.of(context);
    final t = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        foregroundColor: c.fg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Semantics(
          header: true,
          child: Text(t.privacy, style: tx(20, w: 800, color: c.fg)),
        ),
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  // The policy text already ends with the support e-mail.
                  SelectableText(
                    t.privacyText,
                    style: tx(15, color: c.fg, height: 1.5),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
