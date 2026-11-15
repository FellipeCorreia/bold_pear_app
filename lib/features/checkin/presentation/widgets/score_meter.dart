import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/pi_cores.dart';

/// Barra com as faixas de gravidade e um marcador na pontuação.
class ScoreMeter extends StatelessWidget {
  const ScoreMeter({
    super.key,
    required this.title,
    required this.score,
    required this.max,
    required this.cuts,
    required this.labels,
    required this.attention,
    required this.attentionLabel,
  });

  final String title;
  final int score;
  final int max;
  final List<int> cuts;
  final List<String> labels;
  final int attention;
  final String attentionLabel;

  static Color bandColor(int band, int bandCount) =>
      PiCores.bandas[bandCount == 4 && band == 3 ? 4 : band];

  @override
  Widget build(BuildContext context) {
    final edges = [0, ...cuts, max + 1];
    final band = cuts.where((c) => score >= c).length;
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(child: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
          Text.rich(TextSpan(children: [
            TextSpan(text: '$score', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
            TextSpan(text: '/$max', style: const TextStyle(fontSize: 15, color: PiCores.textoSuave)),
          ])),
        ]),
        const SizedBox(height: 8),
        LayoutBuilder(builder: (context, c) {
          final x = (score + .5) / (max + 1) * c.maxWidth;
          return SizedBox(
            height: 26,
            child: Stack(clipBehavior: Clip.none, children: [
              Positioned(
                left: 0,
                right: 0,
                top: 6,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: Row(children: [
                    for (var i = 0; i < edges.length - 1; i++)
                      Expanded(
                        flex: edges[i + 1] - edges[i],
                        child: Container(
                          height: 14,
                          margin: EdgeInsets.only(right: i < edges.length - 2 ? 2 : 0),
                          color: bandColor(i, cuts.length + 1).withValues(alpha: i == band ? 1 : .38),
                        ),
                      ),
                  ]),
                ),
              ),
              Positioned(
                left: x - 3,
                top: 0,
                child: Container(
                  width: 6,
                  height: 26,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(color: PiCores.painel, width: 1.5),
                  ),
                ),
              ),
            ]),
          );
        }),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
          Text(labels[band], style: const TextStyle(fontWeight: FontWeight.w800)),
          if (score >= attention)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              decoration: BoxDecoration(color: PiCores.tagFundo, borderRadius: BorderRadius.circular(99)),
              child: Text(attentionLabel,
                  style: const TextStyle(fontSize: 13, color: PiCores.tagTexto, fontWeight: FontWeight.w700)),
            ),
        ]),
      ]),
    );
  }
}
