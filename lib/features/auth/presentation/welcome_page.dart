import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../app/app_state.dart';
import '../../../core/i18n/l10n.dart';
import '../../../core/widgets/ui.dart';

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});
  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  @override
  void initState() {
    super.initState();
    // No navegador a fala só é liberada após um toque; no celular a pera já cumprimenta.
    if (!kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final app = context.read<AppState>();
        app.voice.say(app.t.pear('welcome'), expr: 'happy');
      });
    }
  }

  /// Escolher o idioma já leva para o login (que tem o atalho para criar conta).
  Future<void> _pickLang(String l) async {
    final app = context.read<AppState>();
    await app.setLang(l);
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final t = app.t;
    return PageBody(children: [
      const TitleText('Language · Idioma · Sprache · Langue · 言語'),
      LeadText(t.ui('welcomeBody')),
      for (final (code, name) in kLanguages)
        OptionButton(
          label: name,
          badge: code.toUpperCase(),
          selected: app.lang == code,
          locale: Locale(code),
          onTap: () => _pickLang(code),
        ),
    ]);
  }
}
