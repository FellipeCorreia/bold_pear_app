class Profile {
  const Profile({
    required this.id,
    required this.displayName,
    required this.language,
    required this.voiceGender,
    required this.addressForm,
    required this.onboarded,
  });

  final String id;
  final String displayName;
  final String language;
  final String voiceGender;
  final String addressForm;
  final bool onboarded;

  factory Profile.fromMap(Map<String, dynamic> m) => Profile(
        id: m['id'] as String,
        displayName: (m['display_name'] as String?) ?? '',
        language: (m['language'] as String?) ?? 'pt',
        voiceGender: (m['voice_gender'] as String?) ?? 'f',
        addressForm: (m['address_form'] as String?) ?? 'm',
        onboarded: (m['onboarded'] as bool?) ?? false,
      );

  Profile copyWith({String? displayName, String? language, String? voiceGender, String? addressForm, bool? onboarded}) =>
      Profile(
        id: id,
        displayName: displayName ?? this.displayName,
        language: language ?? this.language,
        voiceGender: voiceGender ?? this.voiceGender,
        addressForm: addressForm ?? this.addressForm,
        onboarded: onboarded ?? this.onboarded,
      );

  Map<String, dynamic> toUpdate() => {
        'display_name': displayName,
        'language': language,
        'voice_gender': voiceGender,
        'address_form': addressForm,
        'onboarded': onboarded,
      };
}
