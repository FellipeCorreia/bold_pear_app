import 'package:flutter/foundation.dart';

import 'neural_voice_status.dart';

export 'neural_voice_status.dart';

/// Web: sem voz neural, o app usa o TTS do navegador.
class NeuralVoice {
  final ValueNotifier<NeuralVoiceStatus> status = ValueNotifier(
    NeuralVoiceStatus.unsupported,
  );
  final ValueNotifier<double> progress = ValueNotifier(0);

  bool get ready => false;
  Future<void> init() async {}
  void discard(String path) {}
  Future<String?> synth(
    String text, {
    required String lang,
    required String gender,
  }) async => null;
}
