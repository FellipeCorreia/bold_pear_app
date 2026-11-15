import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../app/app_state.dart';
import '../../../core/theme/pi_cores.dart';
import '../../../core/widgets/ui.dart';

/// Respiração quadrada guiada (4 ciclos de 4-4-4-4 s ≈ 1 min); a pera respira junto.
class BreathingPage extends StatefulWidget {
  const BreathingPage({super.key});
  @override
  State<BreathingPage> createState() => _BreathingPageState();
}

class _BreathingPageState extends State<BreathingPage> {
  String _phase = '';
  int _count = 0;
  bool _alive = true;
  late final AppState _app;

  @override
  void initState() {
    super.initState();
    _app = context.read<AppState>();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<void> _run() async {
    final t = _app.t;
    await _app.voice.say(t.pear('breatheIntro'), expr: 'happy');
    const phases = [('inhale', 1.14), ('hold', 1.14), ('exhale', 1.0), ('hold', 1.0)];
    for (var cycle = 0; cycle < 4; cycle++) {
      for (final (key, scale) in phases) {
        if (!_alive) return;
        setState(() => _phase = t.ui(key));
        _app.pear.set(breath: scale, expr: 'neutral');
        _app.voice.say(t.ui(key));
        for (var s = 4; s > 0; s--) {
          if (!_alive) return;
          setState(() => _count = s);
          await Future<void>.delayed(const Duration(seconds: 1));
        }
      }
    }
    if (!_alive) return;
    _app.pear.set(breath: 1);
    await _app.voice.say(t.pear('breatheEnd'), expr: 'happy');
    if (mounted) _close();
  }

  void _close() => context.canPop() ? context.pop() : context.go('/home');

  @override
  void dispose() {
    _alive = false;
    _app.pear.set(breath: 1);
    _app.voice.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<AppState>().t;
    return PageBody(children: [
      TitleText(t.ui('breathe')),
      const SizedBox(height: 16),
      Text(_phase.isEmpty ? '…' : _phase,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w900, color: PiCores.lima)),
      Text(_count == 0 ? '' : '$_count',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: PiCores.textoSuave)),
      const SizedBox(height: 24),
      Center(child: OutlinedButton(onPressed: _close, child: Text(t.ui('stop')))),
    ]);
  }
}
