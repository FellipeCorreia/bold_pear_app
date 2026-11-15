import 'checkin.dart';

enum AlertScale { phq, gad }

/// Um item cuja pontuação atual ficou acima do padrão dos registros anteriores.
class ItemDeviation {
  const ItemDeviation({required this.item, required this.value, this.baseline});

  /// Índice do item (0-based) dentro da escala.
  final int item;

  /// Resposta atual (0–3).
  final int value;

  /// Média do item nos registros anteriores; null quando não há histórico.
  final double? baseline;

  double get delta => value - (baseline ?? 0);
}

/// Alerta de limite ultrapassado. Só descreve o que foi detectado;
/// não carrega nenhuma sugestão ou intervenção.
class ScoreAlert {
  const ScoreAlert({
    required this.scale,
    required this.total,
    required this.cutoff,
    required this.previousMean,
    required this.deviations,
  });

  final AlertScale scale;
  final int total;
  final int cutoff;

  /// Média do total nos registros anteriores; null quando não há histórico.
  final double? previousMean;

  /// Itens que fugiram da curva (maior desvio primeiro). Sem histórico,
  /// são os itens com pontuação alta (≥ [AlertEngine.highItem]).
  final List<ItemDeviation> deviations;

  bool get hasHistory => previousMean != null;
}

/// Monitora os pontos de corte do PHQ-9 e do GAD-7 e aponta o desvio.
class AlertEngine {
  AlertEngine._();

  /// Quantos check-ins anteriores formam a linha de base.
  static const baselineSize = 6;

  /// Diferença mínima (em pontos do item) para considerar que o item fugiu da curva.
  static const minDelta = 1.0;

  /// Sem histórico, itens com esta pontuação ou mais são apontados.
  static const highItem = 2;

  /// [history] são check-ins anteriores ao [current], mais recentes primeiro.
  static List<ScoreAlert> evaluate(Checkin current, List<Checkin> history) {
    final prev = history
        .where((c) => c.createdAt.isBefore(current.createdAt))
        .take(baselineSize)
        .toList();
    return [
      if (current.phqTotal >= Scoring.phqAttention(current.language))
        _build(
          AlertScale.phq,
          current.phqItems,
          Scoring.phqAttention(current.language),
          [for (final c in prev) if (c.phqItems.length == current.phqItems.length) c.phqItems],
        ),
      if (current.gadTotal >= Scoring.gadAttention)
        _build(
          AlertScale.gad,
          current.gadItems,
          Scoring.gadAttention,
          [for (final c in prev) if (c.gadItems.length == current.gadItems.length) c.gadItems],
        ),
    ];
  }

  static ScoreAlert _build(AlertScale scale, List<int> items, int cutoff, List<List<int>> prev) {
    final total = items.fold(0, (a, b) => a + b);
    if (prev.isEmpty) {
      final high = [
        for (var i = 0; i < items.length; i++)
          if (items[i] >= highItem) ItemDeviation(item: i, value: items[i]),
      ]..sort((a, b) => b.value.compareTo(a.value));
      return ScoreAlert(scale: scale, total: total, cutoff: cutoff, previousMean: null, deviations: high);
    }
    final n = prev.length;
    final devs = <ItemDeviation>[];
    for (var i = 0; i < items.length; i++) {
      final base = prev.fold(0, (a, p) => a + p[i]) / n;
      if (items[i] - base >= minDelta) devs.add(ItemDeviation(item: i, value: items[i], baseline: base));
    }
    devs.sort((a, b) => b.delta.compareTo(a.delta));
    final prevMean = prev.fold(0, (a, p) => a + p.fold(0, (x, y) => x + y)) / n;
    return ScoreAlert(scale: scale, total: total, cutoff: cutoff, previousMean: prevMean, deviations: devs);
  }
}
