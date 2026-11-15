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

  Future<void> _pickLang(String l) async {
    final app = context.read<AppState>();
    await app.setLang(l);
    if (!mounted) return;
    app.voice.say('${app.t.pear('hello')} ${app.t.pear('welcome')}', expr: 'happy');
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final t = app.t;
    return PageBody(children: [
      const TitleText('Idioma · Language · Sprache · Langue · 言語'),
      LeadText(t.ui('welcomeBody')),
      for (final (code, name) in kLanguages)
        OptionButton(
          label: name,
          badge: code.toUpperCase(),
          selected: app.lang == code,
          onTap: () => _pickLang(code),
        ),
      const SizedBox(height: 12),
      FilledButton(onPressed: () => context.go('/signup'), child: Text(t.ui('createAccount'))),
      const SizedBox(height: 10),
      OutlinedButton(onPressed: () => context.go('/login'), child: Text(t.ui('haveAccount'))),
    ]);
  }
}
