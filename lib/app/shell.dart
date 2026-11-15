import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../core/theme/pi_cores.dart';
import '../core/widgets/space_background.dart';
import '../core/widgets/ui.dart';
import '../features/avatar/pear_controller.dart';
import '../features/avatar/pear_touch.dart';
import '../features/avatar/pear_view.dart';
import 'app_state.dart';

/// Moldura comum: a Bold Pear fica viva em todas as telas, acima (ou ao lado) do conteúdo.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.location, required this.child});
  final String location;
  final Widget child;

  static const _compact = {'/home', '/settings'};

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final compact = _compact.contains(location);
    return Stack(children: [
      // Céu estrelado vivo atrás de todas as telas.
      Positioned.fill(child: SpaceBackground(sky: context.read<SkyController>(), location: location)),
      Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(children: [
            _TopBar(location: location),
            Expanded(
              child: LayoutBuilder(builder: (context, c) {
                final wide = c.maxWidth >= 900;
                final pear = _PearStage(size: wide ? 380 : (compact ? 150 : 240), showSubtitles: app.cc || app.muted);
                if (wide) {
                  return Row(children: [
                    Expanded(flex: 5, child: Center(child: SingleChildScrollView(child: pear))),
                    Expanded(flex: 6, child: child),
                  ]);
                }
                return Column(children: [pear, Expanded(child: child)]);
              }),
            ),
          ]),
        ),
      ),
    ]);
  }
}

class _PearStage extends StatelessWidget {
  const _PearStage({required this.size, required this.showSubtitles});
  final double size;
  final bool showSubtitles;

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    final pear = context.read<PearController>();
    return Column(mainAxisSize: MainAxisSize.min, children: [
      // Tocar na pera: ela reage (pulo, giro, risadinha...) com som.
      Semantics(
        button: true,
        label: 'Bold Pear',
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: context.read<PearTouch>().tap,
            // Arrastos em cima da pera não rolam nada (nem a WebView nativa por baixo).
            onVerticalDragUpdate: (_) {},
            onHorizontalDragUpdate: (_) {},
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              width: size,
              height: size,
              child: PearView(controller: pear),
            ),
          ),
        ),
      ),
      ValueListenableBuilder<bool>(
        valueListenable: app.voice.noVoice,
        builder: (context, noVoice, _) => ValueListenableBuilder<String>(
          valueListenable: app.voice.subtitle,
          builder: (context, text, _) {
            if (!(showSubtitles || noVoice) || text.isEmpty) return const SizedBox(height: 6);
            return Container(
              constraints: const BoxConstraints(maxWidth: 460),
              margin: const EdgeInsets.fromLTRB(16, 4, 16, 10),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              decoration: BoxDecoration(
                color: PiCores.marinho.withValues(alpha: .94),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: PiCores.marinhoBorda),
              ),
              child: Text(text,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, height: 1.4)),
            );
          },
        ),
      ),
    ]);
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.location});
  final String location;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final t = app.t;
    final canSettings = app.loggedIn && (app.profile?.onboarded ?? false) && location == '/home';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 4),
      child: Row(children: [
        const BrandBadge(size: 38),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Bold Pear', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
            Text(t.ui('appTag'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: PiCores.textoSuave)),
          ]),
        ),
        IconButton(
          tooltip: t.ui(app.muted ? 'unmute' : 'mute'),
          onPressed: app.toggleMute,
          icon: Icon(app.muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
              color: app.muted ? PiCores.laranja : PiCores.textoSuave),
        ),
        IconButton(
          tooltip: t.ui('subtitles'),
          onPressed: app.toggleCc,
          icon: Icon(app.cc ? Icons.closed_caption : Icons.closed_caption_off_outlined,
              color: app.cc ? PiCores.lima : PiCores.textoSuave),
        ),
        if (canSettings)
          IconButton(
            tooltip: t.ui('settings'),
            onPressed: () => context.push('/settings'),
            icon: const Icon(Icons.tune_rounded, color: PiCores.textoSuave),
          ),
      ]),
    );
  }
}
