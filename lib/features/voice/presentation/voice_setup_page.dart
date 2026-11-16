import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../app/app_state.dart';
import '../../../core/theme/pi_cores.dart';
import '../../../core/widgets/ui.dart';
import '../neural/neural_voice.dart';

/// Primeira abertura: baixa a voz neural da pera antes da escolha de idioma.
/// Quando termina, as rotas seguem sozinhas para as boas-vindas.
class VoiceSetupPage extends StatelessWidget {
  const VoiceSetupPage({super.key});

  static String _mb(int bytes) => (bytes / 1048576).toStringAsFixed(0);

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final t = app.t;
    final n = app.voice.neural;
    return PageBody(children: [
      TitleText(t.ui('setupTitle')),
      LeadText(t.ui('setupBody').replaceAll('{mb}', _mb(NeuralVoice.totalBytes))),
      ValueListenableBuilder<NeuralVoiceStatus>(
        valueListenable: n.status,
        builder: (context, st, _) {
          if (st == NeuralVoiceStatus.error) {
            return Panel(
              borderColor: PiCores.bochecha,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(Icons.wifi_off_rounded, color: PiCores.bochecha),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Semantics(
                      liveRegion: true,
                      child: Text(t.ui('setupError'), style: const TextStyle(fontWeight: FontWeight.w700, height: 1.4)),
                    ),
                  ),
                ]),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: n.retry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(t.ui('setupRetry')),
                ),
                const SizedBox(height: 10),
                OutlinedButton(onPressed: app.skipVoiceSetup, child: Text(t.ui('setupSkip'))),
              ]),
            );
          }
          return Panel(
            child: ValueListenableBuilder<double>(
              valueListenable: n.progress,
              builder: (context, p, _) {
                final pct = (p * 100).floor().clamp(0, 100);
                final label = t
                    .ui('setupProgress')
                    .replaceAll('{a}', _mb(n.downloadedBytes))
                    .replaceAll('{b}', _mb(NeuralVoice.totalBytes))
                    .replaceAll('{p}', '$pct');
                return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: [
                    const Icon(Icons.download_rounded, color: PiCores.lima),
                    const SizedBox(width: 10),
                    Expanded(child: Text(label, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900))),
                  ]),
                  const SizedBox(height: 14),
                  Semantics(
                    label: t.ui('setupTitle'),
                    value: '$pct%',
                    child: LinearProgressIndicator(
                      // Antes do primeiro byte (conectando), barra indeterminada.
                      value: n.downloadedBytes == 0 ? null : p,
                      minHeight: 12,
                      color: PiCores.lima,
                      backgroundColor: PiCores.borda,
                      borderRadius: BorderRadius.circular(9),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(children: [
                    const Icon(Icons.wifi_rounded, size: 18, color: PiCores.textoSuave),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(t.ui('setupWifi'), style: const TextStyle(color: PiCores.textoSuave, fontWeight: FontWeight.w600)),
                    ),
                  ]),
                ]);
              },
            ),
          );
        },
      ),
    ]);
  }
}
