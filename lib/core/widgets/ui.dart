import 'package:material_ui/material_ui.dart';

import '../theme/pi_cores.dart';

/// Conteúdo rolável, centralizado e com largura máxima de leitura.
class PageBody extends StatelessWidget {
  const PageBody({super.key, required this.children, this.maxWidth = 560});
  final List<Widget> children;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
        ),
      ),
    );
  }
}

class Panel extends StatelessWidget {
  const Panel({super.key, required this.child, this.color, this.borderColor, this.padding});
  final Widget child;
  final Color? color;
  final Color? borderColor;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: color ?? PiCores.painel,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor ?? PiCores.borda, width: borderColor == null ? 1 : 1.5),
        boxShadow: const [BoxShadow(color: Color(0x4D000000), blurRadius: 30, offset: Offset(0, 14))],
      ),
      child: child,
    );
  }
}

class TitleText extends StatelessWidget {
  const TitleText(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        // Cabeçalho para leitores de tela (WCAG 1.3.1 / 2.4.6).
        child: Semantics(
          header: true,
          child: Text(text, style: const TextStyle(fontSize: 28, height: 1.12, fontWeight: FontWeight.w900)),
        ),
      );
}

class LeadText extends StatelessWidget {
  const LeadText(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Text(text, style: const TextStyle(fontSize: 16, height: 1.45, color: PiCores.textoSuave)),
      );
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 22, bottom: 10),
        child: Text(text, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
      );
}

/// Botão grande de opção (respostas, idiomas, escolhas).
class OptionButton extends StatelessWidget {
  const OptionButton({
    super.key,
    required this.label,
    this.badge,
    this.trailing,
    this.selected = false,
    this.enabled = true,
    this.locale,
    required this.onTap,
  });

  /// Idioma do rótulo, para o leitor de tela pronunciar certo (WCAG 3.1.2).
  final Locale? locale;

  final String label;
  final String? badge;
  final String? trailing;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Semantics(
        button: true,
        selected: selected,
        enabled: enabled,
        child: Opacity(
        opacity: enabled ? 1 : .45,
        child: Material(
          color: selected ? PiCores.limaFundo : PiCores.fundo2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: selected ? PiCores.lima : PiCores.borda, width: 1.5),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: enabled ? onTap : null,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 58),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(children: [
                  if (badge != null) ...[
                    // A sigla é só visual; o leitor de tela lê o rótulo completo.
                    ExcludeSemantics(child: Container(
                      width: 32,
                      height: 32,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(color: Color(0xFF45454C), shape: BoxShape.circle),
                      child: Text(badge!, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                    )),
                    const SizedBox(width: 14),
                  ],
                  Expanded(
                      child: Text(label, locale: locale, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
                  if (trailing != null)
                    Text(trailing!,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: PiCores.textoSuave)),
                ]),
              ),
            ),
          ),
        ),
      ),
      ),
    );
  }
}

/// Mini badge da marca (anel laranja, anel cinza, espaço e pera).
class BrandBadge extends StatelessWidget {
  const BrandBadge({super.key, this.size = 40});
  final double size;
  @override
  Widget build(BuildContext context) => CustomPaint(size: Size.square(size), painter: _BadgePainter());
}

class _BadgePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    canvas.drawCircle(c, r, Paint()..color = PiCores.laranja);
    canvas.drawCircle(c, r * .84, Paint()..color = const Color(0xFFA9ADB3));
    canvas.drawCircle(c, r * .72, Paint()..color = PiCores.marinho);
    final pear = Path()
      ..moveTo(c.dx, c.dy - r * .48)
      ..cubicTo(c.dx - r * .16, c.dy - r * .48, c.dx - r * .18, c.dy - r * .2, c.dx - r * .2, c.dy - r * .08)
      ..cubicTo(c.dx - r * .42, c.dy + r * .05, c.dx - r * .42, c.dy + r * .5, c.dx, c.dy + r * .5)
      ..cubicTo(c.dx + r * .42, c.dy + r * .5, c.dx + r * .42, c.dy + r * .05, c.dx + r * .2, c.dy - r * .08)
      ..cubicTo(c.dx + r * .18, c.dy - r * .2, c.dx + r * .16, c.dy - r * .48, c.dx, c.dy - r * .48)
      ..close();
    canvas.drawPath(pear, Paint()..color = const Color(0xFFBEC512));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

void showMessage(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
}
