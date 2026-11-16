import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

import '../../../core/config/env.dart';
import 'neural_voice_status.dart';

export 'neural_voice_status.dart';

/// Voz neural offline da Bold Pear: Supertonic 3 (31 idiomas, OpenRAIL-M) via sherpa-onnx.
///
/// O modelo (~138 MB) não vai dentro do app: é baixado na primeira abertura, direto para o
/// armazenamento interno, arquivo por arquivo. O download retoma de onde parou se a conexão
/// cair, e cada arquivo é conferido (tamanho + SHA-256) antes de a voz ser ativada.
/// Enquanto isso (ou se falhar) a pera usa a voz do sistema.
///
/// A síntese roda num isolate próprio para não travar as animações. O tom fica
/// "de personagem" com um truque barato: gera um pouco mais devagar e grava o WAV
/// com sample rate maior (pitch sobe, ritmo volta ao normal).
class NeuralVoice {
  static const _dirName = 'supertonic-3-int8';
  static const _version = 'supertonic3-int8-2026-05-11';

  /// Arquivos do modelo, como publicados pelo sherpa-onnx (revisão fixada em [Env.voiceModelUrl]).
  static const _files = {
    'vector_estimator.int8.onnx': (bytes: 78400833, sha256: '20cd86fa5c6effedfda0e7cffe5b0569ca401c440a0c3a1d72bf39286c0db3fd'),
    'text_encoder.int8.onnx': (bytes: 36416150, sha256: 'c7befd5ea8c3119769e8a6c1486c4edc6a3bc8365c67621c881bbb774b9902ff'),
    'vocoder.int8.onnx': (bytes: 25991073, sha256: 'e923d60f53f95eb1ce235f1dc33ec56d9c057823c96fa6f8acf98f32b0da6152'),
    'duration_predictor.int8.onnx': (bytes: 3700147, sha256: 'c3eb91414d5ff8a7a239b7fe9e34e7e2bf8a8140d8375ffb14718b1c639325db'),
    'voice.bin': (bytes: 517168, sha256: '67d5209b0ee8ce6c74105ffbe12fe6a7628aea3b4ba2fcb308a4a67938a93ce8'),
    'unicode_indexer.bin': (bytes: 262144, sha256: '8402ca48e5189a8950138580b0fff64db6f072f24ac07cd54ba8b2fbb9883b30'),
    'tts.json': (bytes: 8253, sha256: '42078d3aef1cd43ab43021f3c54f47d2d75ceb4e75f627f118890128b06a0d09'),
  };

  /// Tamanho total do download, em bytes.
  static final int totalBytes = _files.values.fold(0, (a, f) => a + f.bytes);

  final ValueNotifier<NeuralVoiceStatus> status = ValueNotifier(NeuralVoiceStatus.absent);

  /// Fração baixada (0–1).
  final ValueNotifier<double> progress = ValueNotifier(0);

  /// Bytes já no disco (para mostrar "x de y MB").
  int downloadedBytes = 0;

  /// Motivo da última falha (para diagnóstico).
  Object? lastError;

  Directory? _root;
  Future<void>? _installing;
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

  /// Deixa a voz pronta: usa a cópia já instalada ou baixa o modelo.
  Future<void> init() => _installing ??= _init().whenComplete(() => _installing = null);

  /// Tenta de novo depois de uma falha (ex.: sem internet). Retoma o que já veio.
  Future<void> retry() => init();

  Future<void> _init() async {
    try {
      _root ??= Directory('${(await getApplicationSupportDirectory()).path}/voices');
      final marker = File('$_modelDir/.ok');
      if (marker.existsSync() && marker.readAsStringSync() == _version) {
        status.value = NeuralVoiceStatus.ready;
        _warmUp();
        return;
      }
      await _download(marker);
      _warmUp();
    } catch (e) {
      debugPrint('NeuralVoice download failed: $e');
      lastError = e;
      status.value = NeuralVoiceStatus.error;
    }
  }

  Future<void> _download(File marker) async {
    status.value = NeuralVoiceStatus.installing;
    final dir = Directory(_modelDir)..createSync(recursive: true);
    final http = HttpClient()
      ..connectionTimeout = const Duration(seconds: 20)
      ..idleTimeout = const Duration(seconds: 30)
      ..userAgent = 'BoldPear';
    try {
      var done = 0;
      void report(int current) {
        downloadedBytes = done + current;
        progress.value = downloadedBytes / totalBytes;
      }

      for (final MapEntry(key: name, value: spec) in _files.entries) {
        final file = File('${dir.path}/$name');
        // Já baixado e conferido numa tentativa anterior: pula.
        final ok = file.existsSync() && file.lengthSync() == spec.bytes && await _sha256(file) == spec.sha256;
        if (!ok) {
          await fetchFile(http, '${Env.voiceModelUrl}/$name', file, spec.bytes, report);
          if (await _sha256(file) != spec.sha256) {
            file.deleteSync();
            throw StateError('checksum mismatch: $name');
          }
        }
        done += spec.bytes;
        report(0);
      }
      marker.writeAsStringSync(_version);
      status.value = NeuralVoiceStatus.ready;
    } finally {
      http.close(force: true);
    }
  }

  /// Baixa [url] para [dest] via um `.part`, retomando (HTTP Range) o que já veio.
  @visibleForTesting
  static Future<void> fetchFile(HttpClient http, String url, File dest, int size, void Function(int) report) async {
    final part = File('${dest.path}.part');
    var have = part.existsSync() ? part.lengthSync() : 0;
    if (have > size) {
      part.deleteSync();
      have = 0;
    }
    report(have);
    if (have < size) {
      // Redirecionamentos na mão: o Hugging Face manda para a CDN e o Range precisa ir junto.
      var uri = Uri.parse(url);
      HttpClientResponse res;
      for (var hops = 0;; hops++) {
        final req = await http.getUrl(uri);
        req.followRedirects = false;
        if (have > 0) req.headers.set(HttpHeaders.rangeHeader, 'bytes=$have-');
        res = await req.close();
        if (!res.isRedirect) break;
        await res.drain<void>();
        final loc = res.headers.value(HttpHeaders.locationHeader);
        if (loc == null || hops >= 5) throw HttpException('too many redirects', uri: uri);
        uri = uri.resolve(loc);
      }
      if (res.statusCode == HttpStatus.ok) {
        have = 0; // o servidor ignorou o Range: recomeça do zero
      } else if (res.statusCode != HttpStatus.partialContent) {
        await res.drain<void>();
        throw HttpException('HTTP ${res.statusCode}', uri: uri);
      }
      final sink = part.openWrite(mode: have == 0 ? FileMode.write : FileMode.append);
      try {
        await for (final chunk in res.timeout(const Duration(seconds: 30))) {
          sink.add(chunk);
          have += chunk.length;
          report(have);
        }
      } finally {
        await sink.close();
      }
    }
    if (part.lengthSync() != size) throw StateError('incomplete download: ${dest.path}');
    if (dest.existsSync()) dest.deleteSync();
    part.renameSync(dest.path);
  }

  /// SHA-256 do arquivo, calculado fora da thread de UI.
  @visibleForTesting
  static Future<String> sha256Of(File f) => _sha256(f);

  static Future<String> _sha256(File f) {
    final path = f.path;
    return Isolate.run(() async => (await sha256.bind(File(path).openRead()).first).toString());
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
