import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/profile.dart';

class ProfileRepository {
  ProfileRepository(this._sb);
  final SupabaseClient _sb;

  /// Cria o perfil já com o idioma escolhido na tela de boas-vindas.
  Future<Profile> fetchOrCreate(User user, {required String language}) async {
    final row = await _sb.from('profiles').select().eq('id', user.id).maybeSingle();
    if (row != null) return Profile.fromMap(row);
    final name = (user.userMetadata?['display_name'] as String?) ?? (user.email ?? '').split('@').first;
    final created = await _sb.from('profiles').insert({'id': user.id, 'display_name': name, 'language': language}).select().single();
    return Profile.fromMap(created);
  }

  Future<Profile> save(Profile p) async {
    final row = await _sb.from('profiles').update(p.toUpdate()).eq('id', p.id).select().single();
    return Profile.fromMap(row);
  }
}
