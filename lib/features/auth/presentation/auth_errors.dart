import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/i18n/l10n.dart';

/// Traduz os erros do Supabase Auth para o idioma do app.
String _authErrorImpl(AuthException e, L10n t) {
  switch (e.code) {
    case 'invalid_credentials':
      return t.ui('errInvalid');
    case 'email_address_invalid':
    case 'validation_failed':
      return t.ui('errEmail');
    case 'user_already_exists':
    case 'email_exists':
      return t.ui('errExists');
    case 'weak_password':
      return t.ui('errPassword');
  }
  if (e.statusCode == '400' && e.message.toLowerCase().contains('invalid login')) return t.ui('errInvalid');
  return t.ui('errGeneric');
}

String authErrorMessage(AuthException e, L10n t) => _authErrorImpl(e, t);
