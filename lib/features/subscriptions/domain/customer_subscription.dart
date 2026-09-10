import 'package:paper_route/core/domain/local_date.dart';
import 'package:paper_route/core/errors/app_exception.dart';

enum SubscriptionStatus {
  active('active', 'Active'),
  paused('paused', 'Paused'),
  ended('ended', 'Ended');

  const SubscriptionStatus(this.value, this.label);

  final String value;
  final String label;

  static SubscriptionStatus fromValue(Object? value) =>
      values.firstWhere((status) => status.value == value, orElse: () => ended);
}

abstract final class DeliveryWeekday {
  static const all = <int>{1, 2, 3, 4, 5, 6, 7};

  static const labels = <int, String>{
    1: 'Mon',
    2: 'Tue',
    3: 'Wed',
    4: 'Thu',
    5: 'Fri',
    6: 'Sat',
    7: 'Sun',
  };

  static String describe(Set<int> weekdays) {
    if (weekdays.length == 7 && weekdays.containsAll(all)) return 'Every day';
    return [
      for (final day in weekdays.toList()..sort()) labels[day] ?? '$day',
    ].join(', ');
  }
}

class SubscriptionInput {
  const SubscriptionInput({
    required this.newspaperId,
    required this.startDate,
    required this.endDate,
    required this.quantity,
    required this.deliveryWeekdays,
    required this.customPricePaise,
    required this.customPriceReason,
  });

  final String newspaperId;
  final LocalDate startDate;
  final LocalDate? endDate;
  final int quantity;
  final Set<int> deliveryWeekdays;
  final int? customPricePaise;
  final String customPriceReason;

  SubscriptionInput normalized() => SubscriptionInput(
    newspaperId: newspaperId.trim(),
    startDate: startDate,
    endDate: endDate,
    quantity: quantity,
    deliveryWeekdays: Set.unmodifiable(deliveryWeekdays),
    customPricePaise: customPricePaise,
    customPriceReason: customPriceReason.trim(),
  );

  void validate() {
    final value = normalized();
    _validateDate(value.startDate, 'start date');
    if (value.endDate != null) {
      _validateDate(value.endDate!, 'end date');
      if (value.endDate!.isBefore(value.startDate)) {
        throw const AppException(
          'Subscription end date cannot be before its start date.',
        );
      }
    }
    if (value.newspaperId.isEmpty) {
      throw const AppException('Select a newspaper.');
    }
    if (value.quantity < 1 || value.quantity > 50) {
      throw const AppException('Quantity must be between 1 and 50.');
    }
    if (value.deliveryWeekdays.isEmpty ||
        !DeliveryWeekday.all.containsAll(value.deliveryWeekdays)) {
      throw const AppException('Select at least one valid delivery weekday.');
    }
    final customPrice = value.customPricePaise;
    if (customPrice != null && (customPrice < 0 || customPrice > 1000000)) {
      throw const AppException(
        'Customer-specific price must be between ₹0 and ₹10,000.',
      );
    }
    if (customPrice == null && value.customPriceReason.isNotEmpty) {
      throw const AppException(
        'Remove the pricing reason or enter a customer-specific price.',
      );
    }
    if (customPrice != null &&
        (value.customPriceReason.length < 3 ||
            value.customPriceReason.length > 200)) {
      throw const AppException(
        'Explain the authorized customer-specific price.',
      );
    }
  }
}

class CustomerSubscription {
  const CustomerSubscription({
    required this.id,
    required this.businessId,
    required this.customerId,
    required this.newspaperId,
    required this.newspaperName,
    required this.currentVersionId,
    required this.currentPauseId,
    required this.status,
    required this.startDate,
    required this.endDate,
    required this.currentEffectiveFrom,
    required this.quantity,
    required this.deliveryWeekdays,
    required this.customPricePaise,
    required this.customPriceReason,
    required this.createdBy,
    required this.updatedBy,
    required this.lastAuditId,
    this.createdAt,
    this.updatedAt,
  });

  factory CustomerSubscription.fromMap(String id, Map<String, Object?> data) =>
      CustomerSubscription(
        id: id,
        businessId: data['businessId'] as String? ?? '',
        customerId: data['customerId'] as String? ?? '',
        newspaperId: data['newspaperId'] as String? ?? id,
        newspaperName: data['newspaperName'] as String? ?? 'Unknown newspaper',
        currentVersionId: data['currentVersionId'] as String? ?? '',
        currentPauseId: data['currentPauseId'] as String? ?? '',
        status: SubscriptionStatus.fromValue(data['status']),
        startDate: _parseDate(data['startDate']),
        endDate: _parseOptionalDate(data['endDate']),
        currentEffectiveFrom: _parseDate(data['currentEffectiveFrom']),
        quantity: data['quantity'] as int? ?? 1,
        deliveryWeekdays: _intSet(data['deliveryWeekdays']),
        customPricePaise: data['customPricePaise'] as int?,
        customPriceReason: data['customPriceReason'] as String? ?? '',
        createdBy: data['createdBy'] as String? ?? '',
        updatedBy: data['updatedBy'] as String? ?? '',
        lastAuditId: data['lastAuditId'] as String? ?? '',
        createdAt: data['createdAt'] as DateTime?,
        updatedAt: data['updatedAt'] as DateTime?,
      );

  final String id;
  final String businessId;
  final String customerId;
  final String newspaperId;
  final String newspaperName;
  final String currentVersionId;
  final String currentPauseId;
  final SubscriptionStatus status;
  final LocalDate startDate;
  final LocalDate? endDate;
  final LocalDate currentEffectiveFrom;
  final int quantity;
  final Set<int> deliveryWeekdays;
  final int? customPricePaise;
  final String customPriceReason;
  final String createdBy;
  final String updatedBy;
  final String lastAuditId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isActive => status == SubscriptionStatus.active;
  bool get isPaused => status == SubscriptionStatus.paused;
  bool get isEnded => status == SubscriptionStatus.ended;

  SubscriptionInput toInput() => SubscriptionInput(
    newspaperId: newspaperId,
    startDate: startDate,
    endDate: endDate,
    quantity: quantity,
    deliveryWeekdays: deliveryWeekdays,
    customPricePaise: customPricePaise,
    customPriceReason: customPriceReason,
  );
}

class SubscriptionVersion {
  const SubscriptionVersion({
    required this.id,
    required this.businessId,
    required this.customerId,
    required this.subscriptionId,
    required this.newspaperId,
    required this.effectiveFrom,
    required this.effectiveTo,
    required this.quantity,
    required this.deliveryWeekdays,
    required this.customPricePaise,
    required this.customPriceReason,
    required this.predecessorVersionId,
    required this.successorVersionId,
    required this.status,
    required this.createdBy,
    this.createdAt,
  });

  factory SubscriptionVersion.fromMap(String id, Map<String, Object?> data) =>
      SubscriptionVersion(
        id: id,
        businessId: data['businessId'] as String? ?? '',
        customerId: data['customerId'] as String? ?? '',
        subscriptionId: data['subscriptionId'] as String? ?? '',
        newspaperId: data['newspaperId'] as String? ?? '',
        effectiveFrom: _parseDate(data['effectiveFrom']),
        effectiveTo: _parseOptionalDate(data['effectiveTo']),
        quantity: data['quantity'] as int? ?? 1,
        deliveryWeekdays: _intSet(data['deliveryWeekdays']),
        customPricePaise: data['customPricePaise'] as int?,
        customPriceReason: data['customPriceReason'] as String? ?? '',
        predecessorVersionId: data['predecessorVersionId'] as String? ?? '',
        successorVersionId: data['successorVersionId'] as String? ?? '',
        status: data['status'] as String? ?? 'closed',
        createdBy: data['createdBy'] as String? ?? '',
        createdAt: data['createdAt'] as DateTime?,
      );

  final String id;
  final String businessId;
  final String customerId;
  final String subscriptionId;
  final String newspaperId;
  final LocalDate effectiveFrom;
  final LocalDate? effectiveTo;
  final int quantity;
  final Set<int> deliveryWeekdays;
  final int? customPricePaise;
  final String customPriceReason;
  final String predecessorVersionId;
  final String successorVersionId;
  final String status;
  final String createdBy;
  final DateTime? createdAt;
}

class SubscriptionPause {
  const SubscriptionPause({
    required this.id,
    required this.businessId,
    required this.customerId,
    required this.subscriptionId,
    required this.startDate,
    required this.endDate,
    required this.reason,
    required this.status,
    required this.createdBy,
    required this.updatedBy,
    required this.lastAuditId,
    this.createdAt,
    this.updatedAt,
  });

  factory SubscriptionPause.fromMap(String id, Map<String, Object?> data) =>
      SubscriptionPause(
        id: id,
        businessId: data['businessId'] as String? ?? '',
        customerId: data['customerId'] as String? ?? '',
        subscriptionId: data['subscriptionId'] as String? ?? '',
        startDate: _parseDate(data['startDate']),
        endDate: _parseOptionalDate(data['endDate']),
        reason: data['reason'] as String? ?? '',
        status: data['status'] as String? ?? 'closed',
        createdBy: data['createdBy'] as String? ?? '',
        updatedBy: data['updatedBy'] as String? ?? '',
        lastAuditId: data['lastAuditId'] as String? ?? '',
        createdAt: data['createdAt'] as DateTime?,
        updatedAt: data['updatedAt'] as DateTime?,
      );

  final String id;
  final String businessId;
  final String customerId;
  final String subscriptionId;
  final LocalDate startDate;
  final LocalDate? endDate;
  final String reason;
  final String status;
  final String createdBy;
  final String updatedBy;
  final String lastAuditId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isOpen => status == 'open' && endDate == null;

  bool contains(LocalDate date) =>
      !date.isBefore(startDate) && (endDate == null || !date.isAfter(endDate!));
}

class SubscriptionAuditEntry {
  const SubscriptionAuditEntry({
    required this.id,
    required this.action,
    required this.actorId,
    required this.createdAt,
    required this.changedFields,
  });

  factory SubscriptionAuditEntry.fromMap(
    String id,
    Map<String, Object?> data,
  ) => SubscriptionAuditEntry(
    id: id,
    action: data['action'] as String? ?? 'subscriptionUpdated',
    actorId: data['actorId'] as String? ?? '',
    createdAt: data['createdAt'] as DateTime?,
    changedFields:
        data['changedFields'] is List
            ? (data['changedFields'] as List).whereType<String>().toList()
            : const [],
  );

  final String id;
  final String action;
  final String actorId;
  final DateTime? createdAt;
  final List<String> changedFields;
}

void validateReplacement({
  required CustomerSubscription current,
  required LocalDate effectiveFrom,
  required SubscriptionInput replacement,
}) {
  if (current.isEnded) {
    throw const AppException('An ended subscription cannot be changed.');
  }
  _validateDate(effectiveFrom, 'change effective date');
  replacement.validate();
  if (!effectiveFrom.isAfter(current.currentEffectiveFrom)) {
    throw const AppException(
      'New terms must begin after the current terms became effective.',
    );
  }
  if (effectiveFrom.isBefore(current.startDate) ||
      (replacement.endDate != null &&
          replacement.endDate!.isBefore(effectiveFrom))) {
    throw const AppException('New terms use an invalid effective date range.');
  }
  if (replacement.newspaperId != current.newspaperId) {
    throw const AppException(
      'End this subscription and create a new newspaper subscription instead.',
    );
  }
}

void validatePausePeriod({
  required CustomerSubscription subscription,
  required LocalDate startDate,
  required LocalDate? endDate,
  required String reason,
  required Iterable<SubscriptionPause> existingPauses,
}) {
  if (subscription.isEnded) {
    throw const AppException('An ended subscription cannot be paused.');
  }
  _validateDate(startDate, 'pause start date');
  if (startDate.isBefore(subscription.startDate) ||
      (subscription.endDate != null &&
          startDate.isAfter(subscription.endDate!))) {
    throw const AppException('Pause must fall within the subscription dates.');
  }
  if (endDate != null) {
    _validateDate(endDate, 'pause end date');
    if (endDate.isBefore(startDate) ||
        (subscription.endDate != null &&
            endDate.isAfter(subscription.endDate!))) {
      throw const AppException('Pause end date is outside the subscription.');
    }
  }
  final normalizedReason = reason.trim();
  if (normalizedReason.length < 2 || normalizedReason.length > 200) {
    throw const AppException('Enter a short reason for the delivery pause.');
  }
  for (final pause in existingPauses) {
    final leftEndsBefore =
        pause.endDate != null && pause.endDate!.isBefore(startDate);
    final rightEndsBefore =
        endDate != null && endDate.isBefore(pause.startDate);
    if (!leftEndsBefore && !rightEndsBefore) {
      throw const AppException('Pause periods cannot overlap.');
    }
  }
}

void validateEndDate(CustomerSubscription subscription, LocalDate endDate) {
  if (subscription.isEnded) {
    throw const AppException('This subscription has already ended.');
  }
  _validateDate(endDate, 'subscription end date');
  if (endDate.isBefore(subscription.startDate)) {
    throw const AppException(
      'End date cannot be before the subscription start.',
    );
  }
}

LocalDate _parseDate(Object? value) {
  if (value is! String) {
    throw const FormatException('A required business date is missing.');
  }
  return LocalDate.parse(value);
}

LocalDate? _parseOptionalDate(Object? value) =>
    value == null ? null : _parseDate(value);

Set<int> _intSet(Object? value) =>
    value is List ? value.whereType<int>().toSet() : <int>{};

void _validateDate(LocalDate date, String label) {
  final normalized = DateTime.utc(date.year, date.month, date.day);
  if (normalized.year != date.year ||
      normalized.month != date.month ||
      normalized.day != date.day) {
    throw AppException('Enter a valid $label.');
  }
}
