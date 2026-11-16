import 'package:bold_pear/features/checkin/domain/checkin.dart';
import 'package:bold_pear/features/checkin/domain/score_alert.dart';
import 'package:flutter_test/flutter_test.dart';

Checkin ck(int daysAgo, List<int> phq, List<int> gad, {String lang = 'pt'}) => Checkin(
      createdAt: DateTime(2026, 11, 15).subtract(Duration(days: daysAgo)),
      language: lang,
      phqItems: phq,
      gadItems: gad,
    );

void main() {
  final calmPhq = List.filled(9, 0);
  final calmGad = [1, 1, 1, 0, 0, 1, 0];

  test('below the cut-offs → no alert', () {
    expect(AlertEngine.evaluate(ck(0, [1, 1, 1, 1, 1, 1, 1, 1, 0], calmGad), []), isEmpty);
  });

  test('PHQ-9 cut-off depends on language (pt ≥ 9, others ≥ 10)', () {
    final phq9 = [1, 1, 1, 1, 1, 1, 1, 2, 0];
    expect(AlertEngine.evaluate(ck(0, phq9, calmGad), []).single.scale, AlertScale.phq);
    expect(AlertEngine.evaluate(ck(0, phq9, calmGad, lang: 'en'), []), isEmpty);
  });

  test('GAD-7 over the cut-off flags the items that moved off the curve', () {
    final history = [ck(14, calmPhq, calmGad), ck(28, calmPhq, [1, 1, 1, 1, 0, 1, 0])];
    final now = ck(0, calmPhq, [2, 2, 1, 3, 1, 1, 0]);
    final a = AlertEngine.evaluate(now, history).single;
    expect(a.scale, AlertScale.gad);
    expect(a.total, 10);
    expect(a.cutoff, 10);
    expect(a.previousMean, 4.5);
    // item 4 "trouble relaxing": 3 vs mean 0.5 → biggest deviation first.
    expect(a.deviations.map((d) => d.item).toList(), [3, 0, 1, 4]);
    expect(a.deviations.first.baseline, 0.5);
  });

  test('stably high score → alert without deviations', () {
    final high = [2, 2, 1, 2, 1, 1, 1];
    final a = AlertEngine.evaluate(ck(0, calmPhq, high), [ck(14, calmPhq, high)]).single;
    expect(a.deviations, isEmpty);
    expect(a.hasHistory, isTrue);
  });

  test('no history → lists the high-scoring items', () {
    final a = AlertEngine.evaluate(ck(0, calmPhq, [3, 2, 1, 2, 1, 1, 0]), []).single;
    expect(a.hasHistory, isFalse);
    expect(a.deviations.map((d) => d.item).toList(), [0, 1, 3]);
  });

  test('history newer than the current check-in is ignored', () {
    final now = ck(10, calmPhq, [2, 2, 2, 2, 1, 1, 0]);
    final a = AlertEngine.evaluate(now, [ck(0, calmPhq, calmGad)]).single;
    expect(a.hasHistory, isFalse);
  });
}
