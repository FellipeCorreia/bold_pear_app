import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/app_state.dart';
import '../../../core/widgets/ui.dart';
import 'auth_errors.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});
  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final app = context.read<AppState>();
      app.voice.say(app.t.pear('signup'), expr: 'happy');
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _signup() async {
    final app = context.read<AppState>();
    final t = app.t;
    final name = _name.text.trim();
    final email = _email.text.trim();
    if (name.isEmpty) return showMessage(context, t.ui('errName'));
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) return showMessage(context, t.ui('errEmail'));
    if (_pass.text.length < 8) return showMessage(context, t.ui('errPassword'));
    setState(() => _busy = true);
    try {
      final res = await app.sb.auth.signUp(email: email, password: _pass.text, data: {'display_name': name});
      if (!mounted) return;
      if (res.session == null) {
        // Projeto com confirmação de e-mail ativa: a pessoa entra depois de confirmar.
        showMessage(context, t.ui('confirmEmail'));
        context.go('/login');
      }
    } on AuthException catch (e) {
      if (mounted) showMessage(context, authErrorMessage(e, t));
    } catch (_) {
      if (mounted) showMessage(context, t.ui('errGeneric'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<AppState>().t;
    return PageBody(children: [
      TitleText(t.ui('signupTitle')),
      const SizedBox(height: 8),
      TextField(
        controller: _name,
        textCapitalization: TextCapitalization.words,
        autofillHints: const [AutofillHints.nickname],
        decoration: InputDecoration(labelText: t.ui('name')),
      ),
      const SizedBox(height: 14),
      TextField(
        controller: _email,
        keyboardType: TextInputType.emailAddress,
        autofillHints: const [AutofillHints.email],
        decoration: InputDecoration(labelText: t.ui('email')),
      ),
      const SizedBox(height: 14),
      TextField(
        controller: _pass,
        obscureText: true,
        autofillHints: const [AutofillHints.newPassword],
        decoration: InputDecoration(labelText: t.ui('password'), helperText: t.ui('passwordHint')),
        onSubmitted: (_) => _signup(),
      ),
      const SizedBox(height: 18),
      FilledButton(
        onPressed: _busy ? null : _signup,
        child: _busy
            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
            : Text(t.ui('signupBtn')),
      ),
      const SizedBox(height: 8),
      TextButton(onPressed: () => context.go('/login'), child: Text(t.ui('toLogin'))),
      TextButton(onPressed: () => context.go('/welcome'), child: Text(t.ui('back'))),
    ]);
  }
}
