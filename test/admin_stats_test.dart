import 'package:bold_pear/features/admin/domain/astronaut.dart';
import 'package:bold_pear/features/checkin/domain/checkin.dart';
import 'package:flutter_test/flutter_test.dart';

final now = DateTime(2026, 11, 15, 12);

AdminUser user(String id, {int signupDaysAgo = 120}) => AdminUser(
      id: id,
      email: '$id@crew.test',
      displayName: id,
      language: 'en',
      voiceGender: 'f',
      addressForm: 'm',
      onboarded: true,
      createdAt: now.subtract(Duration(days: signupDaysAgo)),
      lastSignInAt: null,
      isAdmin: false,
    );

Checkin ci(int daysAgo, {int phq = 0, int gad = 0, bool item9 = false}) {
  final p = List.filled(9, 0);
  for (var i = 0; i < phq; i++) {
    p[i % 8] += 1; // nunca toca o item 9, a não ser que [item9]
  }
  if (item9) p[8] = 1;
  final g = List.filled(7, 0);
  for (var i = 0; i < gad; i++) {
    g[i % 7] += 1;
  }
  return Checkin(createdAt: now.subtract(Duration(days: daysAgo)), language: 'en', phqItems: p, gadItems: g);
}

void main() {
  test('sem check-in: noData, adesão zero', () {
    final a = Astronaut(user('a'), const [], now: now);
    expect(a.risk, Risk.noData);
    expect(a.adherence, 0);
    expect(a.overdue, isTrue);
  });

  test('item 9 positivo tem prioridade máxima', () {
    final a = Astronaut(user('a'), [ci(1, phq: 2, item9: true)], now: now);
    expect(a.risk, Risk.safety);
    expect(a.needsAttention, isTrue);
  });

  test('piora de 5+ pontos pede atenção mesmo abaixo do corte', () {
    final a = Astronaut(user('a'), [ci(1, phq: 7), ci(15, phq: 1)], now: now);
    expect(a.phqDelta, 6);
    expect(a.risk, Risk.attention);
  });

  test('estável e em dia', () {
    final a = Astronaut(user('a'), [ci(2, phq: 2), ci(16, phq: 3)], now: now);
    expect(a.risk, Risk.ok);
  });

  test('atrasado após 14 dias', () {
    final a = Astronaut(user('a'), [ci(20, phq: 1)], now: now);
    expect(a.risk, Risk.overdue);
  });

  test('adesão: 7 esperados em 90 dias, limitada a 100%', () {
    final a = Astronaut(user('a'), [for (var d = 0; d < 90; d += 14) ci(d)], now: now);
    expect(a.checkinsInWindow, 7);
    expect(a.adherence, 1.0);
    final b = Astronaut(user('b', signupDaysAgo: 20), [ci(1)], now: now);
    expect(b.adherence, 0.5); // 21 dias → 2 esperados
  });

  test('frota: faixas, semanas e prioridade', () {
    final crew = [
      Astronaut(user('ok'), [ci(1, phq: 2, gad: 1)], now: now),
      Astronaut(user('grave'), [ci(3, phq: 21, gad: 16)], now: now),
      Astronaut(user('risco'), [ci(2, phq: 3, item9: true)], now: now),
      Astronaut(user('novo'), const [], now: now),
    ];
    final f = FleetStats(crew, now: now);
    expect(f.total, 4);
    expect(f.withData, 3);
    expect(f.noData, 1);
    expect(f.active, 3);
    expect(f.phqBands, [2, 0, 0, 0, 1]);
    expect(f.gadBands, [2, 0, 0, 1]);
    expect(f.weeks.length, FleetStats.weeksShown);
    expect(f.weeks.fold(0, (s, w) => s + w.count), 3);
    expect(f.priority.map((a) => a.user.id), ['risco', 'grave']);
  });
}
