import 'dart:math';

import 'package:bold_pear/features/admin/domain/astronaut.dart';
import 'package:bold_pear/features/checkin/domain/checkin.dart';

/// Tripulação sintética e determinística para testes de volume e casos extremos.
class CrewFixture {
  CrewFixture(this.size, {this.seed = 42, DateTime? at}) : now = at ?? DateTime(2026, 11, 15, 12) {
    final rng = Random(seed);
    const langs = ['en', 'pt', 'de', 'fr', 'ja'];
    for (var i = 0; i < size; i++) {
      final id = 'u${i.toString().padLeft(5, '0')}';
      final signup = now.subtract(Duration(days: 30 + rng.nextInt(520)));
      users.add({
        'id': id,
        'email': 'astro$i@crew.test',
        // Nomes vazios, longos e em japonês para forçar o layout.
        'display_name': switch (i % 9) {
          0 => '',
          1 => 'Comandante Maria Eduarda de Albuquerque Figueiredo Santos $i',
          2 => '宇宙飛行士 さくら $i',
          _ => 'Astronauta $i',
        },
        'language': langs[i % langs.length],
        'voice_gender': i.isEven ? 'f' : 'm',
        'address_form': i % 3 == 0 ? 'f' : 'm',
        'onboarded': i % 11 != 0,
        'created_at': signup.toUtc().toIso8601String(),
        'last_sign_in_at': i % 13 == 0 ? null : now.subtract(Duration(hours: rng.nextInt(900))).toUtc().toIso8601String(),
        'is_admin': false,
      });
      if (i % 7 == 0) continue; // nunca fez check-in
      final n = 1 + rng.nextInt(36);
      final severe = i % 10 == 3; // pontuação máxima + item 9 no último
      final worsening = i % 10 == 5; // salto grande no último
      var day = rng.nextInt(i % 4 == 0 ? 40 : 10); // alguns bem atrasados
      for (var k = 0; k < n; k++) {
        final latest = k == 0;
        List<int> items(int len, int lo, int hi) => List.generate(len, (_) => lo + rng.nextInt(hi - lo + 1));
        var phq = items(9, 0, 1);
        var gad = items(7, 0, 1);
        if (latest && severe) {
          phq = List.filled(9, 3);
          gad = List.filled(7, 3);
        } else if (latest && worsening) {
          phq = items(9, 1, 2);
          gad = items(7, 1, 2);
        } else {
          phq[8] = 0;
        }
        final c = Checkin(
          createdAt: now.subtract(Duration(days: day, hours: rng.nextInt(20))),
          language: langs[i % langs.length],
          phqItems: phq,
          gadItems: gad,
          phqDifficulty: phq.any((v) => v > 0) ? rng.nextInt(4) : null,
        );
        checkins.add({
          'id': '$id-$k',
          'user_id': id,
          'created_at': c.createdAt.toUtc().toIso8601String(),
          ...c.toInsert(),
        });
        day += 12 + rng.nextInt(5);
      }
    }
    checkins.sort((a, b) => (b['created_at'] as String).compareTo(a['created_at'] as String));
  }

  final int size;
  final int seed;
  final DateTime now;

  /// Linhas como a API devolve (admin_users() e checkins).
  final users = <Map<String, dynamic>>[];
  final checkins = <Map<String, dynamic>>[];

  List<Astronaut> crew() {
    final by = <String, List<Checkin>>{};
    for (final r in checkins) {
      by.putIfAbsent(r['user_id'] as String, () => []).add(Checkin.fromMap(r));
    }
    return [for (final u in users) Astronaut(AdminUser.fromMap(u), by[u['id']] ?? const [], now: now)];
  }
}
