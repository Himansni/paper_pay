class BusinessProfile {
  const BusinessProfile({
    required this.id,
    required this.name,
    required this.phone,
    required this.address,
  });

  factory BusinessProfile.fromMap(String id, Map<String, Object?> data) {
    return BusinessProfile(
      id: id,
      name: data['name'] as String? ?? '',
      phone: data['phone'] as String? ?? '',
      address: data['address'] as String? ?? '',
    );
  }

  final String id;
  final String name;
  final String phone;
  final String address;
}
