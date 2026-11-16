import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:bold_pear/features/voice/neural/neural_voice_io.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

/// Servidor local (socket cru) que imita o Hugging Face: /resolve/x → 302 para /cdn/x,
/// que aceita Range. Com [dropAfter], a primeira resposta da CDN é cortada no meio.
class FakeHub {
  FakeHub(this.data, {this.dropAfter, this.ignoreRange = false});
  final Uint8List data;
  final int? dropAfter;
  final bool ignoreRange;
  final ranges = <String?>[];
  late ServerSocket _server;
  var _cdnHits = 0;

  static const crlf = '\r\n';

  String get url => 'http://127.0.0.1:${_server.port}/resolve/model.bin';

  Future<void> start() async {
    _server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    _server.listen(_handle);
  }

  void _handle(Socket socket) {
    final buf = <int>[];
    late StreamSubscription<Uint8List> sub;
    sub = socket.listen((chunk) async {
      buf.addAll(chunk);
      final text = String.fromCharCodes(buf);
      if (!text.contains('$crlf$crlf')) return;
      await sub.cancel();
      final lines = text.split(crlf);
      final path = lines.first.split(' ')[1];
      String? range;
      for (final l in lines.skip(1)) {
        if (l.toLowerCase().startsWith('range:')) range = l.substring(6).trim();
      }
      if (path.startsWith('/resolve/')) {
        socket.add('HTTP/1.1 302 Found${crlf}Location: /cdn/model.bin?sig=abc$crlf'
                'Content-Length: 0${crlf}Connection: close$crlf$crlf'
            .codeUnits);
        await socket.flush();
        await socket.close();
        return;
      }
      _cdnHits++;
      ranges.add(range);
      var from = 0;
      var head = 'HTTP/1.1 200 OK$crlf';
      if (range != null && !ignoreRange) {
        from = int.parse(RegExp(r'bytes=(\d+)-').firstMatch(range)!.group(1)!);
        head = 'HTTP/1.1 206 Partial Content${crlf}Content-Range: bytes $from-${data.length - 1}/${data.length}$crlf';
      }
      socket.add('${head}Content-Length: ${data.length - from}${crlf}Connection: close$crlf$crlf'.codeUnits);
      if (_cdnHits == 1 && dropAfter != null) {
        socket.add(data.sublist(from, from + dropAfter!));
        await socket.flush();
        socket.destroy(); // conexão perdida no meio do arquivo
        return;
      }
      socket.add(data.sublist(from));
      await socket.flush();
      await socket.close();
    });
  }

  Future<void> stop() => _server.close();
}

void main() {
  late Directory tmp;
  final rnd = Random(7);
  final data = Uint8List.fromList(List.generate(300000, (_) => rnd.nextInt(256)));
  final digest = sha256.convert(data).toString();

  setUp(() => tmp = Directory.systemTemp.createTempSync('pear_voice_test'));
  tearDown(() => tmp.deleteSync(recursive: true));

  Future<void> withHub(FakeHub hub, Future<void> Function(HttpClient http, File dest) body) async {
    await hub.start();
    final http = HttpClient();
    try {
      await body(http, File('${tmp.path}/model.bin'));
    } finally {
      http.close(force: true);
      await hub.stop();
    }
  }

  test('segue o redirecionamento e baixa tudo, com progresso até 100%', () async {
    final hub = FakeHub(data);
    await withHub(hub, (http, dest) async {
      var last = 0;
      await NeuralVoice.fetchFile(http, hub.url, dest, data.length, (n) => last = n);
      expect(await NeuralVoice.sha256Of(dest), digest);
      expect(last, data.length);
      expect(File('${dest.path}.part').existsSync(), isFalse);
      expect(hub.ranges.single, isNull, reason: 'primeira tentativa sem Range');
    });
  });

  test('conexão cai no meio: falha, e a nova tentativa retoma com Range', () async {
    final hub = FakeHub(data, dropAfter: 120000);
    await withHub(hub, (http, dest) async {
      await expectLater(NeuralVoice.fetchFile(http, hub.url, dest, data.length, (_) {}), throwsA(anything));
      final part = File('${dest.path}.part');
      expect(part.existsSync(), isTrue);
      final kept = part.lengthSync();
      expect(kept, inExclusiveRange(0, data.length));
      expect(dest.existsSync(), isFalse, reason: 'arquivo incompleto nunca é ativado');

      await NeuralVoice.fetchFile(http, hub.url, dest, data.length, (_) {});
      expect(hub.ranges.last, 'bytes=$kept-', reason: 'o Range sobrevive ao redirecionamento');
      expect(await NeuralVoice.sha256Of(dest), digest);
    });
  }, timeout: const Timeout(Duration(seconds: 20)));

  test('servidor que ignora o Range: recomeça do zero sem corromper', () async {
    final hub = FakeHub(data, ignoreRange: true);
    await withHub(hub, (http, dest) async {
      File('${dest.path}.part').writeAsBytesSync(data.sublist(0, 5000));
      await NeuralVoice.fetchFile(http, hub.url, dest, data.length, (_) {});
      expect(await NeuralVoice.sha256Of(dest), digest);
    });
  });

  test('.part maior que o esperado é descartado', () async {
    final hub = FakeHub(data);
    await withHub(hub, (http, dest) async {
      File('${dest.path}.part').writeAsBytesSync(Uint8List(data.length + 10));
      await NeuralVoice.fetchFile(http, hub.url, dest, data.length, (_) {});
      expect(await NeuralVoice.sha256Of(dest), digest);
      expect(hub.ranges.single, isNull);
    });
  });
}
