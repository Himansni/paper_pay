import 'dart:math' as math;

import 'package:paper_route/core/errors/app_exception.dart';

enum CustomerStatus {
  active('active', 'Active'),
  archived('archived', 'Archived');

  const CustomerStatus(this.value, this.label);

  final String value;
  final String label;

  // Unknown legacy values remain operational rather than being treated as an
  // instruction to hide or delete the customer.
  static CustomerStatus fromValue(Object? value) =>
      value == archived.value ? archived : active;
}

enum CustomerSearchField {
  name('name', 'Name'),
  phone('phone', 'Phone'),
  customerCode('code', 'Customer ID'),
  landmark('landmark', 'Landmark');

  const CustomerSearchField(this.key, this.label);

  final String key;
  final String label;
}

enum DeliveryPlacement {
  doorstep('doorstep', 'Doorstep'),
  handToCustomer('handToCustomer', 'Hand to customer'),
  reception('reception', 'Reception / security'),
  collectionPoint('collectionPoint', 'Collection point');

  const DeliveryPlacement(this.value, this.label);

  final String value;
  final String label;

  static DeliveryPlacement fromValue(Object? value) =>
      values.firstWhere((item) => item.value == value, orElse: () => doorstep);
}

enum BillingCyclePreference {
  monthly('monthly', 'Monthly'),
  fortnightly('fortnightly', 'Fortnightly'),
  weekly('weekly', 'Weekly');

  const BillingCyclePreference(this.value, this.label);

  final String value;
  final String label;

  static BillingCyclePreference fromValue(Object? value) =>
      values.firstWhere((item) => item.value == value, orElse: () => monthly);
}

class CustomerCoordinates {
  const CustomerCoordinates({required this.latitude, required this.longitude});

  factory CustomerCoordinates.fromMap(Map<String, Object?> data) =>
      CustomerCoordinates(
        latitude: (data['latitude'] as num?)?.toDouble() ?? 0,
        longitude: (data['longitude'] as num?)?.toDouble() ?? 0,
      );

  final double latitude;
  final double longitude;

  Map<String, Object> toMap() => {'latitude': latitude, 'longitude': longitude};
}

/// Tenant-owned customer document stored at
/// businesses/{businessId}/customers/{customerCode}.
class Customer {
  const Customer({
    required this.id,
    required this.customerCode,
    required this.businessId,
    required this.name,
    required this.phone,
    required this.areaId,
    required this.assignedEmployeeId,
    required this.status,
    this.alternatePhone = '',
    this.address = '',
    this.landmark = '',
    this.houseNumber = '',
    this.buildingInfo = '',
    this.locationNotes = '',
    this.locationConsent = false,
    this.coordinates,
    this.deliveryPlacement = DeliveryPlacement.doorstep,
    this.billingCycle = BillingCyclePreference.monthly,
    this.subscriptionStatus = 'notConfigured',
    this.openingBalancePaise = 0,
    this.notes = '',
    this.createdBy = '',
    this.updatedBy = '',
    this.createdAt,
    this.updatedAt,
  });

  factory Customer.fromMap(String id, Map<String, Object?> data) {
    final rawCoordinates = data['coordinates'];
    final deliveryPreferences = data['deliveryPreferences'];
    final billingPreferences = data['billingPreferences'];
    return Customer(
      id: id,
      customerCode: data['customerCode'] as String? ?? id,
      businessId: data['businessId'] as String? ?? '',
      name: data['name'] as String? ?? 'Unnamed customer',
      phone: data['phone'] as String? ?? '',
      alternatePhone: data['alternatePhone'] as String? ?? '',
      address: data['address'] as String? ?? '',
      areaId: data['areaId'] as String? ?? '',
      landmark: data['landmark'] as String? ?? '',
      houseNumber: data['houseNumber'] as String? ?? '',
      buildingInfo: data['buildingInfo'] as String? ?? '',
      locationNotes: data['locationNotes'] as String? ?? '',
      locationConsent: data['locationConsent'] == true,
      coordinates:
          rawCoordinates is Map
              ? CustomerCoordinates.fromMap(
                rawCoordinates.cast<String, Object?>(),
              )
              : null,
      assignedEmployeeId: data['assignedEmployeeId'] as String? ?? '',
      status: CustomerStatus.fromValue(data['status']),
      deliveryPlacement: DeliveryPlacement.fromValue(
        deliveryPreferences is Map ? deliveryPreferences['placement'] : null,
      ),
      billingCycle: BillingCyclePreference.fromValue(
        billingPreferences is Map ? billingPreferences['cycle'] : null,
      ),
      subscriptionStatus:
          data['subscriptionStatus'] as String? ?? 'notConfigured',
      openingBalancePaise: data['openingBalancePaise'] as int? ?? 0,
      notes: data['notes'] as String? ?? '',
      createdBy: data['createdBy'] as String? ?? '',
      updatedBy: data['updatedBy'] as String? ?? '',
      createdAt: data['createdAt'] as DateTime?,
      updatedAt: data['updatedAt'] as DateTime?,
    );
  }

  /// Firestore document ID. New records use the same stable value as the code.
  final String id;

  /// Human-visible permanent ID generated once when the customer is created.
  final String customerCode;
  final String businessId;
  final String name;
  final String phone;
  final String alternatePhone;
  final String address;
  final String areaId;
  final String landmark;
  final String houseNumber;
  final String buildingInfo;
  final String locationNotes;

  /// Coordinates are meaningful only when this explicit consent flag is true.
  final bool locationConsent;
  final CustomerCoordinates? coordinates;
  final String assignedEmployeeId;
  final CustomerStatus status;
  final DeliveryPlacement deliveryPlacement;
  final BillingCyclePreference billingCycle;
  final String subscriptionStatus;

  /// Money is stored as integer paise instead of decimal rupees.
  /// For example, ₹125.50 is stored as 12550 to avoid rounding errors.
  final int openingBalancePaise;
  final String notes;
  final String createdBy;
  final String updatedBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isArchived => status == CustomerStatus.archived;

  String get addressSummary {
    final parts = [
      houseNumber,
      buildingInfo,
      address,
      if (landmark.isNotEmpty) 'Near $landmark',
    ].where((part) => part.trim().isNotEmpty);
    return parts.join(', ');
  }

  CustomerInput toInput() => CustomerInput(
    name: name,
    phone: phone,
    alternatePhone: alternatePhone,
    address: address,
    areaId: areaId,
    landmark: landmark,
    houseNumber: houseNumber,
    buildingInfo: buildingInfo,
    locationNotes: locationNotes,
    locationConsent: locationConsent,
    coordinates: coordinates,
    assignedEmployeeId: assignedEmployeeId,
    deliveryPlacement: deliveryPlacement,
    billingCycle: billingCycle,
    openingBalancePaise: openingBalancePaise,
    notes: notes,
  );
}

class CustomerInput {
  const CustomerInput({
    required this.name,
    required this.phone,
    required this.alternatePhone,
    required this.address,
    required this.areaId,
    required this.landmark,
    required this.houseNumber,
    required this.buildingInfo,
    required this.locationNotes,
    required this.locationConsent,
    required this.coordinates,
    required this.assignedEmployeeId,
    required this.deliveryPlacement,
    required this.billingCycle,
    required this.openingBalancePaise,
    required this.notes,
  });

  final String name;
  final String phone;
  final String alternatePhone;
  final String address;
  final String areaId;
  final String landmark;
  final String houseNumber;
  final String buildingInfo;
  final String locationNotes;
  final bool locationConsent;
  final CustomerCoordinates? coordinates;
  final String assignedEmployeeId;
  final DeliveryPlacement deliveryPlacement;
  final BillingCyclePreference billingCycle;
  final int openingBalancePaise;
  final String notes;

  // Normalization makes validation and search indexing deterministic. Turning
  // consent off also removes coordinates instead of retaining hidden GPS data.
  CustomerInput normalized() => CustomerInput(
    name: name.trim(),
    phone: phone.trim(),
    alternatePhone: alternatePhone.trim(),
    address: address.trim(),
    areaId: areaId.trim(),
    landmark: landmark.trim(),
    houseNumber: houseNumber.trim(),
    buildingInfo: buildingInfo.trim(),
    locationNotes: locationNotes.trim(),
    locationConsent: locationConsent,
    coordinates: locationConsent ? coordinates : null,
    assignedEmployeeId: assignedEmployeeId.trim(),
    deliveryPlacement: deliveryPlacement,
    billingCycle: billingCycle,
    openingBalancePaise: openingBalancePaise,
    notes: notes.trim(),
  );

  void validate() {
    final value = normalized();
    if (value.name.length < 2 || value.name.length > 100) {
      throw const AppException(
        'Enter a customer name between 2 and 100 characters.',
      );
    }
    _validatePhone(value.phone, label: 'primary phone');
    if (value.alternatePhone.isNotEmpty) {
      _validatePhone(value.alternatePhone, label: 'alternate phone');
      if (CustomerSearchIndex.normalizePhone(value.alternatePhone) ==
          CustomerSearchIndex.normalizePhone(value.phone)) {
        throw const AppException(
          'Alternate phone must be different from the primary phone.',
        );
      }
    }
    if (value.address.length < 5 || value.address.length > 300) {
      throw const AppException(
        'Enter a complete address between 5 and 300 characters.',
      );
    }
    if (value.landmark.length < 2 || value.landmark.length > 120) {
      throw const AppException('Enter a recognizable landmark.');
    }
    if (value.areaId.isEmpty) {
      throw const AppException('Select a delivery area.');
    }
    if (value.houseNumber.length > 80 ||
        value.buildingInfo.length > 120 ||
        value.locationNotes.length > 300 ||
        value.notes.length > 500) {
      throw const AppException(
        'One or more address or note fields are too long.',
      );
    }
    if (value.openingBalancePaise < 0 ||
        value.openingBalancePaise > 100000000) {
      throw const AppException(
        'Opening balance must be between ₹0 and ₹10,00,000.',
      );
    }
    if (value.locationConsent != (value.coordinates != null)) {
      // Consent and coordinates must move together: neither can exist alone.
      throw const AppException(
        'GPS coordinates require explicit customer consent.',
      );
    }
    final coordinates = value.coordinates;
    if (coordinates != null &&
        (!coordinates.latitude.isFinite ||
            !coordinates.longitude.isFinite ||
            coordinates.latitude < -90 ||
            coordinates.latitude > 90 ||
            coordinates.longitude < -180 ||
            coordinates.longitude > 180)) {
      throw const AppException(
        'Enter valid GPS latitude and longitude values.',
      );
    }
  }

  static void _validatePhone(String value, {required String label}) {
    final digits = CustomerSearchIndex.normalizePhone(value);
    if (value.length > 24 || digits.length < 7 || digits.length > 15) {
      throw AppException('Enter a valid $label number.');
    }
  }
}

/// Builds bounded prefix tokens so Firestore can search without downloading the
/// full customer collection. Tokens are created during every create/update.
abstract final class CustomerSearchIndex {
  static String normalizeText(String value) =>
      value
          .trim()
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();

  static String normalizePhone(String value) =>
      value.replaceAll(RegExp(r'[^0-9]'), '');

  static List<String> buildTokens({
    required String customerCode,
    required String name,
    required String phone,
    required String alternatePhone,
    required String landmark,
  }) {
    final tokens = <String>{};
    // Prefixes support practical starts-with searches for normalized fields.
    // The cap keeps each Firestore document within a predictable index size.
    _addTextTokens(tokens, 'name', normalizeText(name), minimum: 2);
    _addPhoneTokens(tokens, normalizePhone(phone));
    _addPhoneTokens(tokens, normalizePhone(alternatePhone));
    _addTextTokens(tokens, 'landmark', normalizeText(landmark), minimum: 2);
    tokens.add('code:${customerCode.trim().toUpperCase()}');
    final sorted = tokens.toList()..sort();
    return sorted.take(300).toList();
  }

  static String tokenFor(CustomerSearchField field, String term) {
    // Customer codes are stored as exact uppercase identifiers; the other
    // fields use the same normalization and prefix format as buildTokens().
    if (field == CustomerSearchField.customerCode) {
      return term.trim().toUpperCase();
    }
    final normalized =
        field == CustomerSearchField.phone
            ? normalizePhone(term)
            : normalizeText(term);
    final minimum = field == CustomerSearchField.phone ? 3 : 2;
    if (normalized.length < minimum) {
      throw AppException(
        field == CustomerSearchField.phone
            ? 'Enter at least 3 phone digits.'
            : 'Enter at least 2 characters to search.',
      );
    }
    return '${field.key}:$normalized';
  }

  static void _addPhoneTokens(Set<String> target, String phone) {
    if (phone.isEmpty) return;
    for (var length = 3; length <= math.min(phone.length, 15); length++) {
      target.add('phone:${phone.substring(0, length)}');
    }
  }

  static void _addTextTokens(
    Set<String> target,
    String key,
    String value, {
    required int minimum,
  }) {
    if (value.isEmpty) return;
    final candidates = <String>{value, ...value.split(' ')}.take(4);
    for (final candidate in candidates) {
      for (
        var length = minimum;
        length <= math.min(candidate.length, 30);
        length++
      ) {
        target.add('$key:${candidate.substring(0, length)}');
      }
    }
  }
}

/// Converts user-facing rupees to the integer-paise representation used by
/// customer and ledger data.
abstract final class CustomerMoney {
  static int parseRupeesToPaise(String value) {
    final normalized = value.trim().replaceAll(',', '');
    if (!RegExp(r'^\d{1,7}(\.\d{1,2})?$').hasMatch(normalized)) {
      throw const AppException(
        'Enter opening balance in rupees with at most two decimal places.',
      );
    }
    final parts = normalized.split('.');
    final rupees = int.parse(parts.first);
    final paise =
        parts.length == 1 ? 0 : int.parse(parts.last.padRight(2, '0'));
    final result = rupees * 100 + paise;
    if (result > 100000000) {
      throw const AppException('Opening balance cannot exceed ₹10,00,000.');
    }
    return result;
  }

  static String formatPaiseForInput(int paise) {
    final rupees = paise ~/ 100;
    final remainder = (paise % 100).toString().padLeft(2, '0');
    return '$rupees.$remainder';
  }
}

class CustomerPageCursor {
  const CustomerPageCursor({
    required this.searchName,
    required this.customerId,
  });

  final String searchName;
  final String customerId;
}

/// Complete server query description for one page of the customer directory.
/// requesterId and isHead let the repository constrain employee results.
class CustomerListRequest {
  const CustomerListRequest({
    required this.businessId,
    required this.requesterId,
    required this.isHead,
    this.status = CustomerStatus.active,
    this.areaId = '',
    this.searchField,
    this.searchTerm = '',
    this.cursor,
    this.pageSize = 25,
  });

  final String businessId;
  final String requesterId;
  final bool isHead;
  final CustomerStatus status;
  final String areaId;
  final CustomerSearchField? searchField;
  final String searchTerm;
  final CustomerPageCursor? cursor;
  final int pageSize;

  String? get searchToken {
    final field = searchField;
    if (field == null || searchTerm.trim().isEmpty) return null;
    return CustomerSearchIndex.tokenFor(field, searchTerm);
  }

  bool get isCodeSearch =>
      searchField == CustomerSearchField.customerCode &&
      searchTerm.trim().isNotEmpty;
}

class CustomerPage {
  const CustomerPage({
    required this.customers,
    required this.nextCursor,
    required this.hasMore,
  });

  final List<Customer> customers;
  final CustomerPageCursor? nextCursor;
  final bool hasMore;
}

/// Read model for an append-only customer audit record. Assignment entries keep
/// both previous and new values so transfers remain explainable later.
class CustomerAuditEntry {
  const CustomerAuditEntry({
    required this.id,
    required this.action,
    required this.actorId,
    required this.createdAt,
    this.previousEmployeeId = '',
    this.employeeId = '',
    this.previousAreaId = '',
    this.areaId = '',
    this.changedFields = const [],
  });

  factory CustomerAuditEntry.fromMap(String id, Map<String, Object?> data) =>
      CustomerAuditEntry(
        id: id,
        action: data['action'] as String? ?? 'customerUpdated',
        actorId: data['actorId'] as String? ?? '',
        createdAt: data['createdAt'] as DateTime?,
        previousEmployeeId: data['previousEmployeeId'] as String? ?? '',
        employeeId: data['employeeId'] as String? ?? '',
        previousAreaId: data['previousAreaId'] as String? ?? '',
        areaId: data['areaId'] as String? ?? '',
        changedFields:
            data['changedFields'] is List
                ? (data['changedFields'] as List).whereType<String>().toList()
                : const [],
      );

  final String id;
  final String action;
  final String actorId;
  final DateTime? createdAt;
  final String previousEmployeeId;
  final String employeeId;
  final String previousAreaId;
  final String areaId;
  final List<String> changedFields;
}
