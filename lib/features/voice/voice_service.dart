import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../core/i18n/l10n.dart';
import '../avatar/pear_controller.dart';
import 'neural/neural_voice.dart';

/// Voz da Bold Pear: voz neural offline (Supertonic 3) quando o pacote está instalado,
/// senão o TTS do sistema. Controla a boca da pera, as legendas e o modo silencioso.
class VoiceService {
  VoiceService(this.pear) {
    _tts.setStartHandler(() => pear.set(talking: true));
    _tts.setCompletionHandler(() => pear.set(talking: false));
    _tts.setCancelHandler(() => pear.set(talking: false));
    _tts.setErrorHandler((_) => pear.set(talking: false));
    // Voz e efeitos da pera tocam juntos, sem interromper a música de quem estiver ouvindo.
    AudioPlayer.global
        .setAudioContext(AudioContextConfig(focus: AudioContextConfigFocus.mixWithOthers).build())
        .catchError((_) {});
    _player.onPlayerComplete.listen((_) => _finishPlayback());
    _player.onLog.listen((_) {}, onError: (Object e) {
      debugPrint('VoiceService player error: $e');
      _finishPlayback();
    });
    neural.status.addListener(() {
      if (neural.ready) noVoice.value = false;
    });
    neural.init();
  }

  final PearController pear;
  final FlutterTts _tts = FlutterTts();
  final AudioPlayer _player = AudioPlayer(playerId: 'pear-voice');
  final NeuralVoice neural = NeuralVoice();

  final ValueNotifier<String> subtitle = ValueNotifier('');

  /// Sem voz instalada no idioma: fala simulada e legendas forçadas.
  final ValueNotifier<bool> noVoice = ValueNotifier(false);

  /// Voz da pera silenciada pelo usuário: ela "fala" só pelas legendas.
  final ValueNotifier<bool> muted = ValueNotifier(false);

  String _lang = 'en';
  String _gender = 'f';
  double _pitch = 1.2;
  int _tok = 0;
  Completer<void>? _playing;

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
        noVoice.value = !neural.ready;
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
      noVoice.value = !neural.ready;
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
    await _halt();
    if (my != _tok) return;
    if (muted.value || (noVoice.value && !neural.ready)) {
      await _mime(text);
    } else if (!neural.ready || !await _sayNeural(text, my)) {
      if (my == _tok) await _saySystem(text, my);
    }
    if (my == _tok) {
      pear.set(talking: false);
      _clearSubtitleLater(my);
    }
  }

  /// Boca se mexe pelo tempo estimado da fala, sem som.
  Future<void> _mime(String text) async {
    pear.set(talking: true);
    await Future<void>.delayed(Duration(milliseconds: _estimateMs(text)));
  }

  Future<void> _saySystem(String text, int my) async {
    final cs = _chunks(text);
    for (var i = 0; i < cs.length; i++) {
      if (my != _tok) return;
      if (muted.value) return _mime(cs.skip(i).join(' '));
      pear.set(talking: true);
      try {
        await _tts.speak(cs[i]).timeout(Duration(milliseconds: _estimateMs(cs[i]) + 4000));
      } catch (_) {}
    }
  }

  /// Voz neural frase a frase: enquanto uma toca, a próxima já está sendo gerada.
  /// Devolve false se a primeira frase falhar (aí cai no TTS do sistema).
  Future<bool> _sayNeural(String text, int my) async {
    final chunks = _chunks(text);
    Future<String?> gen(int i) => neural.synth(chunks[i], lang: _lang, gender: _gender);
    var next = gen(0);
    for (var i = 0; i < chunks.length; i++) {
      final path = await next;
      if (my == _tok && !muted.value && i + 1 < chunks.length) next = gen(i + 1);
      if (my != _tok || muted.value) {
        if (path != null) neural.discard(path);
        if (my == _tok) await _mime(chunks.skip(i).join(' '));
        return true;
      }
      if (path == null) {
        if (i == 0) return false;
        continue;
      }
      pear.set(talking: true);
      await _play(path, my);
      neural.discard(path);
    }
    return true;
  }

  /// `play()` em andamento (preparando o arquivo). Duas chamadas sobrepostas no mesmo
  /// player travam o audioplayers por 30 s, então quem for parar/tocar espera esta.
  Future<void>? _starting;

  Future<void> _play(String path, int my) async {
    final done = _playing = Completer<void>();
    try {
      final start = _starting = _player.play(DeviceFileSource(path));
      try {
        await start;
      } finally {
        if (identical(_starting, start)) _starting = null;
      }
      if (my != _tok) return; // cortada enquanto preparava; quem cortou já para o player
      await done.future.timeout(const Duration(seconds: 40));
    } catch (e) {
      debugPrint('VoiceService play failed: $e');
      _finishPlayback();
    }
  }

  void _finishPlayback() {
    final p = _playing;
    if (p != null && !p.isCompleted) p.complete();
  }

  Future<void> _halt() async {
    neural.cancelPending();
    _finishPlayback();
    final starting = _starting;
    if (starting != null) {
      try {
        await starting.timeout(const Duration(seconds: 3));
      } catch (_) {}
    }
    try {
      await _player.stop();
    } catch (_) {}
    await _tts.stop();
  }

  /// A legenda some alguns segundos depois da fala, para não ficar "presa" em outra tela.
  void _clearSubtitleLater(int my) {
    Future<void>.delayed(const Duration(seconds: 5), () {
      if (my == _tok) subtitle.value = '';
    });
  }

  /// Silencia (ou devolve) a voz. A fala atual continua só nas legendas.
  void setMuted(bool v) {
    if (muted.value == v) return;
    muted.value = v;
    if (v) {
      _finishPlayback();
      _player.stop().catchError((_) {});
      _tts.stop();
    }
  }

  Future<void> stop() async {
    _tok++;
    subtitle.value = '';
    pear.set(talking: false);
    await _halt();
  }

  String get gender => _gender;
}
