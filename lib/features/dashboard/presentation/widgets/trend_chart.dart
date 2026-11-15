import 'package:intl/intl.dart' show DateFormat;
import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/pi_cores.dart';
import '../../../checkin/presentation/widgets/score_meter.dart';

/// Linha da pontuação ao longo do tempo sobre as faixas de gravidade.
class TrendChart extends StatelessWidget {
  const TrendChart({
    super.key,
    required this.points,
    required this.max,
    required this.cuts,
    required this.locale,
  });

  /// Em ordem cronológica.
  final List<(DateTime, int)> points;
  final int max;
  final List<int> cuts;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final df = DateFormat.MMMd(locale);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SizedBox(
        height: 150,
        child: CustomPaint(painter: _TrendPainter(points, max, cuts)),
      ),
      if (points.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(children: [
            Text(df.format(points.first.$1), style: const TextStyle(fontSize: 12, color: PiCores.textoSuave)),
            const Spacer(),
            if (points.length > 1)
              Text(df.format(points.last.$1), style: const TextStyle(fontSize: 12, color: PiCores.textoSuave)),
          ]),
        ),
    ]);
  }
}

class _TrendPainter extends CustomPainter {
  _TrendPainter(this.points, this.max, this.cuts);
  final List<(DateTime, int)> points;
  final int max;
  final List<int> cuts;

  @override
  void paint(Canvas canvas, Size size) {
    const padR = 34.0;
    final w = size.width - padR;
    final h = size.height;
    double y(num v) => h - (v / max) * h;
    final edges = [0, ...cuts, max];
    for (var i = 0; i < edges.length - 1; i++) {
      final r = Rect.fromLTRB(0, y(edges[i + 1]), w, y(edges[i]));
      canvas.drawRect(r, Paint()..color = ScoreMeter.bandColor(i, cuts.length + 1).withValues(alpha: .14));
    }
    final label = TextPainter(textDirection: TextDirection.ltr);
    for (final v in [0, ...cuts, max]) {
      label.text = TextSpan(text: '$v', style: const TextStyle(fontSize: 11, color: PiCores.textoSuave));
      label.layout();
      label.paint(canvas, Offset(w + 8, (y(v) - label.height / 2).clamp(0, h - label.height)));
    }
    if (points.isEmpty) return;
    double x(int i) => points.length == 1 ? w / 2 : 10 + (w - 20) * i / (points.length - 1);
    final line = Path();
    for (var i = 0; i < points.length; i++) {
      final p = Offset(x(i), y(points[i].$2));
      i == 0 ? line.moveTo(p.dx, p.dy) : line.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
      line,
      Paint()
        ..color = PiCores.texto
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.round,
    );
    for (var i = 0; i < points.length; i++) {
      final last = i == points.length - 1;
      final c = Offset(x(i), y(points[i].$2));
      canvas.drawCircle(c, last ? 6 : 4, Paint()..color = last ? PiCores.lima : PiCores.texto);
      if (last) canvas.drawCircle(c, 6, Paint()..color = PiCores.painel..style = PaintingStyle.stroke..strokeWidth = 2);
    }
  }

  @override
  bool shouldRepaint(covariant _TrendPainter old) => old.points != points;
}
