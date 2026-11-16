import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

import '../voice/voice_service.dart';
import 'pear_controller.dart';

/// Toque na pera: escolhe uma reação (pulo, giro, amassadinho, risadinha...),
/// anima a pera 3D e toca o som correspondente. Muitos toques seguidos deixam ela tonta.
class PearTouch {
  PearTouch(this.pear, this.voice);

  final PearController pear;
  final VoiceService voice;
  final _rng = Random();
  final _players = List.generate(
    2,
    (i) => AudioPlayer(playerId: 'pear-sfx-$i'),
  );
  var _next = 0;
  final _taps = <DateTime>[];
  String _last = '';

  static const _reactions = {
    'jump': 'boing',
    'spin': 'sparkle',
    'squish': 'squeak',
    'giggle': 'giggle',
    'wiggle': 'pop',
  };

  void tap() {
    final now = DateTime.now();
    _taps
      ..add(now)
      ..removeWhere(
        (t) => now.difference(t) > const Duration(milliseconds: 2200),
      );
    String r;
    if (_taps.length >= 5) {
      r = 'dizzy';
      _taps.clear();
    } else {
      final options = _reactions.keys.where((k) => k != _last).toList();
      r = options[_rng.nextInt(options.length)];
    }
    _last = r;
    pear.reactTo(r);
    HapticFeedback.lightImpact();
    if (!voice.muted.value) _play(r == 'dizzy' ? 'dizzy' : _reactions[r]!);
  }

  Future<void> _play(String sfx) async {
    final p = _players[_next++ % _players.length];
    try {
      await p.stop();
      await p.setVolume(.7);
      await p.play(AssetSource('sfx/$sfx.wav'));
    } catch (_) {}
  }
}
