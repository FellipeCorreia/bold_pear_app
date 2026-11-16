import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../app/app_state.dart';
import '../../../core/i18n/l10n.dart';
import '../../../core/theme/pi_cores.dart';
import '../../../core/widgets/ui.dart';
import '../../voice/neural/neural_voice.dart';
import '../../voice/voice_service.dart';

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
      const SizedBox(height: 14),
      _NeuralVoiceTile(voice: app.voice),
      SectionLabel(t.ui('subtitles')),
      SwitchListTile(
        value: app.cc,
        onChanged: (_) => app.toggleCc(),
        title: Text(t.ui('subtitles')),
        contentPadding: EdgeInsets.zero,
        activeThumbColor: PiCores.lima,
      ),
      SwitchListTile(
        value: app.muted,
        onChanged: (_) => app.toggleMute(),
        title: Text(t.ui('mute')),
        secondary: Icon(app.muted ? Icons.volume_off_rounded : Icons.volume_up_rounded),
        contentPadding: EdgeInsets.zero,
        activeThumbColor: PiCores.laranja,
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

/// Estado da voz neural embutida (Supertonic 3).
class _NeuralVoiceTile extends StatelessWidget {
  const _NeuralVoiceTile({required this.voice});
  final VoiceService voice;

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    final t = app.t;
    final n = voice.neural;
    return ValueListenableBuilder<NeuralVoiceStatus>(
      valueListenable: n.status,
      builder: (context, st, _) {
        final Widget action;
        switch (st) {
          case NeuralVoiceStatus.unsupported:
            action = Text(t.ui('neuralWeb'), style: const TextStyle(color: PiCores.textoSuave, fontWeight: FontWeight.w700));
          case NeuralVoiceStatus.absent:
          case NeuralVoiceStatus.installing:
            action = ValueListenableBuilder<double>(
              valueListenable: n.progress,
              builder: (context, p, _) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text(t.ui('neuralInstalling').replaceAll('{n}', '${(p * 100).round()}'),
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: p,
                  color: PiCores.lima,
                  backgroundColor: PiCores.borda,
                  borderRadius: BorderRadius.circular(9),
                ),
              ]),
            );
          case NeuralVoiceStatus.error:
            action = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(t.ui('neuralError'), style: const TextStyle(color: PiCores.bochecha, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              // Quem pulou o download na primeira abertura pode baixar a voz por aqui.
              OutlinedButton.icon(
                onPressed: n.retry,
                icon: const Icon(Icons.download_rounded),
                label: Text(t.ui('neuralRetry')),
              ),
            ]);
          case NeuralVoiceStatus.ready:
            action = Row(children: [
              const Icon(Icons.check_circle_rounded, color: PiCores.lima),
              const SizedBox(width: 8),
              Expanded(child: Text(t.ui('neuralReady'), style: const TextStyle(fontWeight: FontWeight.w800))),
            ]);
        }
        return Panel(
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              const Icon(Icons.auto_awesome_rounded, color: PiCores.laranja),
              const SizedBox(width: 10),
              Expanded(child: Text(t.ui('neuralTitle'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900))),
            ]),
            const SizedBox(height: 8),
            Text(t.ui('neuralBody'), style: const TextStyle(color: PiCores.textoSuave, height: 1.45)),
            const SizedBox(height: 14),
            action,
          ]),
        );
      },
    );
  }
}
