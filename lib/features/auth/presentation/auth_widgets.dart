import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../app/app_state.dart';
import '../../../core/i18n/l10n.dart';
import '../../../core/theme/pi_cores.dart';

/// Botão no topo das telas de conta: mostra o idioma atual e volta para trocá-lo.
class LanguageSwitch extends StatelessWidget {
  const LanguageSwitch({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final name = kLanguages.firstWhere((l) => l.$1 == app.lang).$2;
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: OutlinedButton.icon(
          onPressed: () => context.go('/welcome'),
          icon: const Icon(Icons.translate_rounded, size: 20),
          label: Text('${app.t.ui('language')}: $name'),
        ),
      ),
    );
  }
}

/// Campo de senha com mostrar/ocultar (WCAG 3.3.8: autenticação acessível).
class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    required this.controller,
    required this.label,
    this.helper,
    this.newPassword = false,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final String? helper;
  final bool newPassword;
  final ValueChanged<String>? onSubmitted;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _hidden = true;

  @override
  Widget build(BuildContext context) {
    final t = context.watch<AppState>().t;
    return TextField(
      controller: widget.controller,
      obscureText: _hidden,
      autofillHints: [widget.newPassword ? AutofillHints.newPassword : AutofillHints.password],
      textInputAction: TextInputAction.done,
      onSubmitted: widget.onSubmitted,
      decoration: InputDecoration(
        labelText: widget.label,
        helperText: widget.helper,
        helperMaxLines: 3,
        suffixIcon: IconButton(
          tooltip: t.ui(_hidden ? 'showPassword' : 'hidePassword'),
          onPressed: () => setState(() => _hidden = !_hidden),
          icon: Icon(_hidden ? Icons.visibility_rounded : Icons.visibility_off_rounded, color: PiCores.textoSuave),
        ),
      ),
    );
  }
}

/// Alternativa entre entrar / criar conta: botão grande e visível, não um link escondido.
class AuthAlternative extends StatelessWidget {
  const AuthAlternative({super.key, required this.label, required this.icon, required this.to});
  final String label;
  final IconData icon;
  final String to;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 22),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const ExcludeSemantics(child: Divider(color: PiCores.borda, height: 1)),
        const SizedBox(height: 22),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 54)),
          onPressed: () => context.go(to),
          icon: Icon(icon),
          label: Text(label, textAlign: TextAlign.center),
        ),
      ]),
    );
  }
}
