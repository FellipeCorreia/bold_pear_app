import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../app/app_state.dart';
import '../../../core/theme/pi_cores.dart';
import '../../../core/widgets/ui.dart';
import '../../checkin/data/checkin_repository.dart';
import '../../checkin/domain/checkin.dart';
import 'widgets/trend_chart.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});
  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late Future<List<Checkin>> _future;

  @override
  void initState() {
    super.initState();
    final app = context.read<AppState>();
    _future = CheckinRepository(app.sb).list();
    _future.then((list) {
      if (!mounted || app.greeted) return;
      app.greeted = true;
      final t = app.t;
      final due = list.isNotEmpty &&
          DateTime.now().difference(list.first.createdAt).inDays >= Scoring.checkinIntervalDays;
      app.voice.say(t.pear(list.isEmpty ? 'first' : due ? 'due' : 'dashGreet'), expr: 'happy');
    }).catchError((_) {});
  }

  String _intlLocale(String lang) => {'pt': 'pt_BR', 'en': 'en_US', 'de': 'de_DE', 'fr': 'fr_FR', 'ja': 'ja_JP'}[lang]!;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final t = app.t;
    final loc = _intlLocale(app.lang);
    return FutureBuilder<List<Checkin>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final list = snap.data ?? const <Checkin>[];
        final last = list.isEmpty ? null : list.first;
        final next = last?.createdAt.add(const Duration(days: Scoring.checkinIntervalDays));
        final daysLeft = next == null ? 0 : next.difference(DateTime.now()).inHours / 24;
        final dueNow = next == null || daysLeft <= 0;
        final chrono = list.reversed.toList();
        return PageBody(children: [
          TitleText(t.f(t.ui('dashHello'))),
          Panel(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(t.ui('nextCheckin'),
                  style: const TextStyle(fontWeight: FontWeight.w800, color: PiCores.textoSuave)),
              const SizedBox(height: 4),
              Text(
                dueNow
                    ? t.ui('dueNow')
                    : '${DateFormat.MMMMEEEEd(loc).format(next)} · ${t.f(t.ui('daysLeft'), vars: {'n': '${daysLeft.ceil()}'})}',
                style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w900, color: dueNow ? PiCores.lima : PiCores.texto),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => context.go('/checkin'),
                icon: const Icon(Icons.record_voice_over_rounded),
                label: Text(t.ui('startCheckin')),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => context.push('/breathe'),
                icon: const Icon(Icons.air_rounded),
                label: Text(t.ui('breathe')),
              ),
            ]),
          ),
          SectionLabel(t.ui('evolution')),
          if (list.isEmpty)
            LeadText(t.ui('noData'))
          else ...[
            _TrendCard(
              title: t.ui('phqName'),
              band: t.uiList('bandsPhq')[last!.phqBand],
              score: last.phqTotal,
              max: 27,
              child: TrendChart(
                points: [for (final c in chrono) (c.createdAt, c.phqTotal)],
                max: 27,
                cuts: Scoring.phqCuts,
                locale: loc,
              ),
            ),
            const SizedBox(height: 14),
            _TrendCard(
              title: t.ui('gadName'),
              band: t.uiList('bandsGad')[last.gadBand],
              score: last.gadTotal,
              max: 21,
              child: TrendChart(
                points: [for (final c in chrono) (c.createdAt, c.gadTotal)],
                max: 21,
                cuts: Scoring.gadCuts,
                locale: loc,
              ),
            ),
            SectionLabel('${t.ui('history')} · ${list.length} ${t.ui('checkins')}'),
            for (final c in list.take(8))
              Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(color: PiCores.fundo2, borderRadius: BorderRadius.circular(12)),
                child: Row(children: [
                  Expanded(
                    child: Text('PHQ-9 ${c.phqTotal} · GAD-7 ${c.gadTotal}',
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                  Text(DateFormat.MMMd(loc).add_Hm().format(c.createdAt),
                      style: const TextStyle(color: PiCores.textoSuave)),
                ]),
              ),
          ],
          const SizedBox(height: 12),
          Text(t.ui('disclaimer'), style: const TextStyle(fontSize: 13, color: PiCores.textoSuave)),
        ]);
      },
    );
  }
}

class _TrendCard extends StatelessWidget {
  const _TrendCard({required this.title, required this.band, required this.score, required this.max, required this.child});
  final String title;
  final String band;
  final int score;
  final int max;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Panel(
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              Text(band, style: const TextStyle(color: PiCores.textoSuave, fontWeight: FontWeight.w700)),
            ]),
          ),
          Text.rich(TextSpan(children: [
            TextSpan(text: '$score', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
            TextSpan(text: '/$max', style: const TextStyle(fontSize: 14, color: PiCores.textoSuave)),
          ])),
        ]),
        const SizedBox(height: 12),
        child,
      ]),
    );
  }
}
