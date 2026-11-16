import 'dart:convert';

import 'package:bold_pear/core/i18n/l10n.dart';
import 'package:bold_pear/core/theme/app_theme.dart';
import 'package:bold_pear/features/admin/data/admin_repository.dart';
import 'package:bold_pear/features/admin/domain/astronaut.dart';
import 'package:bold_pear/features/admin/presentation/admin_dashboard_page.dart';
import 'package:bold_pear/features/admin/presentation/admin_user_page.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'support/crew_fixture.dart';

/// Supabase falso: responde admin_users() e pagina /checkins por offset/limit.
({SupabaseClient sb, List<Uri> calls}) fakeSupabase(CrewFixture f) {
  final calls = <Uri>[];
  late http.Request current;
  http.Response json(Object body) => http.Response.bytes(utf8.encode(jsonEncode(body)), 200,
      request: current, headers: {'content-type': 'application/json; charset=utf-8'});
  final client = MockClient((req) async {
    current = req;
    calls.add(req.url);
    final path = req.url.path;
    if (path.endsWith('/rpc/admin_users')) return json(f.users);
    if (path.endsWith('/rpc/is_admin')) return http.Response('true', 200);
    if (path.endsWith('/checkins')) {
      final offset = int.parse(req.url.queryParameters['offset'] ?? '0');
      final limit = int.parse(req.url.queryParameters['limit'] ?? '${f.checkins.length}');
      final page = f.checkins.skip(offset).take(limit).toList();
      return json(page);
    }
    return http.Response('not found', 404);
  });
  return (sb: SupabaseClient('https://fake.supabase.co', 'test-key', httpClient: client), calls: calls);
}

/// Rola até o widget e espera a animação terminar (senão o toque cai fora da tela).
Future<void> reveal(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => initializeDateFormatting());

  group('volume', () {
    test('repositório pagina além de 1.000 check-ins sem perder nem duplicar', () async {
      final f = CrewFixture(400);
      expect(f.checkins.length, greaterThan(3000));
      final api = fakeSupabase(f);
      final repo = AdminRepository(api.sb);
      final users = await repo.users();
      final by = await repo.checkinsByUser();
      expect(users.length, 400);
      expect(by.values.fold(0, (s, l) => s + l.length), f.checkins.length);
      final ids = {for (final l in by.values) for (final c in l) c.id};
      expect(ids.length, f.checkins.length, reason: 'nenhum check-in duplicado');
      final pages = api.calls.where((u) => u.path.endsWith('/checkins')).length;
      expect(pages, (f.checkins.length / 1000).ceil());
      // Cada lista vem do mais recente para o mais antigo.
      for (final l in by.values) {
        for (var i = 1; i < l.length; i++) {
          expect(l[i - 1].createdAt.isBefore(l[i].createdAt), isFalse);
        }
      }
      await api.sb.dispose();
    });

    test('quantidade exata de páginas cheias (múltiplo de 1.000) termina', () async {
      final f = CrewFixture(300);
      f.checkins.removeRange(2000, f.checkins.length);
      final api = fakeSupabase(f);
      final by = await AdminRepository(api.sb).checkinsByUser();
      expect(by.values.fold(0, (s, l) => s + l.length), 2000);
      expect(api.calls.where((u) => u.path.endsWith('/checkins')).length, 3);
      await api.sb.dispose();
    });

    test('1.000 astronautas: indicadores consistentes e rápidos', () {
      final f = CrewFixture(1000);
      final parse = Stopwatch()..start();
      final crew = f.crew();
      parse.stop();
      FleetStats(f.crew(), now: f.now).priority; // aquece o JIT do teste
      final sw = Stopwatch()..start();
      final fleet = FleetStats(crew, now: f.now);
      // Força todos os cálculos preguiçosos.
      final priority = fleet.priority;
      final summary = [
        fleet.active, fleet.overdue, fleet.attention, fleet.safety, fleet.worsening,
        fleet.totalCheckins, fleet.checkins30d, fleet.avgPhq, fleet.avgGad, fleet.avgAdherence,
      ];
      sw.stop();
      // ignore: avoid_print
      print('1.000 astronautas / ${f.checkins.length} check-ins: '
          'leitura ${parse.elapsedMilliseconds} ms, indicadores ${sw.elapsedMilliseconds} ms');
      expect(sw.elapsedMilliseconds, lessThan(2000));
      expect(summary, isNot(contains(null)));

      expect(fleet.total, 1000);
      expect(fleet.withData + fleet.noData, fleet.total);
      expect(fleet.phqBands.fold(0, (a, b) => a + b), fleet.withData);
      expect(fleet.gadBands.fold(0, (a, b) => a + b), fleet.withData);
      expect(fleet.totalCheckins, f.checkins.length);
      expect(fleet.weeks.fold(0, (s, w) => s + w.count), lessThanOrEqualTo(fleet.totalCheckins));
      expect(fleet.avgPhq!, inInclusiveRange(0, 27));
      expect(fleet.avgGad!, inInclusiveRange(0, 21));
      expect(fleet.avgAdherence!, inInclusiveRange(0, 1));
      for (final v in [...fleet.phqItemMeans, ...fleet.gadItemMeans]) {
        expect(v, inInclusiveRange(0, 3));
      }
      for (final a in crew) {
        expect(a.adherence, inInclusiveRange(0, 1));
      }
      // Prioridade: só quem precisa de atenção, item 9 primeiro, sem repetir ninguém.
      expect(priority.every((a) => a.needsAttention), isTrue);
      expect(priority.length, fleet.attention);
      expect(priority.map((a) => a.user.id).toSet().length, priority.length);
      final firstNonSafety = priority.indexWhere((a) => a.risk != Risk.safety);
      if (firstNonSafety >= 0) {
        expect(priority.skip(firstNonSafety).any((a) => a.risk == Risk.safety), isFalse);
      }
    });

    test('pontuação máxima com item 9 vira prioridade máxima', () {
      final crew = CrewFixture(200).crew();
      final severe = crew.where((a) => a.last != null && a.last!.phqTotal == 27).toList();
      expect(severe, isNotEmpty);
      for (final a in severe) {
        expect(a.last!.gadTotal, 21);
        expect(a.last!.phqBand, 4);
        expect(a.last!.gadBand, 3);
        expect(a.risk, Risk.safety);
        expect(a.alerts.length, 2, reason: 'PHQ-9 e GAD-7 acima do corte');
      }
    });
  });

  group('telas', () {
    final fixture = CrewFixture(600);
    final crew = fixture.crew();
    final fleet = FleetStats(crew, now: fixture.now);

    Future<void> pumpAt(WidgetTester tester, Size size, Widget child) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(theme: buildTheme(), home: Scaffold(body: child)));
      await tester.pump();
    }

    for (final (label, size) in [('celular', const Size(390, 844)), ('desktop', const Size(1440, 900))]) {
      for (final lang in ['pt', 'en', 'ja']) {
        testWidgets('painel com 600 astronautas · $label · $lang', (tester) async {
          final sw = Stopwatch()..start();
          await pumpAt(tester, size, CrewOverview(fleet: fleet, t: L10n(lang), lang: lang));
          sw.stop();
          // ignore: avoid_print
          print('painel $label/$lang: ${sw.elapsedMilliseconds} ms');
          expect(tester.takeException(), isNull);
          expect(find.byType(CrewOverview), findsOneWidget);
        });
      }

      testWidgets('ficha do caso mais grave · $label', (tester) async {
        final worst = fleet.priority.first;
        expect(worst.risk, Risk.safety);
        await pumpAt(tester, size, AstronautView(x: worst, t: const L10n('pt'), lang: 'pt'));
        expect(tester.takeException(), isNull);
        expect(find.textContaining('item 9'), findsWidgets);
        // Abre o check-in mais recente do histórico.
        final tile = find.byType(ExpansionTile).first;
        await reveal(tester, tile);
        await tester.tap(tile);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });

      testWidgets('ficha sem nenhum check-in · $label', (tester) async {
        final empty = crew.firstWhere((a) => a.last == null);
        await pumpAt(tester, size, AstronautView(x: empty, t: const L10n('pt'), lang: 'pt'));
        expect(tester.takeException(), isNull);
        expect(find.text('Ainda sem check-ins.'), findsWidgets);
      });
    }

    testWidgets('busca, filtro e ordenação da tripulação', (tester) async {
      await pumpAt(tester, const Size(1440, 900), CrewOverview(fleet: fleet, t: const L10n('pt'), lang: 'pt'));
      String title() => (tester.widget<Text>(find.textContaining('Tripulação ·')).data)!;
      expect(title(), 'Tripulação · 600/600');

      final chip = find.widgetWithText(ChoiceChip, 'Em atenção');
      await reveal(tester, chip);
      await tester.tap(chip);
      await tester.pump();
      expect(title(), 'Tripulação · ${fleet.attention}/600');

      await reveal(tester, find.widgetWithText(ChoiceChip, 'Todos'));
      await tester.tap(find.widgetWithText(ChoiceChip, 'Todos'));
      await tester.pump();
      // Só 50 linhas de cada vez; "Mostrar mais" carrega as próximas.
      final more = find.textContaining('Mostrar mais');
      expect(find.text('Mostrar mais (550 restantes)'), findsOneWidget);
      await reveal(tester, more);
      await tester.tap(more);
      await tester.pump();
      expect(find.text('Mostrar mais (500 restantes)'), findsOneWidget);

      await reveal(tester, find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'astro42@');
      await tester.pump();
      expect(title(), 'Tripulação · 1/600');

      await tester.enterText(find.byType(TextField), 'さくら');
      await tester.pump();
      expect(title(), 'Tripulação · ${crew.where((a) => a.name.contains('さくら')).length}/600');

      final sort = find.text('Prioridade').last;
      await reveal(tester, sort);
      await tester.tap(sort);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nome').last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Nome'), findsWidgets);
    });
  });
}
