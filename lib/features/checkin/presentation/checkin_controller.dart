import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../../app/app_state.dart';
import '../data/checkin_repository.dart';
import '../domain/checkin.dart';
import '../domain/score_alert.dart';

enum CheckinSection { phq, difficulty, gad }

enum CheckinStage { idle, running, finished }

class CheckinQuestion {
  const CheckinQuestion(
    this.label,
    this.index,
    this.count,
    this.text,
    this.options,
  );
  final String label;
  final int index;
  final int count;
  final String text;
  final List<String> options;
}

/// Conduz o check-in falado: PHQ-9 → impacto (se houver sintoma) → GAD-7.
class CheckinController extends ChangeNotifier {
  CheckinController(this.app);

  final AppState app;
  final _rnd = Random();

  CheckinStage stage = CheckinStage.idle;
  CheckinSection section = CheckinSection.phq;
  int qi = 0;
  List<int?> _phq = List.filled(9, null);
  List<int?> _gad = List.filled(7, null);
  int? _difficulty;
  bool busy = false;
  Checkin? last;
  bool saveFailed = false;

  /// Alertas de limite do último check-in (comparado aos registros anteriores).
  List<ScoreAlert> alerts = const [];
  Future<List<Checkin>>? _history;
  int _run = 0;

  int get _phqSum => _phq.fold(0, (a, b) => a + (b ?? 0));

  CheckinQuestion get current {
    final t = app.t;
    final s = t.scales;
    final phq = s['phq'] as Map<String, dynamic>;
    final gad = s['gad'] as Map<String, dynamic>;
    String compose(Map<String, dynamic> m) {
      final stem = (m['stem'] as String?) ?? '';
      final item = (m['items'] as List)[qi] as String;
      return t.f(stem.isEmpty ? item : '$stem $item');
    }

    List<String> opts(Object? o) => (o as List).cast<String>();
    switch (section) {
      case CheckinSection.phq:
        return CheckinQuestion('PHQ-9', qi, 9, compose(phq), opts(phq['opts']));
      case CheckinSection.difficulty:
        return CheckinQuestion(
          'PHQ-9',
          0,
          1,
          t.f(phq['diff'] as String),
          opts(phq['diffOpts']),
        );
      case CheckinSection.gad:
        return CheckinQuestion('GAD-7', qi, 7, compose(gad), opts(gad['opts']));
    }
  }

  Future<void> start() async {
    final my = ++_run;
    _phq = List.filled(9, null);
    _gad = List.filled(7, null);
    _difficulty = null;
    section = CheckinSection.phq;
    qi = 0;
    busy = true;
    saveFailed = false;
    alerts = const [];
    // Linha de base buscada já no início, antes de salvar o novo check-in.
    _history = CheckinRepository(app.sb)
        .list(limit: AlertEngine.baselineSize)
        .catchError((_) => const <Checkin>[]);
    stage = CheckinStage.running;
    notifyListeners();
    final t = app.t;
    await app.voice.say(t.pear('intro'), expr: 'happy');
    if (my != _run) return;
    await app.voice.say(t.pear('phqIntro'), expr: 'neutral');
    if (my != _run) return;
    _ask();
  }

  void _ask() {
    busy = false;
    notifyListeners();
    final q = current;
    var text = q.text;
    if (q.index == 0 && section != CheckinSection.difficulty)
      text = '$text ${app.t.hint(q.options)}';
    final concern = section == CheckinSection.phq && qi == 8;
    app.voice.say(text, expr: concern ? 'concern' : 'neutral');
  }

  void repeat() {
    if (!busy && stage == CheckinStage.running) _ask();
  }

  Future<void> answer(int k) async {
    if (busy || stage != CheckinStage.running) return;
    busy = true;
    await app.voice.stop();
    final t = app.t;
    final acks = t.acks;
    var line = acks[_rnd.nextInt(acks.length)];
    switch (section) {
      case CheckinSection.phq:
        _phq[qi] = k;
        if (qi < 8) {
          qi++;
        } else if (_phqSum > 0) {
          section = CheckinSection.difficulty;
          qi = 0;
        } else {
          section = CheckinSection.gad;
          qi = 0;
          line = t.pear('gadIntro');
        }
      case CheckinSection.difficulty:
        _difficulty = k;
        section = CheckinSection.gad;
        qi = 0;
        line = t.pear('gadIntro');
      case CheckinSection.gad:
        _gad[qi] = k;
        if (qi < 6) {
          qi++;
        } else {
          return _finish();
        }
    }
    notifyListeners();
    final my = _run;
    await app.voice.say(line, expr: 'happy');
    if (my != _run) return;
    _ask();
  }

  Future<void> _finish() async {
    final c = Checkin(
      createdAt: DateTime.now(),
      language: app.lang,
      phqItems: _phq.map((e) => e ?? 0).toList(),
      gadItems: _gad.map((e) => e ?? 0).toList(),
      phqDifficulty: _difficulty,
    );
    final history = await (_history ?? Future.value(const <Checkin>[]));
    last = c;
    alerts = AlertEngine.evaluate(c, history);
    busy = false;
    stage = CheckinStage.finished;
    notifyListeners();
    try {
      await CheckinRepository(app.sb).save(c);
    } catch (_) {
      saveFailed = true;
      notifyListeners();
    }
  }

  /// Fala do resultado (chamada pela tela de resultados).
  Future<void> speakSummary() async {
    final c = last;
    if (c == null) return;
    final my = ++_run;
    final t = app.t;
    await app.voice.say(t.pear('end'), expr: 'happy');
    if (my != _run) return;
    if (c.item9Positive) {
      await app.voice.say(t.pear('safety'), expr: 'concern');
      if (my != _run) return;
    }
    final lv = c.level;
    await app.voice.say(
      t.pear(
        lv == 'calm'
            ? 'sumCalm'
            : lv == 'mid'
            ? 'sumMid'
            : 'sumHigh',
      ),
      expr: lv == 'calm'
          ? 'happy'
          : lv == 'high'
          ? 'concern'
          : 'neutral',
    );
    if (my == _run) app.pear.set(expr: 'neutral');
  }

  void cancel() {
    _run++;
    app.voice.stop();
    app.pear.set(expr: 'neutral'); // nova linha
  }
}
