import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../app/app_state.dart';
import '../../../core/theme/pi_cores.dart';
import '../../../core/widgets/ui.dart';

/// Primeiro acesso: aviso "sou só um programa", voz da pera, nome e forma de tratamento.
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});
  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  int _step = 0;
  String? _gender;
  String _addr = 'm';
  late final TextEditingController _name;

  @override
  void initState() {
    super.initState();
    final app = context.read<AppState>();
    _name = TextEditingController(text: app.profile?.displayName ?? '');
    WidgetsBinding.instance.addPostFrameCallback((_) => _speakStep());
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _speakStep() {
    final app = context.read<AppState>();
    final t = app.t;
    switch (_step) {
      case 0:
        app.voice.say(t.ui('privacyBody'), expr: 'neutral');
      case 2:
        app.voice.say(t.pear('askName'), expr: 'neutral');
    }
  }

  void _go(int step) {
    setState(() => _step = step);
    _speakStep();
  }

  Future<void> _pickGender(String g) async {
    final app = context.read<AppState>();
    setState(() => _gender = g);
    await app.previewGender(g);
    if (!mounted) return;
    app.voice.say(app.t.f(app.t.pear('meet')), expr: 'happy');
  }

  Future<void> _finish() async {
    final app = context.read<AppState>();
    await app.voice.stop();
    await app.updateProfile(
      displayName: _name.text.trim(),
      voiceGender: _gender ?? 'f',
      addressForm: _addr,
      language: app.lang,
      onboarded: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final t = app.t;
    final askAddress = app.lang == 'pt' || app.lang == 'fr';
    final steps = <Widget>[
      // 0 — transparência: ninguém está ouvindo ao vivo.
      Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          TitleText(t.ui('privacyTitle')),
          Text(t.ui('privacyBody'), style: const TextStyle(fontSize: 17, height: 1.5, fontWeight: FontWeight.w600)),
          const SizedBox(height: 20),
          FilledButton(onPressed: () => _go(1), child: Text(t.ui('privacyAck'))),
        ]),
      ),
      // 1 — voz da pera.
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TitleText(t.ui('avatarTitle')),
        LeadText(t.ui('avatarHint')),
        OptionButton(label: t.ui('fem'), selected: _gender == 'f', onTap: () => _pickGender('f')),
        OptionButton(label: t.ui('masc'), selected: _gender == 'm', onTap: () => _pickGender('m')),
        const SizedBox(height: 8),
        FilledButton(onPressed: _gender == null ? null : () => _go(2), child: Text(t.ui('next'))),
        TextButton(onPressed: () => _go(0), child: Text(t.ui('back'))),
      ]),
      // 2 — nome e tratamento.
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TitleText(t.ui('nameQ')),
        TextField(controller: _name, decoration: InputDecoration(labelText: t.ui('name'))),
        if (askAddress) ...[
          const SizedBox(height: 20),
          Text(t.ui('addrQ'), style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          OptionButton(label: t.ui('addrM'), selected: _addr == 'm', onTap: () => setState(() => _addr = 'm')),
          OptionButton(label: t.ui('addrF'), selected: _addr == 'f', onTap: () => setState(() => _addr = 'f')),
        ],
        const SizedBox(height: 16),
        FilledButton(onPressed: _finish, child: Text(t.ui('next'))),
        TextButton(onPressed: () => _go(1), child: Text(t.ui('back'))),
      ]),
    ];
    return PageBody(children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(
          3,
          (i) => AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
            width: i == _step ? 28 : 10,
            height: 8,
            decoration: BoxDecoration(
              color: i <= _step ? PiCores.lima : PiCores.borda,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
      steps[_step],
    ]);
  }
}
