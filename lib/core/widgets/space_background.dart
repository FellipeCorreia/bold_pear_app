import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/scheduler.dart';
import 'package:material_ui/material_ui.dart';

/// Pede ao céu para "viajar" (ex.: ao escolher uma resposta).
class SkyController {
  final ValueNotifier<int> travels = ValueNotifier(0);
  void travel() => travels.value++;
}

/// Céu estrelado procedural: estrelas em 3 camadas com parallax e cintilação suave,
/// nebulosas, planetas que passam quando o céu viaja e um cometa de vez em quando.
/// Respeita "reduzir movimento" do sistema (céu parado, sem cometas).
class SpaceBackground extends StatefulWidget {
  const SpaceBackground({super.key, required this.sky, required this.location});
  final SkyController sky;

  /// Trocar de tela também faz o céu viajar.
  final String location;

  @override
  State<SpaceBackground> createState() => _SpaceBackgroundState();
}

class _SpaceBackgroundState extends State<SpaceBackground>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_onTick);
  final _sky = _SkyModel();
  final _repaint = ValueNotifier<int>(0);
  bool _calm = false;

  @override
  void initState() {
    super.initState();
    widget.sky.travels.addListener(_travel);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _calm = MediaQuery.disableAnimationsOf(context);
    if (_calm) {
      if (_ticker.isActive) _ticker.stop();
    } else if (!_ticker.isActive) {
      _ticker.start();
    }
  }

  @override
  void didUpdateWidget(SpaceBackground old) {
    super.didUpdateWidget(old);
    if (old.sky != widget.sky) {
      old.sky.travels.removeListener(_travel);
      widget.sky.travels.addListener(_travel);
    }
    if (old.location != widget.location) _travel();
  }

  void _travel() {
    _sky.travel(instant: _calm);
    if (_calm) _repaint.value++;
  }

  void _onTick(Duration d) {
    _sky.update(d.inMicroseconds / 1e6);
    _repaint.value++;
  }

  @override
  void dispose() {
    widget.sky.travels.removeListener(_travel);
    _ticker.dispose();
    _repaint.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _SkyPainter(_sky, _repaint, calm: _calm),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _Star {
  _Star(this.x, this.y, this.r, this.a, this.phase, this.speed, this.color);
  final double x, y, r, a, phase, speed;
  final Color color;
}

class _Planet {
  _Planet({
    required this.wx,
    required this.y,
    required this.r,
    required this.base,
    required this.light,
    required this.dark,
    required this.band,
    this.ring,
    this.tilt = 0,
    this.craters = false,
    required this.seed,
  });
  final double wx, y, r, tilt;
  final Color base, light, dark, band;
  final Color? ring;
  final bool craters;
  final int seed;
}

class _Comet {
  _Comet(this.start, this.x, this.y, this.angle, this.speed, this.length);
  final double start, x, y, angle, speed, length;
  static const life = 1.8;
}

/// Estado da "câmera" e dos elementos do céu (em frações da tela, para independer do tamanho).
class _SkyModel {
  final _rng = Random(42);
  late final List<List<_Star>> layers = [
    _stars(150, .25, .9, .25, .65),
    _stars(55, .6, 1.4, .45, .85),
    _stars(16, 1.1, 1.9, .7, 1),
  ];
  static const parallax = [.04, .12, .28];
  static const planetParallax = .55;
  static const worldW = 5.0; // largura do "mundo" dos planetas, em telas

  late final List<_Planet> planets = _planets();
  final comets = <_Comet>[];

  double t = 0;
  double camX = 0, camY = 0, velX = 0;
  double _fromX = 0, _fromY = 0, _toX = 0, _toY = 0, _travelStart = -10;
  static const _travelDur = 2.6;
  double _nextComet = 7 + Random().nextDouble() * 8;

  List<_Star> _stars(
    int n,
    double rMin,
    double rMax,
    double aMin,
    double aMax,
  ) => List.generate(n, (_) {
    final blue = _rng.nextDouble();
    final color = blue < .18
        ? const Color(0xFF9FC4FF)
        : blue < .26
        ? const Color(0xFFFFE2B0)
        : const Color(0xFFFFFFFF);
    return _Star(
      _rng.nextDouble(),
      _rng.nextDouble(),
      rMin + _rng.nextDouble() * (rMax - rMin),
      aMin + _rng.nextDouble() * (aMax - aMin),
      _rng.nextDouble() * pi * 2,
      .4 + _rng.nextDouble() * 1.2,
      color,
    );
  });

  List<_Planet> _planets() => [
    _Planet(
      wx: .12,
      y: .2,
      r: 46,
      base: const Color(0xFFE8963A),
      light: const Color(0xFFFFD08A),
      dark: const Color(0xFF7A3E12),
      band: const Color(0xFFFFF0D0),
      ring: const Color(0xFFF3D9A8),
      tilt: -.32,
      seed: 1,
    ),
    _Planet(
      wx: .95,
      y: .72,
      r: 22,
      base: const Color(0xFF7FA8C9),
      light: const Color(0xFFD8ECFF),
      dark: const Color(0xFF243B57),
      band: const Color(0xFFFFFFFF),
      craters: true,
      seed: 2,
    ),
    _Planet(
      wx: 1.75,
      y: .3,
      r: 36,
      base: const Color(0xFF2FA39A),
      light: const Color(0xFFA8F0E2),
      dark: const Color(0xFF0B3C44),
      band: const Color(0xFFCFFFF5),
      seed: 3,
    ),
    _Planet(
      wx: 2.6,
      y: .82,
      r: 16,
      base: const Color(0xFF9A7BD0),
      light: const Color(0xFFE2D4FF),
      dark: const Color(0xFF34245A),
      band: const Color(0xFFFFFFFF),
      craters: true,
      seed: 4,
    ),
    _Planet(
      wx: 3.3,
      y: .16,
      r: 30,
      base: const Color(0xFFB3BB12),
      light: const Color(0xFFEFF59A),
      dark: const Color(0xFF3D4219),
      band: const Color(0xFFFFFFE0),
      ring: const Color(0xFFDCE38A),
      tilt: .25,
      seed: 5,
    ),
    _Planet(
      wx: 4.15,
      y: .6,
      r: 26,
      base: const Color(0xFFC75B3F),
      light: const Color(0xFFFFB99A),
      dark: const Color(0xFF4A1A10),
      band: const Color(0xFFFFD5C4),
      craters: true,
      seed: 6,
    ),
  ];

  void travel({bool instant = false}) {
    _fromX = camX;
    _fromY = camY;
    _toX = camX + .7 + _rng.nextDouble() * .45;
    _toY = (_rng.nextDouble() - .5) * .16;
    _travelStart = t;
    if (instant) {
      camX = _toX;
      camY = _toY;
      _travelStart = -10;
    }
  }

  void update(double now) {
    final dt = (now - t).clamp(0.0, .1);
    t = now;
    final prevX = camX;
    final p = (t - _travelStart) / _travelDur;
    if (p >= 0 && p < 1) {
      final e = p < .5 ? 4 * p * p * p : 1 - pow(-2 * p + 2, 3) / 2;
      camX = _fromX + (_toX - _fromX) * e;
      camY = _fromY + (_toY - _fromY) * e;
      _toX += .004 * dt;
    } else {
      camX += .004 * dt; // deriva lenta: o céu nunca fica totalmente parado
      if (p >= 1) camY = _toY;
    }
    velX = dt > 0 ? (camX - prevX) / dt : 0;

    comets.removeWhere((c) => t - c.start > _Comet.life);
    if (t > _nextComet) {
      final fromLeft = _rng.nextBool();
      final angle =
          (fromLeft ? .45 : pi - .45) + (_rng.nextDouble() - .5) * .35;
      comets.add(
        _Comet(
          t,
          fromLeft ? _rng.nextDouble() * .5 : .5 + _rng.nextDouble() * .5,
          _rng.nextDouble() * .35,
          angle,
          .35 + _rng.nextDouble() * .2,
          .16 + _rng.nextDouble() * .1,
        ),
      );
      _nextComet = t + 22 + _rng.nextDouble() * 30;
    }
  }
}

class _SkyPainter extends CustomPainter {
  _SkyPainter(this.m, Listenable repaint, {required this.calm})
    : super(repaint: repaint);
  final _SkyModel m;
  final bool calm;

  static double _wrap(double v, double w) => ((v % w) + w) % w;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    if (w <= 0 || h <= 0) return;
    final rect = Offset.zero & size;
    final scale = (size.shortestSide / 420).clamp(.8, 1.6);

    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero,
          Offset(0, h),
          const [Color(0xFF060A18), Color(0xFF0B1328), Color(0xFF121A30)],
          const [0, .55, 1],
        ),
    );

    _nebulae(canvas, size);

    // Estrelas: quanto mais perto, mais parallax e (durante a viagem) um leve rastro.
    final paint = Paint();
    final stretch = (m.velX.abs() * w * .018).clamp(0.0, 14.0);
    for (var li = 0; li < m.layers.length; li++) {
      final px = m.camX * _SkyModel.parallax[li] * w;
      final py = m.camY * _SkyModel.parallax[li] * h;
      final trail = stretch * (li + 1) / 3;
      for (final s in m.layers[li]) {
        final x = _wrap(s.x * w - px, w);
        final y = _wrap(s.y * h - py, h);
        final tw = calm ? 1.0 : .62 + .38 * sin(m.t * s.speed + s.phase);
        paint.color = s.color.withValues(alpha: (s.a * tw).clamp(0, 1));
        final r = s.r * scale;
        if (trail > 1.5 && li > 0) {
          paint
            ..strokeWidth = r * 1.6
            ..strokeCap = StrokeCap.round;
          canvas.drawLine(
            Offset(x, y),
            Offset(x + trail * m.velX.sign, y),
            paint,
          );
        } else {
          canvas.drawCircle(Offset(x, y), r, paint);
        }
        if (li == 2 && tw > .9) {
          _sparkle(
            canvas,
            Offset(x, y),
            r * 4 * (tw - .9) * 10,
            s.color.withValues(alpha: .35 * s.a),
          );
        }
      }
    }

    // Planetas no "mundo" de 5 telas: entram e saem conforme a câmera viaja.
    final worldPx = _SkyModel.worldW * w;
    for (final p in m.planets) {
      final r = p.r * scale;
      final x = _wrap(
        p.wx * w - m.camX * _SkyModel.planetParallax * w,
        worldPx,
      );
      final y = p.y * h - m.camY * _SkyModel.planetParallax * h * .5;
      for (final xx in [x, x - worldPx]) {
        if (xx > -r * 3 && xx < w + r * 3) _planet(canvas, Offset(xx, y), r, p);
      }
    }

    if (!calm) {
      for (final c in m.comets) {
        _comet(canvas, size, c);
      }
    }
  }

  void _nebulae(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    const blobs = [
      (x: .15, y: .25, r: .75, c: Color(0xFF5B3FA0), a: .16),
      (x: .85, y: .65, r: .7, c: Color(0xFF1F6F8B), a: .14),
      (x: .55, y: .95, r: .6, c: Color(0xFFF7A128), a: .05),
    ];
    for (final b in blobs) {
      final c = Offset(
        _wrap(b.x * w - m.camX * .03 * w, w * 1.4) - w * .2,
        b.y * h,
      );
      final r = b.r * size.longestSide * .6;
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..shader = ui.Gradient.radial(c, r, [
            b.c.withValues(alpha: b.a),
            b.c.withValues(alpha: 0),
          ]),
      );
    }
  }

  void _sparkle(Canvas canvas, Offset c, double len, Color color) {
    if (len < 1) return;
    final p = Paint()
      ..color = color
      ..strokeWidth = .8;
    canvas.drawLine(c.translate(-len, 0), c.translate(len, 0), p);
    canvas.drawLine(c.translate(0, -len), c.translate(0, len), p);
  }

  void _planet(Canvas canvas, Offset c, double r, _Planet p) {
    // halo
    canvas.drawCircle(
      c,
      r * 1.6,
      Paint()
        ..shader = ui.Gradient.radial(c, r * 1.6, [
          p.light.withValues(alpha: .14),
          p.light.withValues(alpha: 0),
        ]),
    );
    final ringRect = Rect.fromCenter(
      center: Offset.zero,
      width: r * 3.6,
      height: r * .9,
    );
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * .18
      ..color = (p.ring ?? Colors.transparent).withValues(alpha: .55);
    if (p.ring != null) {
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(p.tilt);
      canvas.drawArc(ringRect, pi, pi, false, ringPaint);
      canvas.restore();
    }

    final body = Rect.fromCircle(center: c, radius: r);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = ui.Gradient.radial(
          c.translate(-r * .4, -r * .45),
          r * 1.5,
          [p.light, p.base, p.dark],
          const [0, .45, 1],
        ),
    );

    canvas.save();
    canvas.clipPath(Path()..addOval(body));
    final rng = Random(p.seed);
    if (p.craters) {
      for (var i = 0; i < 6; i++) {
        final a = rng.nextDouble() * pi * 2, d = rng.nextDouble() * r * .75;
        canvas.drawCircle(
          c + Offset(cos(a) * d, sin(a) * d),
          r * (.08 + rng.nextDouble() * .14),
          Paint()..color = p.dark.withValues(alpha: .35),
        );
      }
    } else {
      canvas.translate(c.dx, c.dy);
      canvas.rotate(p.tilt);
      for (var i = 0; i < 5; i++) {
        final y = -r + (i + .5) * r * 2 / 5 + (rng.nextDouble() - .5) * r * .2;
        canvas.drawRect(
          Rect.fromLTWH(-r, y, r * 2, r * (.08 + rng.nextDouble() * .16)),
          Paint()
            ..color = p.band.withValues(alpha: .13 + rng.nextDouble() * .1),
        );
      }
      canvas.rotate(-p.tilt);
      canvas.translate(-c.dx, -c.dy);
    }
    // sombra do lado oposto à luz
    canvas.drawRect(
      body,
      Paint()
        ..shader = ui.Gradient.linear(
          body.topLeft,
          body.bottomRight,
          [
            const Color(0x00000000),
            const Color(0x00000000),
            const Color(0x99000000),
          ],
          const [0, .5, 1],
        ),
    );
    canvas.restore();

    if (p.ring != null) {
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(p.tilt);
      canvas.drawArc(ringRect, 0, pi, false, ringPaint);
      canvas.restore();
    }
  }

  void _comet(Canvas canvas, Size size, _Comet c) {
    final age = m.t - c.start;
    final p = age / _Comet.life;
    final fade = sin(pi * p.clamp(0, 1));
    final dir = Offset(cos(c.angle), sin(c.angle));
    final head =
        Offset(c.x * size.width, c.y * size.height) +
        dir * (age * c.speed * size.longestSide);
    final tail = head - dir * (c.length * size.longestSide);
    canvas.drawLine(
      tail,
      head,
      Paint()
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round
        ..shader = ui.Gradient.linear(tail, head, [
          const Color(0x00BFD8FF),
          Color.fromRGBO(220, 235, 255, .75 * fade),
        ]),
    );
    canvas.drawCircle(
      head,
      6,
      Paint()
        ..shader = ui.Gradient.radial(head, 6, [
          Color.fromRGBO(255, 255, 255, .9 * fade),
          const Color(0x00FFFFFF),
        ]),
    );
  }

  @override
  bool shouldRepaint(_SkyPainter old) => old.calm != calm || old.m != m;
}
