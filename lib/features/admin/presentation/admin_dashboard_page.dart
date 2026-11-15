import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../app/app_state.dart';
import '../../../core/i18n/l10n.dart';
import '../../../core/theme/pi_cores.dart';
import '../../../core/widgets/ui.dart';
import '../domain/astronaut.dart';
import 'admin_controller.dart';
import 'admin_strings.dart';
import 'widgets/admin_widgets.dart';

enum _Filter { all, attention, overdue, noData }

enum _Sort { risk, name, last, phq, gad }

/// Painel NASA: visão geral da tripulação e lista de todos os astronautas.
class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});
  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  final _search = TextEditingController();
  var _filter = _Filter.all;
  var _sort = _Sort.risk;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final app = context.read<AppState>();
      app.voice.stop(); // o painel não tem a pera falando
      final c = context.read<AdminController>();
      if (!c.loaded) c.load();
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final c = context.watch<AdminController>();
    final a = AdminText(app.lang);
    final loc = kAdminLocales[app.lang]!;
    return AdminScaffold(
      a: a,
      onRefresh: c.loading ? null : c.load,
      updatedAt: c.updatedAt,
      loading: c.loading,
      locale: loc,
      body: () {
        final f = c.fleet;
        if (f == null) {
          if (c.error != null) return _ErrorView(a: a, onRetry: c.load);
          return const Center(child: CircularProgressIndicator());
        }
        return _content(context, app, f, a, loc);
      }(),
    );
  }

  Widget _content(BuildContext context, AppState app, FleetStats f, AdminText a, String loc) {
    final t = app.t;
    final pct = f.total == 0 ? 0 : (100 * f.active / f.total).round();
    final df = DateFormat.MMMd(loc);
    final langName = {for (final (k, v) in kLanguages) k: v};
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1240),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              ResponsiveGrid(minWidth: 220, children: [
                StatTile(
                  icon: Icons.groups_rounded,
                  label: a('kAstronauts'),
                  value: '${f.total}',
                  sub: a('kAstronautsSub', {'n': '${f.onboarded}'}),
                ),
                StatTile(
                  icon: Icons.verified_rounded,
                  label: a('kActive'),
                  value: '${f.active}',
                  sub: a('kActiveSub', {'p': '$pct'}),
                  color: PiCores.lima,
                ),
                StatTile(
                  icon: Icons.fact_check_rounded,
                  label: a('kCheckins'),
                  value: '${f.totalCheckins}',
                  sub: a('kCheckinsSub', {'n': '${f.checkins30d}'}),
                ),
                StatTile(
                  icon: Icons.schedule_rounded,
                  label: a('kOverdue'),
                  value: '${f.overdue}',
                  sub: a('kOverdueSub', {'n': '${f.noData}'}),
                  color: f.overdue > 0 ? PiCores.tagTexto : null,
                ),
                StatTile(
                  icon: Icons.warning_amber_rounded,
                  label: a('kAttention'),
                  value: '${f.attention}',
                  sub: a('kAttentionSub', {'n': '${f.worsening}'}),
                  color: f.attention > 0 ? PiCores.laranja : null,
                ),
                StatTile(
                  icon: Icons.health_and_safety_rounded,
                  label: a('kSafety'),
                  value: '${f.safety}',
                  sub: a('kSafetySub'),
                  color: f.safety > 0 ? PiCores.bandas[4] : null,
                ),
                StatTile(
                  icon: Icons.mood_rounded,
                  label: a('kPhq'),
                  value: fmt1(f.avgPhq),
                  sub: a('kLatestSub'),
                ),
                StatTile(
                  icon: Icons.psychology_alt_rounded,
                  label: a('kGad'),
                  value: fmt1(f.avgGad),
                  sub: a('kLatestSub'),
                ),
              ]),
              const SizedBox(height: 16),
              ResponsiveGrid(minWidth: 460, maxCols: 2, gap: 16, children: [
                _PriorityPanel(f: f, a: a),
                AdminPanel(
                  title: a('kAdherence'),
                  subtitle: a('kAdherenceSub'),
                  child: _AdherenceSummary(f: f),
                ),
              ]),
              const SizedBox(height: 16),
              ResponsiveGrid(minWidth: 460, maxCols: 2, gap: 16, children: [
                AdminPanel(
                  title: a('distPhq'),
                  subtitle: a('distSub', {'n': '${f.withData}'}),
                  child: BandDistribution(counts: f.phqBands, labels: t.uiList('bandsPhq'), colors: PiCores.bandas),
                ),
                AdminPanel(
                  title: a('distGad'),
                  subtitle: a('distSub', {'n': '${f.withData}'}),
                  child: BandDistribution(
                    counts: f.gadBands,
                    labels: t.uiList('bandsGad'),
                    colors: [PiCores.bandas[0], PiCores.bandas[1], PiCores.bandas[2], PiCores.bandas[4]],
                  ),
                ),
                AdminPanel(
                  title: a('weekly'),
                  subtitle: a('weeklySub'),
                  child: WeeklyBars(weeks: f.weeks, locale: loc),
                ),
                AdminPanel(
                  title: a('trend'),
                  subtitle: a('trendSub'),
                  child: MultiLineChart(
                    max: 27,
                    xLabels: [df.format(f.weeks.first.start), df.format(f.weeks.last.start)],
                    series: [
                      LineSeries('PHQ-9', PiCores.lima, [for (final w in f.weeks) w.avgPhq]),
                      LineSeries('GAD-7', PiCores.laranja, [for (final w in f.weeks) w.avgGad]),
                    ],
                  ),
                ),
                AdminPanel(
                  title: a('symptomsPhq'),
                  subtitle: a('symptomsSub'),
                  child: ItemBars(labels: t.alertItems('phqItems'), values: f.phqItemMeans),
                ),
                AdminPanel(
                  title: a('symptomsGad'),
                  subtitle: a('symptomsSub'),
                  child: ItemBars(labels: t.alertItems('gadItems'), values: f.gadItemMeans),
                ),
              ]),
              const SizedBox(height: 16),
              AdminPanel(
                title: a('profileMix'),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(a('languages'), style: const TextStyle(fontWeight: FontWeight.w800, color: PiCores.textoSuave)),
                  const SizedBox(height: 8),
                  CountPills(items: [for (final e in f.languages.entries) (langName[e.key] ?? e.key, e.value)]),
                  const SizedBox(height: 16),
                  Text(a('voices'), style: const TextStyle(fontWeight: FontWeight.w800, color: PiCores.textoSuave)),
                  const SizedBox(height: 8),
                  CountPills(items: [
                    for (final e in f.voices.entries) (a(e.key == 'm' ? 'voiceM' : 'voiceF'), e.value),
                  ]),
                ]),
              ),
              const SizedBox(height: 16),
              _crewPanel(context, f, a, loc),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _crewPanel(BuildContext context, FleetStats f, AdminText a, String loc) {
    final q = _search.text.trim().toLowerCase();
    final list = f.crew.where((x) {
      final okFilter = switch (_filter) {
        _Filter.all => true,
        _Filter.attention => x.needsAttention,
        _Filter.overdue => x.last != null && x.overdue,
        _Filter.noData => x.last == null,
      };
      if (!okFilter) return false;
      if (q.isEmpty) return true;
      return x.name.toLowerCase().contains(q) || x.user.email.toLowerCase().contains(q);
    }).toList();
    int byLast(Astronaut x, Astronaut y) {
      final dx = x.last?.createdAt, dy = y.last?.createdAt;
      if (dx == null && dy == null) return 0;
      if (dx == null) return 1;
      if (dy == null) return -1;
      return dy.compareTo(dx);
    }

    list.sort(switch (_sort) {
      _Sort.risk => (x, y) {
          final r = x.risk.index.compareTo(y.risk.index);
          return r != 0 ? r : byLast(x, y);
        },
      _Sort.name => (x, y) => x.name.toLowerCase().compareTo(y.name.toLowerCase()),
      _Sort.last => byLast,
      _Sort.phq => (x, y) => (y.last?.phqTotal ?? -1).compareTo(x.last?.phqTotal ?? -1),
      _Sort.gad => (x, y) => (y.last?.gadTotal ?? -1).compareTo(x.last?.gadTotal ?? -1),
    });

    return AdminPanel(
      title: '${a('crew')} · ${list.length}/${f.total}',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TextField(
          controller: _search,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search_rounded),
            hintText: a('search'),
            isDense: true,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          for (final (fl, key) in [
            (_Filter.all, 'fAll'),
            (_Filter.attention, 'fAttention'),
            (_Filter.overdue, 'fOverdue'),
            (_Filter.noData, 'fNoData'),
          ])
            ChoiceChip(
              label: Text(a(key)),
              selected: _filter == fl,
              onSelected: (_) => setState(() => _filter = fl),
            ),
          const SizedBox(width: 8),
          Text(a('sortBy'), style: const TextStyle(color: PiCores.textoSuave, fontWeight: FontWeight.w700)),
          DropdownButton<_Sort>(
            value: _sort,
            underline: const SizedBox.shrink(),
            borderRadius: BorderRadius.circular(12),
            onChanged: (v) => setState(() => _sort = v ?? _sort),
            items: [
              for (final (s, key) in [
                (_Sort.risk, 'sRisk'),
                (_Sort.name, 'sName'),
                (_Sort.last, 'sLast'),
                (_Sort.phq, 'sPhq'),
                (_Sort.gad, 'sGad'),
              ])
                DropdownMenuItem(value: s, child: Text(a(key))),
            ],
          ),
        ]),
        const SizedBox(height: 12),
        if (f.total == 0)
          Padding(padding: const EdgeInsets.all(12), child: Text(a('emptyCrew'), style: const TextStyle(color: PiCores.textoSuave)))
        else if (list.isEmpty)
          Padding(padding: const EdgeInsets.all(12), child: Text(a('noMatch'), style: const TextStyle(color: PiCores.textoSuave)))
        else
          LayoutBuilder(builder: (context, box) {
            final wide = box.maxWidth >= 860;
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (wide) _CrewHeader(a: a),
              for (final x in list) _CrewRow(x: x, a: a, wide: wide, locale: loc),
            ]);
          }),
      ]),
    );
  }
}

/// Moldura das telas do admin: cabeçalho com marca, atualização e saída.
class AdminScaffold extends StatelessWidget {
  const AdminScaffold({
    super.key,
    required this.a,
    required this.body,
    this.onRefresh,
    this.updatedAt,
    this.loading = false,
    required this.locale,
    this.leading,
  });
  final AdminText a;
  final Widget body;
  final VoidCallback? onRefresh;
  final DateTime? updatedAt;
  final bool loading;
  final String locale;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    return Scaffold(
      backgroundColor: PiCores.fundo,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 6),
            child: Row(children: [
              ?leading,
              const BrandBadge(size: 38),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(a('title'), style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
                  Text(
                    updatedAt == null
                        ? a('subtitle')
                        : '${a('subtitle')} · ${a('updatedAt', {'t': DateFormat.Hm(locale).format(updatedAt!)})}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: PiCores.textoSuave),
                  ),
                ]),
              ),
              if (loading)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5)),
                )
              else
                IconButton(
                  tooltip: a('refresh'),
                  onPressed: onRefresh,
                  icon: const Icon(Icons.refresh_rounded, color: PiCores.textoSuave),
                ),
              IconButton(
                tooltip: a('logout'),
                onPressed: () {
                  context.read<AdminController>().clear();
                  app.logout();
                },
                icon: const Icon(Icons.logout_rounded, color: PiCores.textoSuave),
              ),
            ]),
          ),
          if (loading) const LinearProgressIndicator(minHeight: 2),
          Expanded(child: body),
        ]),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.a, required this.onRetry});
  final AdminText a;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.cloud_off_rounded, size: 40, color: PiCores.textoSuave),
            const SizedBox(height: 12),
            Text(a('errorLoad'), textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: Text(a('retry'))),
          ]),
        ),
      );
}

class _PriorityPanel extends StatelessWidget {
  const _PriorityPanel({required this.f, required this.a});
  final FleetStats f;
  final AdminText a;

  @override
  Widget build(BuildContext context) {
    final list = f.priority;
    return AdminPanel(
      title: a('priority'),
      subtitle: '${list.length}',
      child: list.isEmpty
          ? Row(children: [
              Icon(Icons.check_circle_rounded, color: PiCores.bandas[0]),
              const SizedBox(width: 8),
              Expanded(child: Text(a('priorityEmpty'), style: const TextStyle(fontWeight: FontWeight.w700))),
            ])
          : Column(children: [
              for (final x in list.take(8))
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => context.push('/admin/astronaut/${x.user.id}'),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                    child: Row(children: [
                      _Avatar(x),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(x.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
                          Text(
                            'PHQ-9 ${x.last!.phqTotal} (${signed(x.phqDelta)}) · GAD-7 ${x.last!.gadTotal} (${signed(x.gadDelta)}) · ${ago(x.daysSinceLast, a)}',
                            style: const TextStyle(fontSize: 12, color: PiCores.textoSuave),
                          ),
                        ]),
                      ),
                      RiskChip(x.risk, a),
                    ]),
                  ),
                ),
            ]),
    );
  }
}

class _AdherenceSummary extends StatelessWidget {
  const _AdherenceSummary({required this.f});
  final FleetStats f;

  @override
  Widget build(BuildContext context) {
    final avg = f.avgAdherence ?? 0;
    // Faixas de adesão: <50%, 50–79%, ≥80%.
    final low = f.crew.where((x) => x.adherence < .5).length;
    final mid = f.crew.where((x) => x.adherence >= .5 && x.adherence < .8).length;
    final high = f.crew.length - low - mid;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('${(avg * 100).round()}%', style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: PiCores.lima)),
      const SizedBox(height: 8),
      ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: LinearProgressIndicator(
          value: avg,
          minHeight: 12,
          backgroundColor: PiCores.fundo2,
          color: PiCores.lima,
        ),
      ),
      const SizedBox(height: 16),
      BandDistribution(
        counts: [high, mid, low],
        labels: const ['≥ 80%', '50–79%', '< 50%'],
        colors: [PiCores.bandas[0], PiCores.bandas[2], PiCores.bandas[4]],
      ),
    ]);
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar(this.x);
  final Astronaut x;

  @override
  Widget build(BuildContext context) {
    final c = riskColor(x.risk);
    final initial = x.name.isEmpty ? '?' : x.name.characters.first.toUpperCase();
    return ExcludeSemantics(
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: c.withValues(alpha: .18),
          shape: BoxShape.circle,
          border: Border.all(color: c, width: 1.5),
        ),
        child: Text(initial, style: TextStyle(fontWeight: FontWeight.w900, color: c)),
      ),
    );
  }
}

const _hdr = TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: PiCores.textoSuave);

class _CrewHeader extends StatelessWidget {
  const _CrewHeader({required this.a});
  final AdminText a;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        child: Row(children: [
          const SizedBox(width: 46),
          Expanded(flex: 5, child: Text(a('colAstronaut'), style: _hdr)),
          Expanded(flex: 3, child: Text(a('colStatus'), style: _hdr)),
          Expanded(flex: 2, child: Text(a('colLast'), style: _hdr)),
          Expanded(flex: 2, child: Text('PHQ-9', style: _hdr)),
          Expanded(flex: 2, child: Text('GAD-7', style: _hdr)),
          Expanded(flex: 2, child: Text(a('colAdh'), style: _hdr)),
          Expanded(flex: 2, child: Text(a('colCount'), style: _hdr, textAlign: TextAlign.right)),
          const SizedBox(width: 28),
        ]),
      );
}

class _CrewRow extends StatelessWidget {
  const _CrewRow({required this.x, required this.a, required this.wide, required this.locale});
  final Astronaut x;
  final AdminText a;
  final bool wide;
  final String locale;

  Widget _score(int? v, int? delta) {
    if (v == null) return const Text('—', style: TextStyle(color: PiCores.textoSuave));
    final worse = (delta ?? 0) > 0;
    return Text.rich(TextSpan(children: [
      TextSpan(text: '$v', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
      if (delta != null && delta != 0)
        TextSpan(
          text: '  ${signed(delta)}',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: worse ? PiCores.bochecha : PiCores.bandas[0]),
        ),
    ]));
  }

  @override
  Widget build(BuildContext context) {
    final l = x.last;
    final name = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(x.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
      Text(x.user.email, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: PiCores.textoSuave)),
    ]);
    final adh = '${(x.adherence * 100).round()}%';
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: PiCores.fundo2,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => context.push('/admin/astronaut/${x.user.id}'),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: wide
                ? Row(children: [
                    _Avatar(x),
                    const SizedBox(width: 10),
                    Expanded(flex: 5, child: name),
                    Expanded(flex: 3, child: Align(alignment: Alignment.centerLeft, child: RiskChip(x.risk, a))),
                    Expanded(flex: 2, child: Text(ago(x.daysSinceLast, a), style: const TextStyle(fontWeight: FontWeight.w700))),
                    Expanded(flex: 2, child: _score(l?.phqTotal, x.phqDelta)),
                    Expanded(flex: 2, child: _score(l?.gadTotal, x.gadDelta)),
                    Expanded(flex: 2, child: Text(adh, style: const TextStyle(fontWeight: FontWeight.w700))),
                    Expanded(
                      flex: 2,
                      child: Text('${x.checkins.length}', textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w800)),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: PiCores.textoSuave),
                  ])
                : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Row(children: [
                      _Avatar(x),
                      const SizedBox(width: 10),
                      Expanded(child: name),
                      RiskChip(x.risk, a),
                    ]),
                    const SizedBox(height: 8),
                    Wrap(spacing: 14, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                      Row(mainAxisSize: MainAxisSize.min, children: [const Text('PHQ-9  ', style: _hdr), _score(l?.phqTotal, x.phqDelta)]),
                      Row(mainAxisSize: MainAxisSize.min, children: [const Text('GAD-7  ', style: _hdr), _score(l?.gadTotal, x.gadDelta)]),
                      Text('${a('colLast')}: ${ago(x.daysSinceLast, a)}', style: _hdr),
                      Text('${a('colAdh')}: $adh', style: _hdr),
                      Text('${a('colCount')}: ${x.checkins.length}', style: _hdr),
                    ]),
                  ]),
          ),
        ),
      ),
    );
  }
}
