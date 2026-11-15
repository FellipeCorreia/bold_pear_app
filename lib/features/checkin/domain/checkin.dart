/// Um check-in de PHQ-9 + GAD-7.
class Checkin {
  const Checkin({
    this.id,
    required this.createdAt,
    required this.language,
    required this.phqItems,
    required this.gadItems,
    this.phqDifficulty,
  });

  final String? id;
  final DateTime createdAt;
  final String language;
  final List<int> phqItems;
  final List<int> gadItems;
  final int? phqDifficulty;

  int get phqTotal => phqItems.fold(0, (a, b) => a + b);
  int get gadTotal => gadItems.fold(0, (a, b) => a + b);
  bool get item9Positive => phqItems.length == 9 && phqItems[8] > 0;
  int get phqBand => Scoring.band(phqTotal, Scoring.phqCuts);
  int get gadBand => Scoring.band(gadTotal, Scoring.gadCuts);

  /// calm / mid / high — define o tom do resumo e as práticas sugeridas.
  String get level {
    if (phqBand >= 3 || gadBand >= 3) return 'high';
    if (phqTotal >= 5 || gadTotal >= 5) return 'mid';
    return 'calm';
  }

  factory Checkin.fromMap(Map<String, dynamic> m) => Checkin(
        id: m['id'] as String?,
        createdAt: DateTime.parse(m['created_at'] as String).toLocal(),
        language: m['language'] as String,
        phqItems: (m['phq_items'] as List).map((e) => (e as num).toInt()).toList(),
        gadItems: (m['gad_items'] as List).map((e) => (e as num).toInt()).toList(),
        phqDifficulty: (m['phq_difficulty'] as num?)?.toInt(),
      );

  Map<String, dynamic> toInsert() => {
        'language': language,
        'phq_items': phqItems,
        'phq_total': phqTotal,
        'phq_difficulty': phqDifficulty,
        'gad_items': gadItems,
        'gad_total': gadTotal,
        'item9_positive': item9Positive,
      };
}

class Scoring {
  Scoring._();

  /// PHQ-9: 0–4 mínima, 5–9 leve, 10–14 moderada, 15–19 mod. grave, 20–27 grave (Kroenke et al., 2001).
  static const phqCuts = [5, 10, 15, 20];

  /// GAD-7: 0–4 mínima, 5–9 leve, 10–14 moderada, 15–21 grave (Spitzer et al., 2006).
  static const gadCuts = [5, 10, 15];

  static int band(int score, List<int> cuts) => cuts.where((c) => score >= c).length;

  /// Ponto de atenção do PHQ-9: ≥9 na população geral brasileira (Santos et al., 2013), ≥10 nas demais.
  static int phqAttention(String lang) => lang == 'pt' ? 9 : 10;
  static const gadAttention = 10;

  static const checkinIntervalDays = 14;
}
