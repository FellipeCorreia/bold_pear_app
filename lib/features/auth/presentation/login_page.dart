import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/app_state.dart';
import '../../../core/widgets/ui.dart';
import 'auth_errors.dart';
import 'auth_widgets.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final app = context.read<AppState>();
      app.voice.say(app.t.pear('login'), expr: 'happy');
    });
  }

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  bool _validEmail(String e) => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(e);

  Future<void> _login() async {
    final app = context.read<AppState>();
    final t = app.t;
    final email = _email.text.trim();
    if (!_validEmail(email)) return showMessage(context, t.ui('errEmail'));
    if (_pass.text.isEmpty) return showMessage(context, t.ui('errPassword'));
    setState(() => _busy = true);
    try {
      await app.sb.auth.signInWithPassword(email: email, password: _pass.text);
    } on AuthException catch (e) {
      if (mounted) showMessage(context, authErrorMessage(e, t));
    } catch (_) {
      if (mounted) showMessage(context, t.ui('errGeneric'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _forgot() async {
    final app = context.read<AppState>();
    final t = app.t;
    final email = _email.text.trim();
    if (!_validEmail(email)) return showMessage(context, t.ui('errEmail'));
    try {
      await app.sb.auth.resetPasswordForEmail(email);
      if (mounted) showMessage(context, t.ui('resetSent'));
    } catch (_) {
      if (mounted) showMessage(context, t.ui('errGeneric'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<AppState>().t;
    return PageBody(children: [
      const LanguageSwitch(),
      TitleText(t.ui('loginTitle')),
      const SizedBox(height: 8),
      TextField(
        controller: _email,
        keyboardType: TextInputType.emailAddress,
        autofillHints: const [AutofillHints.email],
        textInputAction: TextInputAction.next,
        decoration: InputDecoration(labelText: t.ui('email')),
      ),
      const SizedBox(height: 14),
      PasswordField(controller: _pass, label: t.ui('password'), onSubmitted: (_) => _login()),
      Align(
        alignment: Alignment.centerRight,
        child: TextButton(onPressed: _forgot, child: Text(t.ui('forgot'))),
      ),
      FilledButton(
        onPressed: _busy ? null : _login,
        child: _busy
            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
            : Text(t.ui('loginBtn')),
      ),
      AuthAlternative(label: t.ui('toSignup'), icon: Icons.person_add_alt_1_rounded, to: '/signup'),
    ]);
  }
}
