import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

import 'neural_voice_status.dart';

export 'neural_voice_status.dart';

/// Voz neural offline da Bold Pear: Supertonic 3 (31 idiomas, OpenRAIL-M) via sherpa-onnx.
///
/// O modelo vem embutido no app (assets/voice/supertonic3). Como o sherpa precisa de
/// arquivos em disco (e no Android os assets ficam compactados no APK), na primeira
/// abertura ele é copiado para o armazenamento interno, em segundo plano. Enquanto isso
/// a pera usa a voz do sistema.
///
/// A síntese roda num isolate próprio para não travar as animações. O tom fica
/// "de personagem" com um truque barato: gera um pouco mais devagar e grava o WAV
/// com sample rate maior (pitch sobe, ritmo volta ao normal).
class NeuralVoice {
  static const _assetDir = 'assets/voice/supertonic3';
  static const _dirName = 'supertonic-3-int8';
  static const _version = 'supertonic3-int8-2026-05-11';

  /// Arquivos do modelo e tamanho aproximado (MB), para a barra de progresso.
  static const _files = {
    'vector_estimator.int8.onnx': 78,
    'text_encoder.int8.onnx': 36,
    'vocoder.int8.onnx': 26,
    'duration_predictor.int8.onnx': 4,
    'voice.bin': 1,
    'unicode_indexer.bin': 1,
    'tts.json': 1,
  };

  final ValueNotifier<NeuralVoiceStatus> status = ValueNotifier(NeuralVoiceStatus.absent);
  final ValueNotifier<double> progress = ValueNotifier(0);

  Directory? _root;
  Future<SendPort>? _spawning;
  final _pending = <int, Completer<String?>>{};
  int _seq = 0;

  /// Fila do lado de cá: o worker recebe uma frase por vez, assim [cancelPending]
  /// consegue descartar o que ainda não começou a ser gerado.
  final _queue = <(int, List<Object?>)>[];
  int? _inFlight;
  SendPort? _worker;

  bool get ready => status.value == NeuralVoiceStatus.ready;
  String get _modelDir => '${_root!.path}/$_dirName';

  /// Deixa a voz pronta: usa a cópia já instalada ou instala a partir dos assets.
  Future<void> init() async {
    try {
      _root = Directory('${(await getApplicationSupportDirectory()).path}/voices');
      final marker = File('$_modelDir/.ok');
      if (marker.existsSync() && marker.readAsStringSync() == _version) {
        status.value = NeuralVoiceStatus.ready;
        _warmUp();
        return;
      }
      await _install(marker);
      _warmUp();
    } catch (e) {
      debugPrint('NeuralVoice install failed: $e');
      status.value = NeuralVoiceStatus.error;
    }
  }

  Future<void> _install(File marker) async {
    status.value = NeuralVoiceStatus.installing;
    progress.value = 0;
    final dir = Directory(_modelDir);
    if (dir.existsSync()) dir.deleteSync(recursive: true);
    dir.createSync(recursive: true);
    final total = _files.values.reduce((a, b) => a + b);
    var done = 0;
    for (final MapEntry(key: name, value: mb) in _files.entries) {
      final data = await rootBundle.load('$_assetDir/$name');
      await File('${dir.path}/$name').writeAsBytes(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes), flush: true);
      done += mb;
      progress.value = done / total;
    }
    marker.writeAsStringSync(_version);
    status.value = NeuralVoiceStatus.ready;
  }

  /// Sintetiza [text] e devolve o caminho de um WAV temporário (ou null em falha).
  /// Quem toca o arquivo deve apagá-lo depois.
  Future<String?> synth(
    String text, {
    required String lang,
    required String gender,
  }) async {
    if (!ready || text.trim().isEmpty) return null;
    try {
      _worker ??= await (_spawning ??= _spawn());
      final id = ++_seq;
      final c = Completer<String?>();
      _pending[id] = c;
      _queue.add((id, [id, text, lang, gender]));
      _pump();
      return await c.future.timeout(
        const Duration(seconds: 25),
        onTimeout: () {
          _pending.remove(id);
          _queue.removeWhere((e) => e.$1 == id);
          return null;
        },
      );
    } catch (e) {
      debugPrint('NeuralVoice synth failed: $e');
      return null;
    }
  }

  /// Descarta as frases pedidas que ainda não começaram (fala cortada).
  /// A que já está sendo gerada termina, mas o WAV dela é apagado.
  void cancelPending() {
    for (final (id, _) in _queue) {
      _pending.remove(id)?.complete(null);
    }
    _queue.clear();
    final cur = _inFlight;
    if (cur != null) _pending.remove(cur)?.complete(null);
  }

  void _pump() {
    final w = _worker;
    if (w == null || _inFlight != null || _queue.isEmpty) return;
    final (id, msg) = _queue.removeAt(0);
    _inFlight = id;
    w.send(msg);
  }

  /// Sobe o worker e carrega o modelo já, para a primeira fala não esperar.
  void _warmUp() {
    if (kIsWeb) return;
    (_spawning ??= _spawn()).then((w) {
      _worker ??= w;
      w.send(const ['warmup']);
    }).catchError((Object e) => debugPrint('NeuralVoice warm-up failed: $e'));
  }

  /// Apaga um WAV já tocado.
  void discard(String path) {
    try {
      File(path).deleteSync();
    } catch (_) {}
  }

  Future<SendPort> _spawn() async {
    final rp = ReceivePort();
    final tmp = (await getTemporaryDirectory()).path;
    final ready = Completer<SendPort>();
    rp.listen((m) {
      if (m is SendPort) {
        ready.complete(m);
      } else if (m is List) {
        if (m.length > 2) debugPrint('NeuralVoice worker: ${m[2]}');
        final id = m[0] as int;
        final path = m[1] as String?;
        if (_inFlight == id) _inFlight = null;
        final c = _pending.remove(id);
        if (c != null) {
          c.complete(path);
        } else if (path != null) {
          discard(path); // ninguém mais quer esse áudio
        }
        _pump();
      }
    });
    await Isolate.spawn(_workerMain, [
      rp.sendPort,
      _modelDir,
      tmp,
    ], debugName: 'pear-tts');
    return ready.future;
  }
}

/// (sid, speed, pitch) por gênero. sid 0–4 = F1–F5, 5–9 = M1–M5.
/// F2 é a mais aguda/brilhante; M1 a masculina mais jovem.
const _voices = {
  'f': (sid: 1, speed: 0.9, pitch: 1.1),
  'm': (sid: 5, speed: 0.93, pitch: 1.07),
};

void _workerMain(List<Object?> args) {
  final out = args[0] as SendPort;
  final dir = args[1] as String;
  final tmp = args[2] as String;
  final inbox = ReceivePort();
  out.send(inbox.sendPort);

  sherpa.OfflineTts? tts;
  inbox.listen((m) {
    if (m == null) {
      tts?.free();
      inbox.close();
      return;
    }
    final req = m as List;
    final warm = req.length == 1 && req[0] == 'warmup';
    final id = warm ? -1 : req[0] as int;
    try {
      if (tts == null) {
        sherpa.initBindings();
        tts = sherpa.OfflineTts(
          sherpa.OfflineTtsConfig(
            model: sherpa.OfflineTtsModelConfig(
              supertonic: sherpa.OfflineTtsSupertonicModelConfig(
                durationPredictor: '$dir/duration_predictor.int8.onnx',
                textEncoder: '$dir/text_encoder.int8.onnx',
                vectorEstimator: '$dir/vector_estimator.int8.onnx',
                vocoder: '$dir/vocoder.int8.onnx',
                ttsJson: '$dir/tts.json',
                unicodeIndexer: '$dir/unicode_indexer.bin',
                voiceStyle: '$dir/voice.bin',
              ),
              numThreads: 2,
            ),
          ),
        );
      }
      if (warm) return;
      final v = _voices[req[3]] ?? _voices['f']!;
      final a = tts!.generateWithConfig(
        text: req[1] as String,
        config: sherpa.OfflineTtsGenerationConfig(
          sid: v.sid,
          speed: v.speed,
          numSteps: 5,
          extra: {'lang': req[2] as String},
        ),
      );
      if (a.samples.isEmpty) {
        out.send([id, null, 'empty audio']);
        return;
      }
      final path = '$tmp/pear_voice_$id.wav';
      _writeWav(
        path,
        _trim(a.samples, a.sampleRate),
        (a.sampleRate * v.pitch).round(),
      );
      out.send([id, path]);
    } catch (e) {
      if (!warm) out.send([id, null, '$e']);
    }
  });
}

/// Corta o silêncio das pontas (deixa 40 ms) para a fala soar mais imediata.
Float32List _trim(Float32List s, int sr) {
  const th = 0.012;
  var a = 0, b = s.length - 1;
  while (a < b && s[a].abs() < th) {
    a++;
  }
  while (b > a && s[b].abs() < th) {
    b--;
  }
  final pad = (sr * 0.04).round();
  a = (a - pad).clamp(0, s.length);
  b = (b + pad).clamp(0, s.length - 1);
  return Float32List.sublistView(s, a, b + 1);
}

void _writeWav(String path, Float32List s, int sampleRate) {
  var peak = 0.0;
  for (final v in s) {
    if (v.abs() > peak) peak = v.abs();
  }
  final gain = peak > 0 ? 0.92 / peak : 1.0;
  final n = s.length;
  final b = ByteData(44 + n * 2);
  void str(int o, String t) {
    for (var i = 0; i < t.length; i++) {
      b.setUint8(o + i, t.codeUnitAt(i));
    }
  }

  str(0, 'RIFF');
  b.setUint32(4, 36 + n * 2, Endian.little);
  str(8, 'WAVE');
  str(12, 'fmt ');
  b.setUint32(16, 16, Endian.little);
  b.setUint16(20, 1, Endian.little);
  b.setUint16(22, 1, Endian.little);
  b.setUint32(24, sampleRate, Endian.little);
  b.setUint32(28, sampleRate * 2, Endian.little);
  b.setUint16(32, 2, Endian.little);
  b.setUint16(34, 16, Endian.little);
  str(36, 'data');
  b.setUint32(40, n * 2, Endian.little);
  for (var i = 0; i < n; i++) {
    b.setInt16(
      44 + i * 2,
      (s[i] * gain * 32767).round().clamp(-32768, 32767),
      Endian.little,
    );
  }
  File(path).writeAsBytesSync(b.buffer.asUint8List());
}
