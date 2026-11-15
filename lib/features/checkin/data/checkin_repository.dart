import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/checkin.dart';

class CheckinRepository {
  CheckinRepository(this._sb);
  final SupabaseClient _sb;

  Future<void> save(Checkin c) => _sb.from('checkins').insert(c.toInsert());

  /// Mais recentes primeiro.
  Future<List<Checkin>> list({int limit = 60}) async {
    final rows = await _sb.from('checkins').select().order('created_at', ascending: false).limit(limit);
    return rows.map(Checkin.fromMap).toList();
  }
}
