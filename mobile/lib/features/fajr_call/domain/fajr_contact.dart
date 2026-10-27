/// How a person on a Fajr list is related to the user. Only used for the
/// icon and the label next to the name.
enum ContactRelation {
  father,
  mother,
  sibling,
  spouse,
  child,
  friend,
  other;

  static ContactRelation? tryParse(Object? value) {
    for (final r in values) {
      if (r.name == value) return r;
    }
    return null;
  }
}

/// Someone the user wants to wake for Fajr. Contacts never leave the device.
class FajrContact {
  const FajrContact({
    required this.id,
    required this.name,
    required this.phone,
    String? rawPhone,
    this.relation,
  }) : rawPhone = rawPhone ?? phone;

  final String id;
  final String name;

  /// The number that is dialled: E.164 (`+213551234567`) when it could be
  /// normalised, otherwise the digits as entered.
  final String phone;

  /// The number exactly as the user typed or picked it.
  final String rawPhone;

  final ContactRelation? relation;

  /// Builds a contact from user input, normalising the number with
  /// [dialCode] (for example `213`) when it is in local format.
  factory FajrContact.fromInput({
    required String id,
    required String name,
    required String phone,
    ContactRelation? relation,
    String? dialCode,
  }) =>
      FajrContact(
        id: id,
        name: name.trim(),
        phone: normalizePhone(phone, dialCode: dialCode),
        rawPhone: phone.trim(),
        relation: relation,
      );

  FajrContact copyWith({
    String? name,
    String? phone,
    String? rawPhone,
    ContactRelation? relation,
    bool clearRelation = false,
  }) =>
      FajrContact(
        id: id,
        name: name ?? this.name,
        phone: phone ?? this.phone,
        rawPhone: rawPhone ?? this.rawPhone,
        relation: clearRelation ? null : (relation ?? this.relation),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'rawPhone': rawPhone,
        if (relation != null) 'relation': relation!.name,
      };

  factory FajrContact.fromJson(Map<String, dynamic> json) {
    final phone = json['phone'] as String? ?? '';
    return FajrContact(
      id: json['id'] as String? ?? phone,
      name: json['name'] as String? ?? '',
      phone: phone,
      rawPhone: json['rawPhone'] as String?,
      relation: ContactRelation.tryParse(json['relation']),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is FajrContact &&
      other.id == id &&
      other.name == name &&
      other.phone == phone &&
      other.rawPhone == rawPhone &&
      other.relation == relation;

  @override
  int get hashCode => Object.hash(id, name, phone, rawPhone, relation);
}

/// Normalises a phone number towards E.164.
///
/// - Spaces, dashes, dots and brackets are dropped.
/// - `00…` becomes `+…`.
/// - A local number with one leading `0` becomes `+<dialCode>…` when
///   [dialCode] is known (`0551 23 45 67` + `213` → `+213551234567`).
/// - Anything else is returned as cleaned digits, which the dialler still
///   understands (short codes, numbers without a known country).
String normalizePhone(String raw, {String? dialCode}) {
  final trimmed = raw.trim();
  final plus = trimmed.startsWith('+');
  final digits = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isEmpty) return '';
  if (plus) return '+$digits';
  if (digits.startsWith('00') && digits.length > 4) {
    return '+${digits.substring(2)}';
  }
  final code = dialCode?.replaceAll(RegExp(r'[^0-9]'), '');
  if (code != null &&
      code.isNotEmpty &&
      digits.startsWith('0') &&
      !digits.startsWith('00') &&
      digits.length >= 8) {
    return '+$code${digits.substring(1)}';
  }
  return digits;
}

/// International dialling codes for the countries Lahuma users are most
/// likely in, keyed by ISO 3166 country code. Used to normalise local
/// numbers; a missing country just leaves numbers as dialled.
const Map<String, String> kDialCodes = {
  'DZ': '213',
  'MA': '212',
  'TN': '216',
  'LY': '218',
  'EG': '20',
  'MR': '222',
  'SD': '249',
  'SA': '966',
  'AE': '971',
  'QA': '974',
  'KW': '965',
  'BH': '973',
  'OM': '968',
  'YE': '967',
  'JO': '962',
  'PS': '970',
  'LB': '961',
  'SY': '963',
  'IQ': '964',
  'TR': '90',
  'FR': '33',
  'BE': '32',
  'DE': '49',
  'GB': '44',
  'ES': '34',
  'IT': '39',
  'CA': '1',
  'US': '1',
};
