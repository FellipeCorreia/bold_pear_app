import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../app/app_state.dart';
import '../../../core/theme/pi_cores.dart';
import '../../../core/widgets/ui.dart';
import '../domain/checkin.dart';
import 'checkin_controller.dart';
import 'widgets/alert_panel.dart';
import 'widgets/score_meter.dart';

class ResultsPage extends StatefulWidget {
  const ResultsPage({super.key});
  @override
  State<ResultsPage> createState() => _ResultsPageState();
}

class _ResultsPageState extends State<ResultsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final c = context.read<CheckinController>();
      if (c.last == null) {
        context.go('/home');
      } else {
        c.speakSummary();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<CheckinController>();
    final app = context.watch<AppState>();
    final t = app.t;
    final r = c.last;
    if (r == null) return const SizedBox.shrink();
    final lv = r.level;
    final tips = <String>[
      if (lv == 'calm') t.ui('sCalm'),
      if (r.phqTotal >= 5) ...[t.ui('sPhq'), t.ui('sPhq2')],
      if (r.gadTotal >= 5) ...[t.ui('sGad'), t.ui('sGad2')],
      if (lv == 'high') t.ui('sHigh'),
    ];
    final diffOpts = ((t.scales['phq'] as Map)['diffOpts'] as List).cast<String>();
    return PageBody(children: [
      TitleText(t.ui('resultsTitle')),
      if (c.saveFailed)
        Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: const Color(0xFF3A3420), borderRadius: BorderRadius.circular(14)),
          child: Text(t.ui('errGeneric'), style: const TextStyle(color: Color(0xFFF3DC8A), fontWeight: FontWeight.w700)),
        ),
      if (r.item9Positive)
        Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: Panel(
            color: PiCores.alertaFundo,
            borderColor: PiCores.bochecha,
            padding: const EdgeInsets.all(18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t.ui('safetyTitle'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Text(t.ui('safetyBody'), style: const TextStyle(height: 1.5)),
            ]),
          ),
        ),
      AlertPanel(alerts: c.alerts, t: t),
      Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          ScoreMeter(
            title: t.ui('phqName'),
            score: r.phqTotal,
            max: 27,
            cuts: Scoring.phqCuts,
            labels: t.uiList('bandsPhq'),
            attention: Scoring.phqAttention(app.lang),
            attentionLabel: t.ui('attn'),
          ),
          ScoreMeter(
            title: t.ui('gadName'),
            score: r.gadTotal,
            max: 21,
            cuts: Scoring.gadCuts,
            labels: t.uiList('bandsGad'),
            attention: Scoring.gadAttention,
            attentionLabel: t.ui('attn'),
          ),
          if (r.phqDifficulty != null)
            Text.rich(TextSpan(children: [
              TextSpan(text: '${t.ui('impact')}: ', style: const TextStyle(fontWeight: FontWeight.w800)),
              TextSpan(text: diffOpts[r.phqDifficulty!]),
            ])),
          if (app.lang == 'pt')
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(t.ui('brNote'), style: const TextStyle(fontSize: 13, color: PiCores.textoSuave)),
            ),
        ]),
      ),
      SectionLabel(t.ui('suggestTitle')),
      for (final tip in tips)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Padding(
              padding: EdgeInsets.only(top: 7, right: 10),
              child: Icon(Icons.circle, size: 7, color: PiCores.lima),
            ),
            Expanded(child: Text(tip, style: const TextStyle(height: 1.45))),
          ]),
        ),
      const SizedBox(height: 14),
      FilledButton.icon(
        onPressed: () => context.push('/breathe'),
        icon: const Icon(Icons.air_rounded),
        label: Text(t.ui('breathe')),
      ),
      const SizedBox(height: 10),
      OutlinedButton(
        onPressed: () {
          c.cancel();
          context.go('/home');
        },
        child: Text(t.ui('done')),
      ),
      const SizedBox(height: 14),
      Text('${t.ui('disclaimer')} ${t.ui('provisional')}',
          style: const TextStyle(fontSize: 13, color: PiCores.textoSuave, height: 1.45)),
    ]);
  }
}
