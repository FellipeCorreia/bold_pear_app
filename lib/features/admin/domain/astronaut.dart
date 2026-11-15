import 'dart:math' as math;

import '../../checkin/domain/checkin.dart';
import '../../checkin/domain/score_alert.dart';

/// Conta cadastrada, como o admin a vê (perfil + dados do auth).
class AdminUser {
  const AdminUser({
    required this.id,
    required this.email,
    required this.displayName,
    required this.language,
    required this.voiceGender,
    required this.addressForm,
    required this.onboarded,
    required this.createdAt,
    required this.lastSignInAt,
    required this.isAdmin,
  });

  final String id;
  final String email;
  final String displayName;
  final String language;
  final String voiceGender;
  final String addressForm;
  final bool onboarded;
  final DateTime createdAt;
  final DateTime? lastSignInAt;
  final bool isAdmin;

  factory AdminUser.fromMap(Map<String, dynamic> m) => AdminUser(
        id: m['id'] as String,
        email: (m['email'] as String?) ?? '',
        displayName: (m['display_name'] as String?) ?? '',
        language: (m['language'] as String?) ?? 'en',
        voiceGender: (m['voice_gender'] as String?) ?? 'f',
        addressForm: (m['address_form'] as String?) ?? 'm',
        onboarded: (m['onboarded'] as bool?) ?? false,
        createdAt: DateTime.parse(m['created_at'] as String).toLocal(),
        lastSignInAt: m['last_sign_in_at'] == null ? null : DateTime.parse(m['last_sign_in_at'] as String).toLocal(),
        isAdmin: (m['is_admin'] as bool?) ?? false,
      );
}

/// Situação de acompanhamento, da mais urgente para a menos urgente.
enum Risk { safety, high, attention, overdue, noData, ok }

/// Um astronauta com o histórico de check-ins e os indicadores derivados.
class Astronaut {
  Astronaut(this.user, List<Checkin> checkins, {DateTime? now})
      : checkins = [...checkins]..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
        now = now ?? DateTime.now();

  final AdminUser user;

  /// Mais recentes primeiro.
  final List<Checkin> checkins;
  final DateTime now;

  /// Janela usada para medir a adesão.
  static const adherenceDays = 90;

  /// Piora (em pontos) entre dois check-ins seguidos que já pede atenção.
  static const worseningDelta = 5;

  String get name => user.displayName.isNotEmpty ? user.displayName : user.email.split('@').first;

  Checkin? get last => checkins.isEmpty ? null : checkins.first;
  Checkin? get previous => checkins.length < 2 ? null : checkins[1];

  late final List<ScoreAlert> alerts =
      last == null ? const [] : AlertEngine.evaluate(last!, checkins.skip(1).toList());

  int? get daysSinceLast => last == null ? null : now.difference(last!.createdAt).inDays;

  DateTime? get nextDue => last?.createdAt.add(const Duration(days: Scoring.checkinIntervalDays));

  bool get overdue => last == null || daysSinceLast! >= Scoring.checkinIntervalDays;

  int? get phqDelta => previous == null ? null : last!.phqTotal - previous!.phqTotal;
  int? get gadDelta => previous == null ? null : last!.gadTotal - previous!.gadTotal;

  bool get worsening => (phqDelta ?? 0) >= worseningDelta || (gadDelta ?? 0) >= worseningDelta;

  late final Risk risk = () {
    final l = last;
    if (l == null) return Risk.noData;
    if (l.item9Positive) return Risk.safety;
    if (l.level == 'high') return Risk.high;
    if (alerts.isNotEmpty || worsening) return Risk.attention;
    if (overdue) return Risk.overdue;
    return Risk.ok;
  }();

  bool get needsAttention => risk == Risk.safety || risk == Risk.high || risk == Risk.attention;

  int get checkinsInWindow =>
      checkins.where((c) => now.difference(c.createdAt).inDays < adherenceDays).length;

  /// Check-ins feitos ÷ esperados (um a cada 14 dias) nos últimos 90 dias
  /// (ou desde o cadastro, se for mais recente). Limitado a 100%.
  double get adherence {
    final days = math.min(adherenceDays, math.max(1, now.difference(user.createdAt).inDays + 1));
    final expected = math.max(1, (days / Scoring.checkinIntervalDays).ceil());
    return math.min(1.0, checkinsInWindow / expected);
  }

  double? _mean(int Function(Checkin) f) =>
      checkins.isEmpty ? null : checkins.fold(0, (a, c) => a + f(c)) / checkins.length;

  double? get avgPhq => _mean((c) => c.phqTotal);
  double? get avgGad => _mean((c) => c.gadTotal);
  int? get minPhq => checkins.isEmpty ? null : checkins.map((c) => c.phqTotal).reduce(math.min);
  int? get maxPhq => checkins.isEmpty ? null : checkins.map((c) => c.phqTotal).reduce(math.max);
  int? get minGad => checkins.isEmpty ? null : checkins.map((c) => c.gadTotal).reduce(math.min);
  int? get maxGad => checkins.isEmpty ? null : checkins.map((c) => c.gadTotal).reduce(math.max);

  /// Média pessoal de cada item (0–3) em todos os check-ins.
  List<double> itemMeans(List<int> Function(Checkin) items, int n) {
    final rows = checkins.map(items).where((r) => r.length == n).toList();
    if (rows.isEmpty) return List.filled(n, 0);
    return [for (var i = 0; i < n; i++) rows.fold(0, (a, r) => a + r[i]) / rows.length];
  }
}

/// Uma semana do gráfico da tripulação.
class WeekBucket {
  WeekBucket(this.start);
  final DateTime start;
  int count = 0;
  int _phq = 0;
  int _gad = 0;
  double? get avgPhq => count == 0 ? null : _phq / count;
  double? get avgGad => count == 0 ? null : _gad / count;
}

/// Indicadores da tripulação inteira.
class FleetStats {
  FleetStats(this.crew, {DateTime? now}) : now = now ?? DateTime.now() {
    for (final a in crew) {
      final l = a.last;
      if (l == null) continue;
      phqBands[l.phqBand]++;
      gadBands[l.gadBand]++;
      for (var i = 0; i < 9 && i < l.phqItems.length; i++) {
        phqItemMeans[i] += l.phqItems[i];
      }
      for (var i = 0; i < 7 && i < l.gadItems.length; i++) {
        gadItemMeans[i] += l.gadItems[i];
      }
    }
    if (withData > 0) {
      for (var i = 0; i < 9; i++) {
        phqItemMeans[i] /= withData;
      }
      for (var i = 0; i < 7; i++) {
        gadItemMeans[i] /= withData;
      }
    }
    final thisWeek = weekStart(this.now);
    for (var i = weeksShown - 1; i >= 0; i--) {
      weeks.add(WeekBucket(thisWeek.subtract(Duration(days: 7 * i))));
    }
    for (final a in crew) {
      for (final c in a.checkins) {
        final w = weekStart(c.createdAt);
        final idx = weeks.indexWhere((b) => b.start == w);
        if (idx < 0) continue;
        final b = weeks[idx];
        b.count++;
        b._phq += c.phqTotal;
        b._gad += c.gadTotal;
      }
    }
  }

  static const weeksShown = 12;

  final List<Astronaut> crew;
  final DateTime now;

  final phqBands = List.filled(5, 0);
  final gadBands = List.filled(4, 0);
  final phqItemMeans = List<double>.filled(9, 0);
  final gadItemMeans = List<double>.filled(7, 0);
  final weeks = <WeekBucket>[];

  static DateTime weekStart(DateTime d) => DateTime(d.year, d.month, d.day).subtract(Duration(days: d.weekday - 1));

  int get total => crew.length;
  int get onboarded => crew.where((a) => a.user.onboarded).length;
  int get withData => crew.where((a) => a.last != null).length;
  int get noData => total - withData;
  int get active =>
      crew.where((a) => a.daysSinceLast != null && a.daysSinceLast! < Scoring.checkinIntervalDays).length;
  int get overdue => crew.where((a) => a.last != null && a.overdue).length;
  int get attention => crew.where((a) => a.needsAttention).length;
  int get safety => crew.where((a) => a.risk == Risk.safety).length;
  int get worsening => crew.where((a) => a.worsening).length;
  int get totalCheckins => crew.fold(0, (s, a) => s + a.checkins.length);
  int get checkins30d =>
      crew.fold(0, (s, a) => s + a.checkins.where((c) => now.difference(c.createdAt).inDays < 30).length);

  double? _avgLast(int Function(Checkin) f) {
    final l = crew.map((a) => a.last).whereType<Checkin>().toList();
    return l.isEmpty ? null : l.fold(0, (s, c) => s + f(c)) / l.length;
  }

  double? get avgPhq => _avgLast((c) => c.phqTotal);
  double? get avgGad => _avgLast((c) => c.gadTotal);
  double? get avgAdherence => crew.isEmpty ? null : crew.fold(0.0, (s, a) => s + a.adherence) / crew.length;

  Map<String, int> _count(String Function(Astronaut) key) {
    final m = <String, int>{};
    for (final a in crew) {
      m.update(key(a), (v) => v + 1, ifAbsent: () => 1);
    }
    return Map.fromEntries(m.entries.toList()..sort((a, b) => b.value.compareTo(a.value)));
  }

  Map<String, int> get languages => _count((a) => a.user.language);
  Map<String, int> get voices => _count((a) => a.user.voiceGender);

  /// Quem precisa de atenção, mais urgente primeiro.
  List<Astronaut> get priority => crew.where((a) => a.needsAttention).toList()
    ..sort((a, b) {
      final r = a.risk.index.compareTo(b.risk.index);
      if (r != 0) return r;
      return (b.last!.phqTotal + b.last!.gadTotal).compareTo(a.last!.phqTotal + a.last!.gadTotal);
    });
}
