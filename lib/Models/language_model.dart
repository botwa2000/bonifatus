// .../lib/models/language_model.dart

class Language {
  final String id;
  final String name;
  final String countryCode;
  final int displayOrder;
  final bool isActive;

  Language({
    required this.id,
    required this.name,
    required this.countryCode,
    required this.displayOrder,
    this.isActive = true,
  });

  factory Language.fromJson(Map<String, dynamic> json) {
    return Language(
      id: json['language_id']?.toString() ?? '',
      name: json['language_name']?.toString() ?? '',
      countryCode: (json['country_code'] ?? json['language_id'])?.toString().toUpperCase() ?? '',
      displayOrder: int.tryParse(json['display_order']?.toString() ?? '0') ?? 0,
      isActive: json['is_active'] == 1 || json['is_active'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
    'language_id': id,
    'language_name': name,
    'country_code': countryCode,
    'display_order': displayOrder,
    'is_active': isActive,
  };
}