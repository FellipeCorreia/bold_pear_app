import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../core/i18n/l10n.dart';
import '../avatar/pear_controller.dart';

/// Voz da Bold Pear (TTS do sistema no protótipo; áudios neurais na versão final).
/// Controla a boca da pera e as legendas.
class VoiceService {
  VoiceService(this.pear) {
    _tts.setStartHandler(() => pear.set(talking: true));
    _tts.setCompletionHandler(() => pear.set(talking: false));
    _tts.setCancelHandler(() => pear.set(talking: false));
    _tts.setErrorHandler((_) => pear.set(talking: false));
  }

  final PearController pear;
  final FlutterTts _tts = FlutterTts();

  final ValueNotifier<String> subtitle = ValueNotifier('');

  /// Sem voz instalada no idioma: fala simulada e legendas forçadas.
  final ValueNotifier<bool> noVoice = ValueNotifier(false);

  String _lang = 'pt';
  String _gender = 'f';
  double _pitch = 1.2;
  int _tok = 0;

  static final _fem = RegExp(
      r'(female|luciana|francisca|thalita|vit[oó]ria|maria|raquel|fernanda|leticia|samantha|victoria|karen|zira|aria|jenny|susan|allison|ava\b|serena|tessa|moira|anna|petra|katja|hedda|marlene|vicki|am[eé]lie|audrey|aur[eé]lie|denise|julie|marie|c[eé]line|virginie|kyoko|haruka|ayumi|nanami|mizuki|sayaka)',
      caseSensitive: false);
  static final _masc = RegExp(
      r'(\bmale|felipe|daniel|ant[oô]nio|ricardo|paulo|duarte|thomas|alex\b|fred\b|david|mark\b|guy\b|ryan|george|reed|aaron|markus|stefan|conrad|yannick|hans|klaus|henri|paul\b|nicolas|thierry|otoya|ichiro|keita|kenji|takumi)',
      caseSensitive: false);

  Future<void> configure(String lang, String gender) async {
    _lang = lang;
    _gender = gender;
    pear.set(gender: gender);
    try {
      await _tts.awaitSpeakCompletion(true);
      await _tts.setLanguage(kLocales[lang]!);
      await _tts.setSpeechRate(kIsWeb ? 0.95 : 0.48);
      final raw = await _tts.getVoices;
      final voices = (raw is List ? raw : const [])
          .whereType<Map>()
          .map((v) => {'name': '${v['name'] ?? ''}', 'locale': '${v['locale'] ?? v['lang'] ?? ''}'})
          .where((v) => v['locale']!.toLowerCase().replaceAll('_', '-').startsWith(lang))
          .toList();
      if (voices.isEmpty) {
        noVoice.value = true;
        return;
      }
      noVoice.value = false;
      final f = gender == 'f';
      Map<String, String>? best;
      var bestScore = -99;
      for (final v in voices) {
        final n = v['name']!;
        final isF = _fem.hasMatch(n);
        final isM = !isF && _masc.hasMatch(n);
        var s = 0;
        if (f ? isF : isM) s += 4;
        if (f ? isM : isF) s -= 4;
        if (RegExp(r'natural|neural|premium|enhanced|google', caseSensitive: false).hasMatch(n)) s += 2;
        if (v['locale']!.replaceAll('_', '-').toLowerCase() == kLocales[lang]!.toLowerCase()) s += 1;
        if (s > bestScore) {
          bestScore = s;
          best = v;
        }
      }
      final matched = bestScore >= 4;
      _pitch = f ? (matched ? 1.18 : 1.4) : (matched ? 0.98 : 0.78);
      await _tts.setPitch(_pitch);
      if (best != null) await _tts.setVoice(best);
    } catch (_) {
      noVoice.value = true;
    }
  }

  int _estimateMs(String s) => (_lang == 'ja' ? s.length * 150 : s.length * 62) + 500;

  List<String> _chunks(String t) {
    final parts = RegExp(r'[^.!?。！？]+[.!?。！？]*').allMatches(t).map((m) => m[0]!.trim()).where((p) => p.isNotEmpty);
    final out = <String>[];
    for (var p in parts) {
      while (p.length > 170) {
        var i = p.lastIndexOf(', ', 150);
        if (i < 40) i = p.indexOf(', ', 40);
        if (i < 0) break;
        out.add(p.substring(0, i + 1));
        p = p.substring(i + 2);
      }
      out.add(p);
    }
    return out.isEmpty ? [t] : out;
  }

  /// Fala [text] e espera terminar. Uma nova fala ou [stop] cancela a anterior.
  Future<void> say(String text, {String? expr}) async {
    final my = ++_tok;
    if (expr != null) pear.set(expr: expr);
    subtitle.value = text;
    await _tts.stop();
    if (my != _tok) return;
    if (noVoice.value) {
      pear.set(talking: true);
      await Future<void>.delayed(Duration(milliseconds: _estimateMs(text)));
      if (my == _tok) {
        pear.set(talking: false);
        _clearSubtitleLater(my);
      }
      return;
    }
    for (final c in _chunks(text)) {
      if (my != _tok) return;
      pear.set(talking: true);
      try {
        await _tts.speak(c).timeout(Duration(milliseconds: _estimateMs(c) + 4000));
      } catch (_) {}
    }
    if (my == _tok) {
      pear.set(talking: false);
      _clearSubtitleLater(my);
    }
  }

  /// A legenda some alguns segundos depois da fala, para não ficar "presa" em outra tela.
  void _clearSubtitleLater(int my) {
    Future<void>.delayed(const Duration(seconds: 5), () {
      if (my == _tok) subtitle.value = '';
    });
  }

  Future<void> stop() async {
    _tok++;
    subtitle.value = '';
    pear.set(talking: false);
    await _tts.stop();
  }

  String get gender => _gender;
}
