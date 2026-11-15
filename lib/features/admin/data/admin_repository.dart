import 'package:supabase_flutter/supabase_flutter.dart';

import '../../checkin/domain/checkin.dart';
import '../domain/astronaut.dart';

/// Leitura dos dados de todos os astronautas. O acesso é garantido pelo banco
/// (public.is_admin() + RLS); para quem não é admin as consultas voltam vazias ou falham.
class AdminRepository {
  AdminRepository(this._sb);
  final SupabaseClient _sb;

  static const _page = 1000;

  Future<bool> isAdmin() async {
    try {
      return (await _sb.rpc('is_admin')) == true;
    } catch (_) {
      return false;
    }
  }

  Future<List<AdminUser>> users() async {
    final rows = await _sb.rpc('admin_users') as List;
    return rows.map((r) => AdminUser.fromMap(Map<String, dynamic>.from(r as Map))).toList();
  }

  /// Todos os check-ins agrupados por usuário (mais recentes primeiro), paginando de mil em mil.
  Future<Map<String, List<Checkin>>> checkinsByUser() async {
    final out = <String, List<Checkin>>{};
    for (var from = 0;; from += _page) {
      final rows = await _sb
          .from('checkins')
          .select()
          .order('created_at', ascending: false)
          .range(from, from + _page - 1);
      for (final r in rows) {
        out.putIfAbsent(r['user_id'] as String, () => []).add(Checkin.fromMap(r));
      }
      if (rows.length < _page) break;
    }
    return out;
  }
}
