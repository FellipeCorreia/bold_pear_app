import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../app/app_state.dart';
import '../../../core/i18n/l10n.dart';
import '../../../core/theme/pi_cores.dart';
import '../../checkin/domain/checkin.dart';
import '../../checkin/domain/score_alert.dart';
import '../../dashboard/presentation/widgets/trend_chart.dart';
import '../domain/astronaut.dart';
import 'admin_controller.dart';
import 'admin_dashboard_page.dart' show AdminScaffold;
import 'admin_strings.dart';
import 'widgets/admin_widgets.dart';

/// Ficha de um astronauta: perfil, estatísticas, alertas, evolução e histórico.
class AdminUserPage extends StatefulWidget {
  const AdminUserPage({super.key, required this.id});
  final String id;

  @override
  State<AdminUserPage> createState() => _AdminUserPageState();
}

class _AdminUserPageState extends State<AdminUserPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final c = context.read<AdminController>();
      if (!c.loaded) c.load(); // aberto direto pela URL (web)
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final c = context.watch<AdminController>();
    final a = AdminText(app.lang);
    final loc = kAdminLocales[app.lang]!;
    final x = c.byId(widget.id);
    return AdminScaffold(
      a: a,
      locale: loc,
      loading: c.loading,
      updatedAt: c.updatedAt,
      onRefresh: c.loading ? null : c.load,
      leading: IconButton(
        tooltip: a('back'),
        onPressed: () => context.canPop() ? context.pop() : context.go('/admin'),
        icon: const Icon(Icons.arrow_back_rounded),
      ),
      body: x == null
          ? Center(
              child: c.loaded || c.error != null
                  ? Text(a(c.error != null ? 'errorLoad' : 'notFound'), style: const TextStyle(fontWeight: FontWeight.w700))
                  : const CircularProgressIndicator(),
            )
          : _Body(x: x, a: a, t: app.t, loc: loc),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.x, required this.a, required this.t, required this.loc});
  final Astronaut x;
  final AdminText a;
  final L10n t;
  final String loc;

  @override
  Widget build(BuildContext context) {
    final l = x.last;
    final dfLong = DateFormat.yMMMd(loc).add_Hm();
    final dfDay = DateFormat.yMMMd(loc);
    final chrono = x.checkins.reversed.toList();
    final langName = {for (final (k, v) in kLanguages) k: v};
    final u = x.user;
    final diffOpts = ((t.scales['phq'] as Map)['diffOpts'] as List).cast<String>();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1240),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              // Cabeçalho da ficha.
              Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Semantics(
                      header: true,
                      child: Text(x.name, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
                    ),
                    SelectableText(u.email, style: const TextStyle(color: PiCores.textoSuave, fontWeight: FontWeight.w700)),
                  ]),
                ),
                RiskChip(x.risk, a),
              ]),
              const SizedBox(height: 16),
              if (l != null && l.item9Positive) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: PiCores.alertaFundo,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: PiCores.bandas[4], width: 1.5),
                  ),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(Icons.health_and_safety_rounded, color: PiCores.bandas[4]),
                    const SizedBox(width: 10),
                    Expanded(child: Text(a('safetyNote'), style: const TextStyle(fontWeight: FontWeight.w800, height: 1.4))),
                  ]),
                ),
                const SizedBox(height: 16),
              ],
              ResponsiveGrid(minWidth: 220, children: [
                StatTile(
                  icon: Icons.mood_rounded,
                  label: a('sLastPhq'),
                  value: l == null ? '—' : '${l.phqTotal}/27',
                  sub: l == null
                      ? null
                      : '${t.uiList('bandsPhq')[l.phqBand]} · ${a('sRange', {'m': fmt1(x.avgPhq), 'a': '${x.minPhq}', 'b': '${x.maxPhq}'})}',
                  color: l == null ? null : PiCores.bandas[l.phqBand],
                ),
                StatTile(
                  icon: Icons.psychology_alt_rounded,
                  label: a('sLastGad'),
                  value: l == null ? '—' : '${l.gadTotal}/21',
                  sub: l == null
                      ? null
                      : '${t.uiList('bandsGad')[l.gadBand]} · ${a('sRange', {'m': fmt1(x.avgGad), 'a': '${x.minGad}', 'b': '${x.maxGad}'})}',
                  color: l == null ? null : PiCores.bandas[l.gadBand == 3 ? 4 : l.gadBand],
                ),
                StatTile(
                  icon: Icons.trending_up_rounded,
                  label: a('sDeltaPhq'),
                  value: signed(x.phqDelta),
                  sub: a('sDeltaSub'),
                  color: (x.phqDelta ?? 0) > 0 ? PiCores.bochecha : null,
                ),
                StatTile(
                  icon: Icons.trending_up_rounded,
                  label: a('sDeltaGad'),
                  value: signed(x.gadDelta),
                  sub: a('sDeltaSub'),
                  color: (x.gadDelta ?? 0) > 0 ? PiCores.bochecha : null,
                ),
                StatTile(
                  icon: Icons.schedule_rounded,
                  label: a('sSince'),
                  value: x.daysSinceLast == null ? '—' : a('days', {'n': '${x.daysSinceLast}'}),
                  sub: x.nextDue == null ? null : a('sSinceSub', {'d': dfDay.format(x.nextDue!)}),
                  color: x.last != null && x.overdue ? PiCores.tagTexto : null,
                ),
                StatTile(
                  icon: Icons.event_repeat_rounded,
                  label: a('sAdh'),
                  value: '${(x.adherence * 100).round()}%',
                  sub: a('sAdhSub', {'n': '${x.checkinsInWindow}'}),
                ),
                StatTile(
                  icon: Icons.fact_check_rounded,
                  label: a('sTotal'),
                  value: '${x.checkins.length}',
                  sub: x.checkins.isEmpty ? null : a('sTotalSub', {'d': dfDay.format(x.checkins.last.createdAt)}),
                ),
                StatTile(
                  icon: Icons.work_history_rounded,
                  label: a('sImpact'),
                  value: l?.phqDifficulty == null ? '—' : diffOpts[l!.phqDifficulty!],
                  sub: a('sImpactSub'),
                ),
              ]),
              const SizedBox(height: 16),
              ResponsiveGrid(minWidth: 460, maxCols: 2, gap: 16, children: [
                AdminPanel(
                  title: a('profile'),
                  child: Column(children: [
                    _Info(a('email'), u.email),
                    _Info(a('language'), langName[u.language] ?? u.language),
                    _Info(a('voice'), a(u.voiceGender == 'm' ? 'voiceM' : 'voiceF')),
                    _Info(a('address'), a(u.addressForm == 'f' ? 'addrF' : 'addrM')),
                    _Info(a('signup'), dfLong.format(u.createdAt)),
                    _Info(a('lastLogin'), u.lastSignInAt == null ? a('never') : dfLong.format(u.lastSignInAt!)),
                    _Info(a('onboarding'), a(u.onboarded ? 'yes' : 'no')),
                    _Info(a('id'), u.id, mono: true),
                  ]),
                ),
                AdminPanel(
                  title: a('alerts'),
                  child: _Alerts(x: x, a: a, t: t),
                ),
              ]),
              const SizedBox(height: 16),
              if (x.checkins.isEmpty)
                AdminPanel(
                  title: a('evolution'),
                  child: Text(a('noCheckins'), style: const TextStyle(color: PiCores.textoSuave)),
                )
              else ...[
                ResponsiveGrid(minWidth: 460, maxCols: 2, gap: 16, children: [
                  AdminPanel(
                    title: '${a('evolution')} · ${t.ui('phqName')}',
                    child: TrendChart(
                      points: [for (final c in chrono) (c.createdAt, c.phqTotal)],
                      max: 27,
                      cuts: Scoring.phqCuts,
                      locale: loc,
                    ),
                  ),
                  AdminPanel(
                    title: '${a('evolution')} · ${t.ui('gadName')}',
                    child: TrendChart(
                      points: [for (final c in chrono) (c.createdAt, c.gadTotal)],
                      max: 21,
                      cuts: Scoring.gadCuts,
                      locale: loc,
                    ),
                  ),
                  AdminPanel(
                    title: a('itemsPhq'),
                    subtitle: a('itemsLegend'),
                    child: ItemBars(
                      labels: t.alertItems('phqItems'),
                      values: [for (final v in l!.phqItems) v.toDouble()],
                      reference: x.itemMeans((c) => c.phqItems, 9),
                    ),
                  ),
                  AdminPanel(
                    title: a('itemsGad'),
                    subtitle: a('itemsLegend'),
                    child: ItemBars(
                      labels: t.alertItems('gadItems'),
                      values: [for (final v in l.gadItems) v.toDouble()],
                      reference: x.itemMeans((c) => c.gadItems, 7),
                    ),
                  ),
                ]),
                const SizedBox(height: 16),
                AdminPanel(
                  title: '${a('history')} · ${x.checkins.length}',
                  child: Column(children: [
                    for (var i = 0; i < x.checkins.length; i++)
                      _HistoryTile(
                        c: x.checkins[i],
                        prev: i + 1 < x.checkins.length ? x.checkins[i + 1] : null,
                        t: t,
                        a: a,
                        df: dfLong,
                        diffOpts: diffOpts,
                        langName: langName,
                      ),
                  ]),
                ),
              ],
            ]),
          ),
        ),
      ],
    );
  }
}

class _Info extends StatelessWidget {
  const _Info(this.label, this.value, {this.mono = false});
  final String label;
  final String value;
  final bool mono;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            width: 130,
            child: Text(label, style: const TextStyle(color: PiCores.textoSuave, fontWeight: FontWeight.w700)),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: mono ? 12 : 14, fontFamily: mono ? 'monospace' : null),
            ),
          ),
        ]),
      );
}

class _Alerts extends StatelessWidget {
  const _Alerts({required this.x, required this.a, required this.t});
  final Astronaut x;
  final AdminText a;
  final L10n t;

  @override
  Widget build(BuildContext context) {
    final l = x.last;
    if (l == null) return Text(a('noCheckins'), style: const TextStyle(color: PiCores.textoSuave));
    final notes = <String>[
      if ((x.phqDelta ?? 0) >= Astronaut.worseningDelta) a('worseningNote', {'n': '${x.phqDelta}', 's': 'PHQ-9'}),
      if ((x.gadDelta ?? 0) >= Astronaut.worseningDelta) a('worseningNote', {'n': '${x.gadDelta}', 's': 'GAD-7'}),
    ];
    if (x.alerts.isEmpty && notes.isEmpty) {
      return Row(children: [
        Icon(Icons.check_circle_rounded, color: PiCores.bandas[0]),
        const SizedBox(width: 8),
        Expanded(child: Text(a('noAlerts'), style: const TextStyle(fontWeight: FontWeight.w700))),
      ]);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (final al in x.alerts) _alert(al),
      for (final n in notes)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(children: [
            const Icon(Icons.trending_up_rounded, color: PiCores.laranja, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(n, style: const TextStyle(fontWeight: FontWeight.w700))),
          ]),
        ),
    ]);
  }

  Widget _alert(ScoreAlert al) {
    final items = t.alertItems(al.scale == AlertScale.phq ? 'phqItems' : 'gadItems');
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: PiCores.alertaFundo,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: PiCores.laranja.withValues(alpha: .6)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(t.alert(al.scale == AlertScale.phq ? 'headPhq' : 'headGad'),
            style: const TextStyle(fontWeight: FontWeight.w900, color: PiCores.tagTexto)),
        const SizedBox(height: 4),
        Text(t.alert('score', vars: {'n': '${al.total}', 'c': '${al.cutoff}'}), style: const TextStyle(fontWeight: FontWeight.w700)),
        if (al.hasHistory)
          Text(t.alert('prevMean', vars: {'m': fmt1(al.previousMean)}), style: const TextStyle(color: PiCores.textoSuave)),
        const SizedBox(height: 8),
        if (!al.hasHistory) Text(t.alert('noHistory'), style: const TextStyle(color: PiCores.textoSuave)),
        if (al.hasHistory && al.deviations.isEmpty) Text(t.alert('noDeviation'), style: const TextStyle(color: PiCores.textoSuave)),
        if (al.hasHistory && al.deviations.isNotEmpty)
          Text(t.alert('devTitle'), style: const TextStyle(fontWeight: FontWeight.w800)),
        for (final d in al.deviations)
          Text(
            '• ${al.hasHistory ? t.alert('devLine', vars: {'item': items[d.item], 'v': '${d.value}', 'b': fmt1(d.baseline)}) : t.alert('highLine', vars: {'item': items[d.item], 'v': '${d.value}'})}',
          ),
      ]),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({
    required this.c,
    required this.prev,
    required this.t,
    required this.a,
    required this.df,
    required this.diffOpts,
    required this.langName,
  });
  final Checkin c;
  final Checkin? prev;
  final L10n t;
  final AdminText a;
  final DateFormat df;
  final List<String> diffOpts;
  final Map<String, String> langName;

  @override
  Widget build(BuildContext context) {
    final dPhq = prev == null ? null : c.phqTotal - prev!.phqTotal;
    final dGad = prev == null ? null : c.gadTotal - prev!.gadTotal;
    final phqLabels = t.alertItems('phqItems');
    final gadLabels = t.alertItems('gadItems');
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: PiCores.fundo2,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: ExpansionTile(
          shape: const Border(),
          collapsedShape: const Border(),
          leading: c.item9Positive ? Icon(Icons.health_and_safety_rounded, color: PiCores.bandas[4]) : null,
          title: Text(
            'PHQ-9 ${c.phqTotal} (${signed(dPhq)}) · GAD-7 ${c.gadTotal} (${signed(dGad)})',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          subtitle: Text(
            '${df.format(c.createdAt)} · ${t.uiList('bandsPhq')[c.phqBand]} / ${t.uiList('bandsGad')[c.gadBand]} · ${langName[c.language] ?? c.language}',
            style: const TextStyle(fontSize: 12, color: PiCores.textoSuave),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          children: [
            LayoutBuilder(builder: (context, box) {
              final phq = ItemBars(labels: phqLabels, values: [for (final v in c.phqItems) v.toDouble()]);
              final gad = ItemBars(labels: gadLabels, values: [for (final v in c.gadItems) v.toDouble()]);
              final impact = c.phqDifficulty == null
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('${a('sImpact')}: ${diffOpts[c.phqDifficulty!]}', style: const TextStyle(fontWeight: FontWeight.w700)),
                    );
              if (box.maxWidth < 760) {
                return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const Text('PHQ-9', style: TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  phq,
                  const SizedBox(height: 8),
                  const Text('GAD-7', style: TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  gad,
                  impact,
                ]);
              }
              return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    const Text('PHQ-9', style: TextStyle(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 6),
                    phq,
                    impact,
                  ]),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    const Text('GAD-7', style: TextStyle(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 6),
                    gad,
                  ]),
                ),
              ]);
            }),
          ],
        ),
      ),
    );
  }
}
