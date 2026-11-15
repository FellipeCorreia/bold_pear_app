import 'package:flutter/foundation.dart';

import '../../../app/app_state.dart';
import '../data/admin_repository.dart';
import '../domain/astronaut.dart';

/// Dados do painel NASA: carrega todos os astronautas e calcula os indicadores.
class AdminController extends ChangeNotifier {
  AdminController(this.app);

  final AppState app;
  late final _repo = AdminRepository(app.sb);

  bool loading = false;
  Object? error;
  DateTime? updatedAt;
  List<Astronaut> crew = const [];
  FleetStats? fleet;
  Future<void>? _inFlight;

  bool get loaded => updatedAt != null;

  Future<void> load() => _inFlight ??= _load().whenComplete(() => _inFlight = null);

  Future<void> _load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final results = await Future.wait([_repo.users(), _repo.checkinsByUser()]);
      final users = results[0] as List<AdminUser>;
      final checkins = results[1] as Map<String, dynamic>;
      final now = DateTime.now();
      // Contas de admin não entram nas estatísticas da tripulação.
      crew = [
        for (final u in users)
          if (!u.isAdmin) Astronaut(u, (checkins[u.id] as List?)?.cast() ?? const [], now: now),
      ];
      fleet = FleetStats(crew, now: now);
      updatedAt = now;
    } catch (e) {
      debugPrint('AdminController load failed: $e');
      error = e;
    }
    loading = false;
    notifyListeners();
  }

  Astronaut? byId(String id) {
    for (final a in crew) {
      if (a.user.id == id) return a;
    }
    return null;
  }

  void clear() {
    crew = const [];
    fleet = null;
    updatedAt = null;
    error = null;
  }
}
