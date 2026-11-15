import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/i18n/l10n.dart';
import '../features/avatar/pear_controller.dart';
import '../features/profile/data/profile_repository.dart';
import '../features/profile/domain/profile.dart';
import '../features/voice/voice_service.dart';

/// Sessão, perfil, idioma e preferências de exibição.
class AppState extends ChangeNotifier {
  AppState(this._prefs, this.voice, this.pear) {
    lang = _prefs.getString('lang') ?? 'pt';
    cc = _prefs.getBool('cc') ?? false;
    voice.setMuted(_prefs.getBool('muted') ?? false);
    voice.configure(lang, 'f');
    _sub = sb.auth.onAuthStateChange.listen((d) => _onAuth(d.session));
    _onAuth(sb.auth.currentSession);
  }

  final SharedPreferences _prefs;
  final VoiceService voice;
  final PearController pear;
  final SupabaseClient sb = Supabase.instance.client;
  late final ProfileRepository _profiles = ProfileRepository(sb);
  StreamSubscription<AuthState>? _sub;

  bool ready = false;
  Session? session;
  Profile? profile;
  late String lang;
  bool cc = false;
  bool greeted = false;
  int _authTok = 0;

  bool get loggedIn => session != null;

  L10n get t => L10n(
        lang,
        voiceGender: profile?.voiceGender ?? pear.gender,
        addressForm: profile?.addressForm ?? 'm',
        name: profile?.displayName ?? '',
      );

  Future<void> _onAuth(Session? s) async {
    final my = ++_authTok;
    final sameUser = s != null && session?.user.id == s.user.id && profile != null;
    session = s;
    if (s == null) {
      profile = null;
      greeted = false;
      ready = true;
      notifyListeners();
      return;
    }
    if (sameUser) return;
    profile = null;
    notifyListeners();
    try {
      final p = await _profiles.fetchOrCreate(s.user);
      if (my != _authTok) return;
      profile = p;
      if (p.onboarded) {
        lang = p.language;
        await _prefs.setString('lang', lang);
      }
    } catch (_) {
      if (my != _authTok) return;
      profile = Profile(
          id: s.user.id, displayName: '', language: lang, voiceGender: 'f', addressForm: 'm', onboarded: false);
    }
    await voice.configure(lang, profile!.voiceGender);
    ready = true;
    notifyListeners();
  }

  Future<void> setLang(String l) async {
    lang = l;
    await _prefs.setString('lang', l);
    await voice.configure(l, profile?.voiceGender ?? pear.gender);
    if (profile != null) await updateProfile(language: l);
    notifyListeners();
  }

  Future<void> previewGender(String g) async {
    await voice.configure(lang, g);
    notifyListeners();
  }

  Future<void> updateProfile({String? displayName, String? language, String? voiceGender, String? addressForm, bool? onboarded}) async {
    final p = profile;
    if (p == null) return;
    final next = p.copyWith(
        displayName: displayName,
        language: language,
        voiceGender: voiceGender,
        addressForm: addressForm,
        onboarded: onboarded);
    profile = next;
    notifyListeners();
    if (voiceGender != null) await voice.configure(lang, voiceGender);
    try {
      profile = await _profiles.save(next);
      notifyListeners();
    } catch (_) {}
  }

  void toggleCc() {
    cc = !cc;
    _prefs.setBool('cc', cc);
    notifyListeners();
  }

  bool get muted => voice.muted.value;

  void toggleMute() {
    voice.setMuted(!muted);
    _prefs.setBool('muted', muted);
    notifyListeners();
  }

  Future<void> logout() async {
    await voice.stop();
    pear.set(expr: 'neutral', breath: 1);
    await sb.auth.signOut();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
