import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/i18n/l10n.dart';
import '../../../../core/theme/pi_cores.dart';
import '../../../../core/widgets/ui.dart';
import '../../domain/score_alert.dart';

/// Mostra os alertas de limite. Apenas detecção e aviso: sem sugestões nem ações.
class AlertPanel extends StatelessWidget {
  const AlertPanel({super.key, required this.alerts, required this.t});

  final List<ScoreAlert> alerts;
  final L10n t;

  static const _intl = {'pt': 'pt_BR', 'en': 'en_US', 'de': 'de_DE', 'fr': 'fr_FR', 'ja': 'ja_JP'};

  @override
  Widget build(BuildContext context) {
    if (alerts.isEmpty) return const SizedBox.shrink();
    final num1 = NumberFormat('0.0', _intl[t.lang]);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (final a in alerts)
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Panel(
            color: PiCores.alertaFundo,
            borderColor: PiCores.laranja,
            padding: const EdgeInsets.all(18),
            child: _AlertBody(alert: a, t: t, fmt: num1),
          ),
        ),
    ]);
  }
}

class _AlertBody extends StatelessWidget {
  const _AlertBody({required this.alert, required this.t, required this.fmt});

  final ScoreAlert alert;
  final L10n t;
  final NumberFormat fmt;

  @override
  Widget build(BuildContext context) {
    final a = alert;
    final isPhq = a.scale == AlertScale.phq;
    final labels = t.alertItems(isPhq ? 'phqItems' : 'gadItems');
    const muted = TextStyle(color: PiCores.textoSuave, height: 1.45);
    Widget line(String text) => Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Padding(
              padding: EdgeInsets.only(top: 7, right: 10),
              child: Icon(Icons.circle, size: 7, color: PiCores.laranja),
            ),
            Expanded(child: Text(text, style: const TextStyle(height: 1.45, fontWeight: FontWeight.w600))),
          ]),
        );

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(Icons.warning_amber_rounded, color: PiCores.laranja),
        const SizedBox(width: 8),
        Expanded(
          child: Text(t.alert(isPhq ? 'headPhq' : 'headGad'),
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
        ),
      ]),
      const SizedBox(height: 6),
      Text(
        '${isPhq ? 'PHQ-9' : 'GAD-7'} · ${t.alert('score', vars: {'n': '${a.total}', 'c': '${a.cutoff}'})}',
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      if (a.hasHistory) Text(t.alert('prevMean', vars: {'m': fmt.format(a.previousMean)}), style: muted),
      const SizedBox(height: 10),
      if (!a.hasHistory) ...[
        Text(t.alert('noHistory'), style: muted),
        for (final d in a.deviations)
          line(t.alert('highLine', vars: {'item': labels[d.item], 'v': '${d.value}'})),
      ] else if (a.deviations.isEmpty)
        Text(t.alert('noDeviation'), style: muted)
      else ...[
        Text(t.alert('devTitle'), style: const TextStyle(fontWeight: FontWeight.w800)),
        for (final d in a.deviations)
          line(t.alert('devLine', vars: {
            'item': labels[d.item],
            'v': '${d.value}',
            'b': fmt.format(d.baseline),
          })),
      ],
    ]);
  }
}
