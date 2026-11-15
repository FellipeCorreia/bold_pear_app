import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../app/app_state.dart';
import '../../../core/i18n/l10n.dart';
import '../../../core/theme/pi_cores.dart';
import '../../../core/widgets/ui.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final TextEditingController _name;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: context.read<AppState>().profile?.displayName ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _saveName() async {
    final app = context.read<AppState>();
    await app.updateProfile(displayName: _name.text.trim());
    if (!mounted) return;
    showMessage(context, app.t.ui('saved'));
    app.voice.say(app.t.pear('saved'), expr: 'happy');
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final t = app.t;
    final p = app.profile;
    final askAddress = app.lang == 'pt' || app.lang == 'fr';
    return PageBody(children: [
      Row(children: [
        IconButton(
          onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        Expanded(child: TitleText(t.ui('settings'))),
      ]),
      TextField(
        controller: _name,
        decoration: InputDecoration(labelText: t.ui('name')),
        onSubmitted: (_) => _saveName(),
      ),
      const SizedBox(height: 10),
      Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton(onPressed: _saveName, child: Text(t.ui('save'))),
      ),
      SectionLabel(t.ui('language')),
      for (final (code, name) in kLanguages)
        OptionButton(
          label: name,
          badge: code.toUpperCase(),
          selected: app.lang == code,
          onTap: () async {
            await app.setLang(code);
            app.voice.say(app.t.pear('hello'), expr: 'happy');
          },
        ),
      SectionLabel(t.ui('voice')),
      OptionButton(
        label: t.ui('fem'),
        selected: p?.voiceGender == 'f',
        onTap: () async {
          await app.updateProfile(voiceGender: 'f');
          app.voice.say(app.t.pear('meet'), expr: 'happy');
        },
      ),
      OptionButton(
        label: t.ui('masc'),
        selected: p?.voiceGender == 'm',
        onTap: () async {
          await app.updateProfile(voiceGender: 'm');
          app.voice.say(app.t.pear('meet'), expr: 'happy');
        },
      ),
      if (askAddress) ...[
        SectionLabel(t.ui('addrQ')),
        OptionButton(label: t.ui('addrM'), selected: p?.addressForm == 'm', onTap: () => app.updateProfile(addressForm: 'm')),
        OptionButton(label: t.ui('addrF'), selected: p?.addressForm == 'f', onTap: () => app.updateProfile(addressForm: 'f')),
      ],
      SectionLabel(t.ui('subtitles')),
      SwitchListTile(
        value: app.cc,
        onChanged: (_) => app.toggleCc(),
        title: Text(t.ui('subtitles')),
        contentPadding: EdgeInsets.zero,
        activeThumbColor: PiCores.lima,
      ),
      const SizedBox(height: 18),
      Panel(
        padding: const EdgeInsets.all(18),
        child: Text(t.ui('privacyBody'), style: const TextStyle(color: PiCores.textoSuave, height: 1.5)),
      ),
      const SizedBox(height: 18),
      OutlinedButton.icon(
        onPressed: app.logout,
        icon: const Icon(Icons.logout_rounded),
        label: Text(t.ui('logout')),
      ),
      const SizedBox(height: 12),
      Text(t.ui('disclaimer'), style: const TextStyle(fontSize: 13, color: PiCores.textoSuave)),
    ]);
  }
}
