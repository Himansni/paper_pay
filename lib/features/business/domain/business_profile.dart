class BusinessProfile {
  const BusinessProfile({
    required this.id,
    required this.name,
    required this.phone,
    required this.address,
    this.primaryPricingRegion = const PricingRegion.empty(),
  });

  factory BusinessProfile.fromMap(String id, Map<String, Object?> data) {
    return BusinessProfile(
      id: id,
      name: data['name'] as String? ?? '',
      phone: data['phone'] as String? ?? '',
      address: data['address'] as String? ?? '',
      primaryPricingRegion: PricingRegion.fromMap(data['primaryPricingRegion']),
    );
  }

  final String id;
  final String name;
  final String phone;
  final String address;
  final PricingRegion primaryPricingRegion;
}

class PricingRegion {
  const PricingRegion({
    required this.state,
    required this.districtCity,
    required this.editionServiceRegion,
  });

  const PricingRegion.empty()
    : state = '',
      districtCity = '',
      editionServiceRegion = '';

  factory PricingRegion.fromMap(Object? value) {
    if (value is! Map) return const PricingRegion.empty();
    return PricingRegion(
      state: value['state'] as String? ?? '',
      districtCity: value['districtCity'] as String? ?? '',
      editionServiceRegion: value['editionServiceRegion'] as String? ?? '',
    );
  }

  final String state;
  final String districtCity;
  final String editionServiceRegion;

  bool get isConfigured => state.isNotEmpty && districtCity.isNotEmpty;

  String get displayName {
    final parts = [
      districtCity,
      if (editionServiceRegion.isNotEmpty) editionServiceRegion,
    ];
    return parts.where((value) => value.isNotEmpty).join(' · ');
  }

  PricingRegion normalized() => PricingRegion(
    state: state.trim(),
    districtCity: districtCity.trim(),
    editionServiceRegion: editionServiceRegion.trim(),
  );

  void validate() {
    final value = normalized();
    if (value.state.length < 2 || value.state.length > 80) {
      throw const FormatException('Enter a valid state.');
    }
    if (value.districtCity.length < 2 || value.districtCity.length > 100) {
      throw const FormatException('Enter a valid district or city.');
    }
    if (value.editionServiceRegion.length > 100) {
      throw const FormatException(
        'Edition or service region must be 100 characters or fewer.',
      );
    }
  }

  Map<String, String> toMap() => {
    'state': state,
    'districtCity': districtCity,
    'editionServiceRegion': editionServiceRegion,
  };
}
