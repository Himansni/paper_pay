import 'dart:math' as math;

import 'package:paper_route/core/errors/app_exception.dart';

// Firestore Rules must validate every allocation in each atomic ledger write.
// Two billing components keeps that validation below the Rules expression
// limit while still supporting deterministic multi-month payments.
const maximumPaymentAllocations = 2;
const maximumCollectionAmountPaise = 9000000000000;

enum PaymentMethod {
  cash('cash', 'Cash'),
  upi('upi', 'UPI'),
  bankTransfer('bankTransfer', 'Bank transfer'),
  other('other', 'Other');

  const PaymentMethod(this.value, this.label);

  final String value;
  final String label;

  bool get requiresReference => this == upi || this == bankTransfer;
  bool get requiresNotes => this == other;

  static PaymentMethod fromValue(Object? value) =>
      values.firstWhere((method) => method.value == value, orElse: () => other);
}

enum ConfirmedPaymentStatus {
  confirmed('confirmed', 'Confirmed'),
  partiallyReversed('partiallyReversed', 'Partially reversed'),
  reversed('reversed', 'Reversed');

  const ConfirmedPaymentStatus(this.value, this.label);

  final String value;
  final String label;

  static ConfirmedPaymentStatus fromValue(Object? value) => values.firstWhere(
    (status) => status.value == value,
    orElse: () => confirmed,
  );
}

/// Local presentation state. Only [confirmed], [partiallyReversed], and
/// [reversed] correspond to persisted financial ledger entries.
enum CollectionConfirmationState {
  requested,
  awaitingConfirmation,
  confirmed,
  partiallyReversed,
  reversed,
}

class BillAllocation {
  const BillAllocation({
    required this.billId,
    required this.billingMonth,
    required this.amountPaise,
  });

  factory BillAllocation.fromMap(Map<String, Object?> data) => BillAllocation(
    billId: data['billId'] as String? ?? '',
    billingMonth: data['billingMonth'] as String? ?? '',
    amountPaise: data['amountPaise'] as int? ?? 0,
  );

  final String billId;
  final String billingMonth;
  final int amountPaise;

  Map<String, Object> toMap() => {
    'billId': billId,
    'billingMonth': billingMonth,
    'amountPaise': amountPaise,
  };
}

class PaymentAllocationState {
  const PaymentAllocationState({
    required this.billId,
    required this.billingMonth,
    required this.amountPaise,
    required this.reversedPaise,
  });

  factory PaymentAllocationState.fromMap(Map<String, Object?> data) =>
      PaymentAllocationState(
        billId: data['billId'] as String? ?? '',
        billingMonth: data['billingMonth'] as String? ?? '',
        amountPaise: data['amountPaise'] as int? ?? 0,
        reversedPaise: data['reversedPaise'] as int? ?? 0,
      );

  final String billId;
  final String billingMonth;
  final int amountPaise;
  final int reversedPaise;

  int get refundablePaise => amountPaise - reversedPaise;

  PaymentAllocationState reverse(int amountPaise) => PaymentAllocationState(
    billId: billId,
    billingMonth: billingMonth,
    amountPaise: this.amountPaise,
    reversedPaise: reversedPaise + amountPaise,
  );

  Map<String, Object> toMap() => {
    'billId': billId,
    'billingMonth': billingMonth,
    'amountPaise': amountPaise,
    'reversedPaise': reversedPaise,
  };
}

class ConfirmedPayment {
  const ConfirmedPayment({
    required this.id,
    required this.businessId,
    required this.customerId,
    required this.customerCode,
    required this.customerName,
    required this.amountPaise,
    required this.method,
    required this.status,
    required this.externalReference,
    required this.notes,
    required this.collectorUid,
    required this.allocations,
    required this.reversedPaise,
    required this.lastAuditId,
    required this.serverConfirmed,
    this.confirmedAt,
  });

  final String id;
  final String businessId;
  final String customerId;
  final String customerCode;
  final String customerName;
  final int amountPaise;
  final PaymentMethod method;
  final ConfirmedPaymentStatus status;
  final String externalReference;
  final String notes;
  final String collectorUid;
  final List<BillAllocation> allocations;
  final int reversedPaise;
  final String lastAuditId;
  final bool serverConfirmed;
  final DateTime? confirmedAt;

  int get netAmountPaise => amountPaise - reversedPaise;
}

class PaymentConfirmationInput {
  const PaymentConfirmationInput({
    required this.amountPaise,
    required this.method,
    required this.idempotencyKey,
    this.externalReference = '',
    this.notes = '',
    this.preferredBillId = '',
  });

  final int amountPaise;
  final PaymentMethod method;
  final String idempotencyKey;
  final String externalReference;
  final String notes;
  final String preferredBillId;

  PaymentConfirmationInput normalized() => PaymentConfirmationInput(
    amountPaise: amountPaise,
    method: method,
    idempotencyKey: idempotencyKey.trim(),
    externalReference: externalReference.trim(),
    notes: notes.trim(),
    preferredBillId: preferredBillId.trim(),
  );

  void validate() {
    final value = normalized();
    if (value.amountPaise <= 0 ||
        value.amountPaise > maximumCollectionAmountPaise) {
      throw const AppException('Enter a valid positive collection amount.');
    }
    _validateIdempotencyKey(value.idempotencyKey, label: 'payment');
    if (value.externalReference.length > 120) {
      throw const AppException(
        'Payment reference must be 120 characters or fewer.',
      );
    }
    if (value.notes.length > 300) {
      throw const AppException(
        'Payment notes must be 300 characters or fewer.',
      );
    }
    if (value.method.requiresReference && value.externalReference.length < 3) {
      throw AppException(
        'Enter the ${value.method.label} transaction or receipt reference.',
      );
    }
    if (value.method.requiresNotes && value.notes.length < 3) {
      throw const AppException('Describe the other payment method.');
    }
  }
}

class PaymentConfirmationResult {
  const PaymentConfirmationResult({
    required this.payment,
    required this.remainingOutstandingPaise,
    required this.serverConfirmed,
  });

  final ConfirmedPayment payment;
  final int remainingOutstandingPaise;
  final bool serverConfirmed;
}

class PaymentReversalInput {
  const PaymentReversalInput({
    required this.paymentId,
    required this.amountPaise,
    required this.reason,
    required this.idempotencyKey,
  });

  final String paymentId;
  final int amountPaise;
  final String reason;
  final String idempotencyKey;

  PaymentReversalInput normalized() => PaymentReversalInput(
    paymentId: paymentId.trim(),
    amountPaise: amountPaise,
    reason: reason.trim(),
    idempotencyKey: idempotencyKey.trim(),
  );

  void validate() {
    final value = normalized();
    if (value.paymentId.isEmpty) {
      throw const AppException('Select a confirmed payment to reverse.');
    }
    if (value.amountPaise <= 0 ||
        value.amountPaise > maximumCollectionAmountPaise) {
      throw const AppException('Enter a valid positive reversal amount.');
    }
    if (value.reason.length < 3 || value.reason.length > 300) {
      throw const AppException(
        'Enter a reversal reason between 3 and 300 characters.',
      );
    }
    _validateIdempotencyKey(value.idempotencyKey, label: 'reversal');
  }
}

class PaymentReversalRecord {
  const PaymentReversalRecord({
    required this.id,
    required this.businessId,
    required this.customerId,
    required this.paymentId,
    required this.amountPaise,
    required this.reason,
    required this.reversedBy,
    required this.allocations,
    required this.lastAuditId,
    required this.serverConfirmed,
    this.reversedAt,
  });

  final String id;
  final String businessId;
  final String customerId;
  final String paymentId;
  final int amountPaise;
  final String reason;
  final String reversedBy;
  final List<BillAllocation> allocations;
  final String lastAuditId;
  final bool serverConfirmed;
  final DateTime? reversedAt;
}

class PaymentReversalResult {
  const PaymentReversalResult({
    required this.reversal,
    required this.paymentStatus,
    required this.paymentReversedPaise,
    required this.remainingOutstandingPaise,
    required this.serverConfirmed,
  });

  final PaymentReversalRecord reversal;
  final ConfirmedPaymentStatus paymentStatus;
  final int paymentReversedPaise;
  final int remainingOutstandingPaise;
  final bool serverConfirmed;
}

class OutstandingBill {
  const OutstandingBill({
    required this.billId,
    required this.billingMonth,
    required this.sourceAmountPaise,
    required this.allocatedPaise,
    required this.reversedPaise,
    required this.outstandingPaise,
    required this.status,
    required this.revision,
  });

  final String billId;
  final String billingMonth;
  final int sourceAmountPaise;
  final int allocatedPaise;
  final int reversedPaise;
  final int outstandingPaise;
  final String status;
  final int revision;

  int get allocatablePaise => math.max(0, outstandingPaise);
}

class CustomerOutstandingSummary {
  const CustomerOutstandingSummary({
    required this.businessId,
    required this.customerId,
    required this.outstandingPaise,
    required this.confirmedPaise,
    required this.reversedPaise,
    required this.bills,
    required this.revision,
    required this.serverConfirmed,
    this.requiresProjectionSetup = false,
    this.updatedAt,
  });

  final String businessId;
  final String customerId;
  final int outstandingPaise;
  final int confirmedPaise;
  final int reversedPaise;
  final List<OutstandingBill> bills;
  final int revision;
  final bool serverConfirmed;
  final bool requiresProjectionSetup;
  final DateTime? updatedAt;

  int get amountDuePaise => math.max(0, outstandingPaise);
  int get creditPaise => math.max(0, -outstandingPaise);
}

class PaymentHistoryCursor {
  const PaymentHistoryCursor({
    required this.confirmedAt,
    required this.documentPath,
  });

  final DateTime confirmedAt;
  final String documentPath;
}

class PaymentHistoryPage {
  const PaymentHistoryPage({
    required this.items,
    required this.nextCursor,
    required this.hasMore,
  });

  final List<ConfirmedPayment> items;
  final PaymentHistoryCursor? nextCursor;
  final bool hasMore;
}

class UpiSettings {
  const UpiSettings({
    required this.businessId,
    required this.upiId,
    required this.payeeName,
    required this.referencePrefix,
    required this.enabled,
    required this.updatedBy,
    required this.lastAuditId,
    required this.serverConfirmed,
    this.createdAt,
    this.updatedAt,
  });

  final String businessId;
  final String upiId;
  final String payeeName;
  final String referencePrefix;
  final bool enabled;
  final String updatedBy;
  final String lastAuditId;
  final bool serverConfirmed;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isConfigured => upiId.isNotEmpty && payeeName.isNotEmpty;

  static UpiSettings empty(String businessId) => UpiSettings(
    businessId: businessId,
    upiId: '',
    payeeName: '',
    referencePrefix: 'PAPERROUTE',
    enabled: false,
    updatedBy: '',
    lastAuditId: '',
    serverConfirmed: true,
  );
}

class UpiSettingsInput {
  const UpiSettingsInput({
    required this.upiId,
    required this.payeeName,
    required this.referencePrefix,
    required this.enabled,
  });

  final String upiId;
  final String payeeName;
  final String referencePrefix;
  final bool enabled;

  UpiSettingsInput normalized() => UpiSettingsInput(
    upiId: upiId.trim().toLowerCase(),
    payeeName: payeeName.trim(),
    referencePrefix: referencePrefix.trim().toUpperCase(),
    enabled: enabled,
  );

  void validate() {
    final value = normalized();
    if (value.upiId.isNotEmpty &&
        !RegExp(
          r'^[A-Za-z0-9._-]{2,128}@[A-Za-z0-9.-]{2,64}$',
        ).hasMatch(value.upiId)) {
      throw const AppException('Enter a valid UPI ID.');
    }
    if (value.payeeName.length > 80 ||
        (value.upiId.isNotEmpty && value.payeeName.length < 2)) {
      throw const AppException(
        'Enter a payee name between 2 and 80 characters.',
      );
    }
    if (!RegExp(r'^[A-Z0-9_-]{2,20}$').hasMatch(value.referencePrefix)) {
      throw const AppException(
        'Reference prefix must use 2–20 letters, numbers, hyphens, or underscores.',
      );
    }
    if (value.enabled && (value.upiId.isEmpty || value.payeeName.isEmpty)) {
      throw const AppException('Configure the UPI ID and payee name first.');
    }
  }
}

void _validateIdempotencyKey(String value, {required String label}) {
  if (value.length < 8 ||
      value.length > 100 ||
      !RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(value)) {
    throw AppException(
      'The $label retry key is invalid. Start a new $label action.',
      code: 'invalid-idempotency-key',
    );
  }
}
