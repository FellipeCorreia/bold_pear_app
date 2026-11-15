import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../app/app_state.dart';
import '../../../core/theme/pi_cores.dart';
import '../../../core/widgets/space_background.dart';
import '../../../core/widgets/ui.dart';
import '../../avatar/pear_controller.dart';
import 'checkin_controller.dart';

/// As perguntas são faladas pela pera; a tela mostra só as opções de resposta.
class CheckinPage extends StatefulWidget {
  const CheckinPage({super.key});
  @override
  State<CheckinPage> createState() => _CheckinPageState();
}

class _CheckinPageState extends State<CheckinPage> {
  late final CheckinController _c;
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _c = context.read<CheckinController>();
    _c.addListener(_onChange);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_c.stage != CheckinStage.running) _c.start();
      _focus.requestFocus();
    });
  }

  void _onChange() {
    if (_c.stage == CheckinStage.finished && mounted) context.go('/results');
  }

  @override
  void dispose() {
    _c.removeListener(_onChange);
    _focus.dispose();
    super.dispose();
  }

  void _quit() {
    _c.cancel();
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<CheckinController>();
    final talking = context.watch<PearController>().talking;
    final t = context.watch<AppState>().t;
    if (c.stage != CheckinStage.running) return const SizedBox.shrink();
    final q = c.current;
    final yourTurn = !talking && !c.busy;
    return KeyboardListener(
      focusNode: _focus,
      onKeyEvent: (e) {
        if (e is! KeyDownEvent) return;
        final k = int.tryParse(e.character ?? '');
        if (k != null && k >= 1 && k <= q.options.length && !c.busy) {
          context.read<SkyController>().travel();
          c.answer(k - 1);
        }
      },
      child: PageBody(children: [
        Row(children: [
          Text(q.label, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          const Spacer(),
          Text('${q.index + 1}/${q.count}', style: const TextStyle(color: PiCores.textoSuave, fontWeight: FontWeight.w800)),
          IconButton(onPressed: _quit, icon: const Icon(Icons.close_rounded, color: PiCores.textoSuave)),
        ]),
        Row(children: [
          for (var i = 0; i < q.count; i++)
            Expanded(
              child: Container(
                height: 6,
                margin: EdgeInsets.only(right: i < q.count - 1 ? 5 : 0),
                decoration: BoxDecoration(
                  color: i < q.index ? PiCores.lima : i == q.index ? PiCores.laranja : PiCores.borda,
                  borderRadius: BorderRadius.circular(9),
                ),
              ),
            ),
        ]),
        const SizedBox(height: 16),
        Row(children: [
          Icon(yourTurn ? Icons.touch_app_rounded : Icons.graphic_eq_rounded,
              size: 20, color: yourTurn ? PiCores.lima : PiCores.textoSuave),
          const SizedBox(width: 8),
          Text(t.ui(yourTurn ? 'yourTurn' : 'speaking'),
              style: TextStyle(fontWeight: FontWeight.w800, color: yourTurn ? PiCores.lima : PiCores.textoSuave)),
        ]),
        const SizedBox(height: 14),
        for (var k = 0; k < q.options.length; k++)
          OptionButton(
            badge: '${k + 1}',
            label: q.options[k],
            enabled: !c.busy,
            onTap: () {
              context.read<SkyController>().travel();
              c.answer(k);
            },
          ),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: c.busy || talking ? null : c.repeat,
            icon: const Icon(Icons.replay_rounded),
            label: Text(t.ui('repeat')),
          ),
        ),
      ]),
    );
  }
}
