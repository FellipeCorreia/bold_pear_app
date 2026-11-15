import 'dart:math' as math;

import 'package:intl/intl.dart' show DateFormat;
import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/pi_cores.dart';
import '../../../../core/widgets/ui.dart';
import '../../domain/astronaut.dart';
import '../admin_strings.dart';

const kAdminLocales = {'pt': 'pt_BR', 'en': 'en_US', 'de': 'de_DE', 'fr': 'fr_FR', 'ja': 'ja_JP'};

const _small = TextStyle(fontSize: 12, color: PiCores.textoSuave, fontWeight: FontWeight.w600);

Color riskColor(Risk r) => switch (r) {
      Risk.safety => PiCores.bandas[4],
      Risk.high => PiCores.bandas[3],
      Risk.attention => PiCores.laranja,
      Risk.overdue => PiCores.tagTexto,
      Risk.noData => PiCores.textoSuave,
      Risk.ok => PiCores.bandas[0],
    };

String riskLabel(Risk r, AdminText a) => a(switch (r) {
      Risk.safety => 'rSafety',
      Risk.high => 'rHigh',
      Risk.attention => 'rAttention',
      Risk.overdue => 'rOverdue',
      Risk.noData => 'rNoData',
      Risk.ok => 'rOk',
    });

String fmt1(double? v) => v == null ? '—' : v.toStringAsFixed(1);

String signed(int? v) => v == null ? '—' : (v > 0 ? '+$v' : '$v');

/// "hoje" / "há 3 d" / "nunca".
String ago(int? days, AdminText a) {
  if (days == null) return a('never');
  if (days <= 0) return a('today');
  return a('daysAgo', {'n': '$days'});
}

/// Painel com título (e subtítulo) para as seções do painel.
class AdminPanel extends StatelessWidget {
  const AdminPanel({super.key, required this.title, this.subtitle, this.trailing, required this.child});
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Panel(
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Semantics(
                header: true,
                child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              ),
              if (subtitle != null) Text(subtitle!, style: _small),
            ]),
          ),
          ?trailing,
        ]),
        const SizedBox(height: 14),
        child,
      ]),
    );
  }
}

/// Grade responsiva: 1–4 colunas conforme a largura disponível.
class ResponsiveGrid extends StatelessWidget {
  const ResponsiveGrid({super.key, required this.children, this.minWidth = 240, this.maxCols = 4, this.gap = 12});
  final List<Widget> children;
  final double minWidth;
  final int maxCols;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final cols = (c.maxWidth / minWidth).floor().clamp(1, maxCols);
      final w = (c.maxWidth - gap * (cols - 1)) / cols;
      return Wrap(spacing: gap, runSpacing: gap, children: [
        for (final child in children) SizedBox(width: w, child: child),
      ]);
    });
  }
}

/// Número grande com rótulo e linha de apoio.
class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.label, required this.value, this.sub, this.icon, this.color});
  final String label;
  final String value;
  final String? sub;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? PiCores.texto;
    return Semantics(
      container: true,
      label: '$label: $value${sub == null ? '' : ', $sub'}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: PiCores.painel,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: PiCores.borda),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            if (icon != null) ...[Icon(icon, size: 18, color: c), const SizedBox(width: 6)],
            Expanded(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800, color: PiCores.textoSuave)),
            ),
          ]),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(fontSize: 28, height: 1.1, fontWeight: FontWeight.w900, color: c)),
          if (sub != null) ...[
            const SizedBox(height: 4),
            Text(sub!, maxLines: 2, overflow: TextOverflow.ellipsis, style: _small),
          ],
        ]),
      ),
    );
  }
}

class RiskChip extends StatelessWidget {
  const RiskChip(this.risk, this.a, {super.key});
  final Risk risk;
  final AdminText a;

  @override
  Widget build(BuildContext context) {
    final c = riskColor(risk);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: .16),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: c.withValues(alpha: .7)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(riskLabel(risk, a), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: c)),
      ]),
    );
  }
}

/// Barra empilhada com a distribuição por faixa de gravidade + legenda.
class BandDistribution extends StatelessWidget {
  const BandDistribution({super.key, required this.counts, required this.labels, required this.colors});
  final List<int> counts;
  final List<String> labels;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    final total = counts.fold(0, (a, b) => a + b);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          height: 16,
          child: total == 0
              ? Container(color: PiCores.fundo2)
              : Row(children: [
                  for (var i = 0; i < counts.length; i++)
                    if (counts[i] > 0) Expanded(flex: counts[i], child: Container(color: colors[i])),
                ]),
        ),
      ),
      const SizedBox(height: 12),
      for (var i = 0; i < counts.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(color: colors[i], shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Expanded(child: Text(labels[i], style: const TextStyle(fontWeight: FontWeight.w700))),
            Text('${counts[i]}', style: const TextStyle(fontWeight: FontWeight.w900)),
            SizedBox(
              width: 52,
              child: Text(total == 0 ? '' : '${(100 * counts[i] / total).round()}%',
                  textAlign: TextAlign.right, style: _small),
            ),
          ]),
        ),
    ]);
  }
}

/// Colunas com a contagem de check-ins de cada semana.
class WeeklyBars extends StatelessWidget {
  const WeeklyBars({super.key, required this.weeks, required this.locale});
  final List<WeekBucket> weeks;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final df = DateFormat.MMMd(locale);
    final peak = math.max(1, weeks.fold(0, (m, w) => math.max(m, w.count)));
    return SizedBox(
      height: 170,
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        for (var i = 0; i < weeks.length; i++)
          Expanded(
            child: Semantics(
              label: '${df.format(weeks[i].start)}: ${weeks[i].count}',
              excludeSemantics: true,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Column(children: [
                  Expanded(
                    child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                      Text(weeks[i].count == 0 ? '' : '${weeks[i].count}',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 3),
                      FractionallySizedBox(
                        widthFactor: 1,
                        child: Container(
                          height: math.max(3, 120 * weeks[i].count / peak),
                          decoration: BoxDecoration(
                            color: i == weeks.length - 1 ? PiCores.lima : PiCores.lima.withValues(alpha: .55),
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 14,
                    child: i % 3 == 0 || i == weeks.length - 1
                        ? FittedBox(child: Text(df.format(weeks[i].start), style: _small))
                        : null,
                  ),
                ]),
              ),
            ),
          ),
      ]),
    );
  }
}

/// Uma série do gráfico de linhas.
class LineSeries {
  const LineSeries(this.label, this.color, this.values);
  final String label;
  final Color color;
  final List<double?> values;
}

/// Linhas sobre o mesmo eixo (0–[max]); pontos nulos interrompem a linha.
class MultiLineChart extends StatelessWidget {
  const MultiLineChart({super.key, required this.series, required this.xLabels, required this.max});
  final List<LineSeries> series;
  final List<String> xLabels;
  final double max;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Wrap(spacing: 16, runSpacing: 6, children: [
        for (final s in series)
          Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 14, height: 4, color: s.color),
            const SizedBox(width: 6),
            Text(s.label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          ]),
      ]),
      const SizedBox(height: 10),
      SizedBox(height: 160, child: CustomPaint(painter: _LinesPainter(series, max))),
      const SizedBox(height: 6),
      Row(children: [
        if (xLabels.isNotEmpty) Text(xLabels.first, style: _small),
        const Spacer(),
        if (xLabels.length > 1) Text(xLabels.last, style: _small),
      ]),
    ]);
  }
}

class _LinesPainter extends CustomPainter {
  _LinesPainter(this.series, this.max);
  final List<LineSeries> series;
  final double max;

  @override
  void paint(Canvas canvas, Size size) {
    const padR = 30.0;
    final w = size.width - padR;
    final h = size.height;
    double y(double v) => h - (v / max) * h;
    final grid = Paint()
      ..color = PiCores.borda
      ..strokeWidth = 1;
    final tp = TextPainter(textDirection: TextDirection.ltr);
    for (var i = 0; i <= 3; i++) {
      final v = max * i / 3;
      canvas.drawLine(Offset(0, y(v)), Offset(w, y(v)), grid);
      tp.text = TextSpan(text: v.round().toString(), style: const TextStyle(fontSize: 11, color: PiCores.textoSuave));
      tp.layout();
      tp.paint(canvas, Offset(w + 6, (y(v) - tp.height / 2).clamp(0, h - tp.height)));
    }
    for (final s in series) {
      final n = s.values.length;
      if (n == 0) continue;
      double x(int i) => n == 1 ? w / 2 : 8 + (w - 16) * i / (n - 1);
      final paint = Paint()
        ..color = s.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.round;
      final path = Path();
      var open = false;
      for (var i = 0; i < n; i++) {
        final v = s.values[i];
        if (v == null) {
          open = false;
          continue;
        }
        final p = Offset(x(i), y(v));
        open ? path.lineTo(p.dx, p.dy) : path.moveTo(p.dx, p.dy);
        open = true;
        canvas.drawCircle(p, 3.5, Paint()..color = s.color);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _LinesPainter old) => old.series != series || old.max != max;
}

/// Barras horizontais por item (0–3), com marcador opcional de referência (média pessoal).
class ItemBars extends StatelessWidget {
  const ItemBars({super.key, required this.labels, required this.values, this.reference});
  final List<String> labels;
  final List<double> values;
  final List<double>? reference;

  static Color colorFor(double v) => PiCores.bandas[(v / 3 * 4).round().clamp(0, 4)];

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      for (var i = 0; i < values.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Semantics(
            label: '${labels[i]}: ${fmt1(values[i])} / 3'
                '${reference == null ? '' : ' (${fmt1(reference![i])})'}',
            excludeSemantics: true,
            child: Row(children: [
              Expanded(
                flex: 5,
                child: Text('${i + 1}. ${labels[i]}',
                    maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 6,
                child: LayoutBuilder(builder: (context, c) {
                  final w = c.maxWidth;
                  return SizedBox(
                    height: 14,
                    child: Stack(clipBehavior: Clip.none, children: [
                      Container(
                        decoration: BoxDecoration(color: PiCores.fundo2, borderRadius: BorderRadius.circular(7)),
                      ),
                      Container(
                        width: w * (values[i] / 3).clamp(0, 1),
                        decoration: BoxDecoration(color: colorFor(values[i]), borderRadius: BorderRadius.circular(7)),
                      ),
                      if (reference != null)
                        Positioned(
                          left: (w * (reference![i] / 3).clamp(0, 1) - 1.5).clamp(0, w - 3),
                          top: -3,
                          bottom: -3,
                          child: Container(width: 3, color: PiCores.texto),
                        ),
                    ]),
                  );
                }),
              ),
              SizedBox(
                width: 38,
                child: Text(fmt1(values[i]), textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w900)),
              ),
            ]),
          ),
        ),
    ]);
  }
}

/// Contagem por categoria em pílulas (idiomas, vozes...).
class CountPills extends StatelessWidget {
  const CountPills({super.key, required this.items});
  final List<(String, int)> items;

  @override
  Widget build(BuildContext context) {
    return Wrap(spacing: 8, runSpacing: 8, children: [
      for (final (label, n) in items)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(color: PiCores.fundo2, borderRadius: BorderRadius.circular(99)),
          child: Text.rich(TextSpan(children: [
            TextSpan(text: '$label  ', style: const TextStyle(fontWeight: FontWeight.w700)),
            TextSpan(text: '$n', style: const TextStyle(fontWeight: FontWeight.w900, color: PiCores.lima)),
          ])),
        ),
    ]);
  }
}
