import 'app_strings.dart';
import 'content.dart';

const kLanguages = <(String, String)>[
  ('pt', 'Português (Brasil)'),
  ('en', 'English'),
  ('de', 'Deutsch'),
  ('fr', 'Français'),
  ('ja', '日本語'),
];

const kLocales = {'pt': 'pt-BR', 'en': 'en-US', 'de': 'de-DE', 'fr': 'fr-FR', 'ja': 'ja-JP'};

/// Textos da interface e falas da Bold Pear no idioma atual.
class L10n {
  const L10n(this.lang, {this.voiceGender = 'f', this.addressForm = 'm', this.name = ''});

  final String lang;
  final String voiceGender;
  final String addressForm;
  final String name;

  String get locale => kLocales[lang]!;

  /// Texto de tela (já com marcadores de gênero resolvidos).
  String ui(String key) {
    final v = kUiApp[lang]?[key] ?? (kUiBase[lang] as Map)[key];
    return v is String ? f(v) : key;
  }

  List<String> uiList(String key) => ((kUiBase[lang] as Map)[key] as List).cast<String>();

  /// Fala da pera.
  String pear(String key) {
    final v = kPearAppLines[lang]?[key] ?? (kPearLines[lang] as Map)[key];
    return v is String ? f(v) : key;
  }

  List<String> get acks => ((kPearLines[lang] as Map)['acks'] as List).cast<String>().map(f).toList();

  Map<String, dynamic> get scales => kScales[lang] as Map<String, dynamic>;

  String hint(List<String> opts) {
    String join(String or) => '${opts.sublist(0, opts.length - 1).join(', ')} $or ${opts.last}';
    switch (lang) {
      case 'en':
        return 'You can answer: ${join('or')}.';
      case 'de':
        return 'Sie können antworten: ${join('oder')}.';
      case 'fr':
        return 'Vous pouvez répondre : ${join('ou')}.';
      case 'ja':
        return '「${opts.join('」「')}」の中から選んでください。';
      default:
        return 'Você pode responder: ${join('ou')}.';
    }
  }

  static final _noName = RegExp(r',?\s?\{name\}(さん)?、?');
  static final _listener = RegExp(r'\{([^|{}]*)\|([^{}]*)\}');
  static final _speaker = RegExp(r'\[([^|\[\]]*)\|([^\[\]]*)\]');

  /// Resolve {name}, {a|b} (gênero de quem ouve) e [a|b] (gênero da voz).
  String f(String t, {Map<String, String> vars = const {}}) {
    var s = t;
    vars.forEach((k, v) => s = s.replaceAll('{$k}', v));
    s = name.isEmpty ? s.replaceAll(_noName, '') : s.replaceAll('{name}', name);
    s = s.replaceAllMapped(_listener, (m) => addressForm == 'f' ? m[2]! : m[1]!);
    s = s.replaceAllMapped(_speaker, (m) => voiceGender == 'f' ? m[2]! : m[1]!);
    return s;
  }
}
