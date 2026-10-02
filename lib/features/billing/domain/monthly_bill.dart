import 'package:paper_route/core/domain/local_date.dart';
import 'package:paper_route/core/errors/app_exception.dart';
import 'package:paper_route/features/newspapers/domain/newspaper.dart';

const phase5CalculationVersion = 'paper-route-monthly-v1';
const maximumAtomicBillLineItems = 475;

abstract final class BillingMoney {
  static String formatPaise(int paise) {
    final magnitude = paise.abs();
    final rupees = magnitude ~/ 100;
    final remainder = (magnitude % 100).toString().padLeft(2, '0');
    final rupeeDigits = rupees.toString();
    final grouped = _groupIndianRupees(rupeeDigits);
    return '${paise < 0 ? '-' : ''}₹$grouped.$remainder';
  }

  static String _groupIndianRupees(String digits) {
    if (digits.length <= 3) return digits;
    final tail = digits.substring(digits.length - 3);
    var prefix = digits.substring(0, digits.length - 3);
    final groups = <String>[];
    while (prefix.length > 2) {
      groups.insert(0, prefix.substring(prefix.length - 2));
      prefix = prefix.substring(0, prefix.length - 2);
    }
    if (prefix.isNotEmpty) groups.insert(0, prefix);
    return '${groups.join(',')},$tail';
  }
}

String billingMonthKey(LocalDate month) {
  if (!month.isValid || month.day != 1) {
    throw const AppException('Select a valid billing month.');
  }
  return '${month.year.toString().padLeft(4, '0')}-'
      '${month.month.toString().padLeft(2, '0')}';
}

LocalDate billingMonthFromKey(String value) {
  if (!RegExp(r'^\d{4}-\d{2}$').hasMatch(value)) {
    throw const FormatException('Invalid billing month.');
  }
  return LocalDate.parse('$value-01');
}

/// Safely decodes a billingMonth value from Firestore.
///
/// Canonical representation is "YYYY-MM" (e.g. "2026-09").
/// Also supports known legacy integer representation (e.g. 202609) by
/// converting to canonical "YYYY-MM".
/// Malformed or ambiguous values produce a safe [AppException].
String parseBillingMonthFromFirestore(Object? raw, {String fallbackId = ''}) {
  if (raw == null) {
    if (fallbackId.isNotEmpty &&
        RegExp(r'^\d{4}-(0[1-9]|1[0-2])$').hasMatch(fallbackId.trim())) {
      return fallbackId.trim();
    }
    if (fallbackId.isNotEmpty) {
      throw AppException(
        'Invalid fallback billingMonth: "$fallbackId"',
        code: 'invalid-billing-month',
      );
    }
    throw const AppException(
      'Missing billingMonth in billing document.',
      code: 'invalid-billing-month',
    );
  }
  if (raw is String) {
    final trimmed = raw.trim();
    if (RegExp(r'^\d{4}-(0[1-9]|1[0-2])$').hasMatch(trimmed)) {
      return trimmed;
    }
    // Handle known legacy representation formatted as 6-digit string: e.g. "202609"
    if (RegExp(r'^\d{6}$').hasMatch(trimmed)) {
      final y = trimmed.substring(0, 4);
      final m = trimmed.substring(4, 6);
      final monthNum = int.tryParse(m);
      if (monthNum != null && monthNum >= 1 && monthNum <= 12) {
        return '$y-$m';
      }
    }
    throw AppException(
      'Invalid billingMonth string format: "$raw"',
      code: 'invalid-billing-month',
    );
  }
  if (raw is int) {
    // Known legacy representation: e.g. 202609
    final str = raw.toString();
    if (str.length == 6) {
      final y = str.substring(0, 4);
      final m = str.substring(4, 6);
      final monthNum = int.tryParse(m);
      if (monthNum != null && monthNum >= 1 && monthNum <= 12) {
        return '$y-$m';
      }
    }
    throw AppException(
      'Unsupported integer billingMonth representation: $raw',
      code: 'invalid-billing-month',
    );
  }
  throw AppException(
    'Unexpected type for billingMonth: ${raw.runtimeType}',
    code: 'invalid-billing-month',
  );
}

/// Safely decodes calculationVersion from Firestore, accepting both string and int representations.
String parseCalculationVersionFromFirestore(Object? raw) {
  if (raw == null) return '';
  if (raw is String) return raw;
  if (raw is num) return raw.toString();
  return raw.toString();
}

enum BillPriceSource {
  customerSpecific('customerSpecific', 'Customer-specific'),
  exactDate('exactDate', 'Exact-date rule'),
  effectivePeriod('effectivePeriod', 'Effective-period rule'),
  defaultPrice('defaultPrice', 'Newspaper default'),
  manual('manual', 'Manual entry');

  const BillPriceSource(this.value, this.label);

  final String value;
  final String label;

  static BillPriceSource fromValue(Object? value) => values.firstWhere(
    (source) => source.value == value,
    orElse: () => defaultPrice,
  );
}

class BillingTermSnapshot {
  const BillingTermSnapshot({
    required this.subscriptionId,
    required this.versionId,
    required this.newspaperId,
    required this.newspaperName,
    required this.effectiveFrom,
    required this.effectiveTo,
    required this.quantity,
    required this.deliveryWeekdays,
    required this.customPricePaise,
  });

  final String subscriptionId;
  final String versionId;
  final String newspaperId;
  final String newspaperName;
  final LocalDate effectiveFrom;
  final LocalDate? effectiveTo;
  final int quantity;
  final Set<int> deliveryWeekdays;
  final int? customPricePaise;

  bool includes(LocalDate date) =>
      !date.isBefore(effectiveFrom) &&
      (effectiveTo == null || !date.isAfter(effectiveTo!)) &&
      deliveryWeekdays.contains(date.isoWeekday);
}

class BillingPauseSnapshot {
  const BillingPauseSnapshot({
    required this.subscriptionId,
    required this.pauseId,
    required this.startDate,
    required this.endDate,
  });

  final String subscriptionId;
  final String pauseId;
  final LocalDate startDate;
  final LocalDate? endDate;

  bool includes(LocalDate date) =>
      !date.isBefore(startDate) && (endDate == null || !date.isAfter(endDate!));
}

class BillingDeliveryExceptionSnapshot {
  const BillingDeliveryExceptionSnapshot({
    required this.id,
    required this.subscriptionId,
    required this.serviceDate,
  });

  final String id;
  final String subscriptionId;
  final LocalDate serviceDate;
}

class BillingPriceRuleSnapshot {
  const BillingPriceRuleSnapshot({
    required this.ruleId,
    required this.startDate,
    required this.endDate,
    required this.pricePaise,
    required this.isExactDate,
    required this.revision,
    this.pricingBasis = PricingBasis.daily,
  });

  final String ruleId;
  final LocalDate startDate;
  final LocalDate endDate;
  final int pricePaise;
  final bool isExactDate;
  final int revision;
  final PricingBasis pricingBasis;

  bool includes(LocalDate date) =>
      !date.isBefore(startDate) && !date.isAfter(endDate);
}

class BillingNewspaperSnapshot {
  const BillingNewspaperSnapshot({
    required this.newspaperId,
    required this.name,
    required this.defaultPricePaise,
    required this.rules,
  });

  final String newspaperId;
  final String name;
  final int defaultPricePaise;
  final List<BillingPriceRuleSnapshot> rules;
}

class BillingAdjustment {
  const BillingAdjustment({
    required this.id,
    required this.billingMonth,
    required this.amountPaise,
    required this.reason,
    required this.referenceBillMonth,
    required this.createdBy,
    this.createdAt,
  });

  factory BillingAdjustment.fromMap(String id, Map<String, Object?> data) =>
      BillingAdjustment(
        id: id,
        billingMonth: parseBillingMonthFromFirestore(data['billingMonth']),
        amountPaise: (data['amountPaise'] as num?)?.toInt() ?? 0,
        reason: data['reason'] as String? ?? '',
        referenceBillMonth:
            data['referenceBillMonth'] != null &&
                    data['referenceBillMonth'].toString().isNotEmpty
                ? parseBillingMonthFromFirestore(data['referenceBillMonth'])
                : '',
        createdBy: data['createdBy'] as String? ?? '',
        createdAt: data['createdAt'] as DateTime?,
      );

  final String id;
  final String billingMonth;
  final int amountPaise;
  final String reason;
  final String referenceBillMonth;
  final String createdBy;
  final DateTime? createdAt;
}

class BillingAdjustmentInput {
  const BillingAdjustmentInput({
    required this.billingMonth,
    required this.amountPaise,
    required this.reason,
    this.referenceBillMonth = '',
  });

  final String billingMonth;
  final int amountPaise;
  final String reason;
  final String referenceBillMonth;

  BillingAdjustmentInput normalized() => BillingAdjustmentInput(
    billingMonth: billingMonth.trim(),
    amountPaise: amountPaise,
    reason: reason.trim(),
    referenceBillMonth: referenceBillMonth.trim(),
  );

  void validate() {
    final value = normalized();
    billingMonthFromKey(value.billingMonth);
    if (value.amountPaise == 0 || value.amountPaise.abs() > 100000000) {
      throw const AppException(
        'Adjustment must be non-zero and no more than ₹10,00,000.',
      );
    }
    if (value.reason.length < 3 || value.reason.length > 300) {
      throw const AppException(
        'Enter an adjustment reason between 3 and 300 characters.',
      );
    }
    if (value.referenceBillMonth.isNotEmpty) {
      billingMonthFromKey(value.referenceBillMonth);
      if (value.referenceBillMonth.compareTo(value.billingMonth) >= 0) {
        throw const AppException(
          'A correction reference must identify an earlier finalized bill.',
        );
      }
    }
  }
}

class MonthlyBillLineItem {
  const MonthlyBillLineItem({
    required this.chargeKey,
    required this.serviceDate,
    required this.subscriptionId,
    required this.versionId,
    required this.newspaperId,
    required this.newspaperName,
    required this.unitPricePaise,
    required this.quantity,
    required this.priceSource,
    required this.priceSourceId,
    required this.priceRuleRevision,
  });

  factory MonthlyBillLineItem.fromMap(String id, Map<String, Object?> data) =>
      MonthlyBillLineItem(
        chargeKey: id,
        serviceDate: LocalDate.parse(data['serviceDate'] as String? ?? ''),
        subscriptionId: data['subscriptionId'] as String? ?? '',
        versionId: data['versionId'] as String? ?? '',
        newspaperId: data['newspaperId'] as String? ?? '',
        newspaperName: data['newspaperName'] as String? ?? '',
        unitPricePaise: (data['unitPricePaise'] as num?)?.toInt() ?? 0,
        quantity: (data['quantity'] as num?)?.toInt() ?? 0,
        priceSource: BillPriceSource.fromValue(data['priceSource']),
        priceSourceId: data['priceSourceId'] as String? ?? '',
        priceRuleRevision: (data['priceRuleRevision'] as num?)?.toInt() ?? 0,
      );

  final String chargeKey;
  final LocalDate serviceDate;
  final String subscriptionId;
  final String versionId;
  final String newspaperId;
  final String newspaperName;
  final int unitPricePaise;
  final int quantity;
  final BillPriceSource priceSource;
  final String priceSourceId;
  final int priceRuleRevision;

  int get totalPaise => unitPricePaise * quantity;

  Map<String, Object> toMap() => {
    'chargeKey': chargeKey,
    'serviceDate': serviceDate.toString(),
    'subscriptionId': subscriptionId,
    'versionId': versionId,
    'newspaperId': newspaperId,
    'newspaperName': newspaperName,
    'unitPricePaise': unitPricePaise,
    'quantity': quantity,
    'totalPaise': totalPaise,
    'priceSource': priceSource.value,
    'priceSourceId': priceSourceId,
    'priceRuleRevision': priceRuleRevision,
  };
}

class BillNewspaperSummary {
  const BillNewspaperSummary({
    required this.newspaperId,
    required this.newspaperName,
    required this.deliveryCount,
    required this.subtotalPaise,
  });

  factory BillNewspaperSummary.fromMap(Map<String, Object?> data) =>
      BillNewspaperSummary(
        newspaperId: data['newspaperId'] as String? ?? '',
        newspaperName: data['newspaperName'] as String? ?? '',
        deliveryCount: (data['deliveryCount'] as num?)?.toInt() ?? 0,
        subtotalPaise:
            (data['subtotalPaise'] as num?)?.toInt() ??
            (data['totalPaise'] as num?)?.toInt() ??
            0,
      );

  final String newspaperId;
  final String newspaperName;
  final int deliveryCount;
  final int subtotalPaise;

  Map<String, Object> toMap() => {
    'newspaperId': newspaperId,
    'newspaperName': newspaperName,
    'deliveryCount': deliveryCount,
    'subtotalPaise': subtotalPaise,
  };
}

class BillPreviewIssue {
  const BillPreviewIssue({required this.code, required this.message});

  final String code;
  final String message;
}

class MonthlyBillPreview {
  const MonthlyBillPreview({
    required this.businessId,
    required this.customerId,
    required this.customerCode,
    required this.customerName,
    required this.customerAddress,
    required this.billingMonth,
    required this.lineItems,
    required this.openingBalancePaise,
    required this.previousBillId,
    required this.previousOutstandingPaise,
    required this.adjustments,
    required this.issues,
    required this.alreadyFinalizedBill,
    this.areaId = '',
    this.assignedEmployeeId = '',
    this.customerStatus = 'active',
    this.billingSource = 'generated',
  });

  final String businessId;
  final String customerId;
  final String customerCode;
  final String customerName;
  final String customerAddress;
  final String billingMonth;
  final List<MonthlyBillLineItem> lineItems;
  final int openingBalancePaise;
  final String previousBillId;
  final int previousOutstandingPaise;
  final List<BillingAdjustment> adjustments;
  final List<BillPreviewIssue> issues;
  final FinalizedMonthlyBill? alreadyFinalizedBill;
  final String areaId;
  final String assignedEmployeeId;
  final String customerStatus;
  final String billingSource;

  bool get canFinalize => issues.isEmpty && alreadyFinalizedBill == null;
  int get currentChargesPaise =>
      lineItems.fold(0, (total, item) => total + item.totalPaise);
  int get adjustmentsPaise => adjustments.fold(
    0,
    (total, adjustment) => total + adjustment.amountPaise,
  );
  int get priorBalancePaise =>
      previousBillId.isEmpty ? openingBalancePaise : previousOutstandingPaise;
  int get totalDuePaise =>
      priorBalancePaise + currentChargesPaise + adjustmentsPaise;

  Map<String, int> get newspaperSubtotalsPaise {
    final result = <String, int>{};
    for (final item in lineItems) {
      result.update(
        item.newspaperName,
        (value) => value + item.totalPaise,
        ifAbsent: () => item.totalPaise,
      );
    }
    return result;
  }

  List<BillNewspaperSummary> get newspaperSummaries {
    final grouped = <String, List<MonthlyBillLineItem>>{};
    for (final item in lineItems) {
      grouped.putIfAbsent(item.newspaperId, () => []).add(item);
    }
    final result = [
      for (final entry in grouped.entries)
        BillNewspaperSummary(
          newspaperId: entry.key,
          newspaperName: entry.value.first.newspaperName,
          deliveryCount: entry.value.length,
          subtotalPaise: entry.value.fold(
            0,
            (total, item) => total + item.totalPaise,
          ),
        ),
    ];
    result.sort(
      (left, right) => left.newspaperName.compareTo(right.newspaperName),
    );
    return result;
  }

  Map<String, Object> toMap() => {
    'currentChargesPaise': currentChargesPaise,
    'lineItems': [for (final item in lineItems) item.toMap()],
    'newspaperSummaries': [
      for (final summary in newspaperSummaries) summary.toMap(),
    ],
  };
}

class FinalizedMonthlyBill {
  const FinalizedMonthlyBill({
    required this.id,
    required this.businessId,
    required this.customerId,
    required this.customerCode,
    required this.customerName,
    required this.customerAddress,
    required this.billingMonth,
    required this.openingBalancePaise,
    required this.previousBillId,
    required this.previousOutstandingPaise,
    required this.priorBalancePaise,
    required this.currentChargesPaise,
    required this.adjustmentsPaise,
    required this.totalDuePaise,
    required this.lineItemCount,
    required this.newspaperSummaries,
    required this.calculationVersion,
    required this.finalizedBy,
    required this.lastAuditId,
    this.areaId = '',
    this.assignedEmployeeId = '',
    this.customerStatus = 'active',
    this.billingSource = 'generated',
    this.finalizedAt,
  });

  factory FinalizedMonthlyBill.fromMap(
    String id,
    Map<String, Object?> data,
  ) => FinalizedMonthlyBill(
    id: id,
    businessId: data['businessId'] as String? ?? '',
    customerId: data['customerId'] as String? ?? '',
    customerCode: data['customerCode'] as String? ?? '',
    customerName: data['customerName'] as String? ?? '',
    customerAddress: data['customerAddress'] as String? ?? '',
    billingMonth: parseBillingMonthFromFirestore(
      data['billingMonth'],
      fallbackId: id,
    ),
    openingBalancePaise: (data['openingBalancePaise'] as num?)?.toInt() ?? 0,
    previousBillId: data['previousBillId']?.toString() ?? '',
    previousOutstandingPaise:
        (data['previousOutstandingPaise'] as num?)?.toInt() ?? 0,
    priorBalancePaise: (data['priorBalancePaise'] as num?)?.toInt() ?? 0,
    currentChargesPaise: (data['currentChargesPaise'] as num?)?.toInt() ?? 0,
    adjustmentsPaise: (data['adjustmentsPaise'] as num?)?.toInt() ?? 0,
    totalDuePaise: (data['totalDuePaise'] as num?)?.toInt() ?? 0,
    lineItemCount: (data['lineItemCount'] as num?)?.toInt() ?? 0,
    newspaperSummaries:
        data['newspaperSummaries'] is List
            ? (data['newspaperSummaries'] as List)
                .whereType<Map>()
                .map(
                  (value) => BillNewspaperSummary.fromMap(
                    value.cast<String, Object?>(),
                  ),
                )
                .toList()
            : const [],
    calculationVersion: parseCalculationVersionFromFirestore(
      data['calculationVersion'],
    ),
    finalizedBy: data['finalizedBy'] as String? ?? '',
    lastAuditId: data['lastAuditId'] as String? ?? '',
    areaId: data['areaId'] as String? ?? '',
    assignedEmployeeId: data['assignedEmployeeId'] as String? ?? '',
    customerStatus: data['customerStatus'] as String? ?? 'active',
    billingSource: data['billingSource'] as String? ?? 'generated',
    finalizedAt: data['finalizedAt'] as DateTime?,
  );

  final String id;
  final String businessId;
  final String customerId;
  final String customerCode;
  final String customerName;
  final String customerAddress;
  final String billingMonth;
  final int openingBalancePaise;
  final String previousBillId;
  final int previousOutstandingPaise;
  final int priorBalancePaise;
  final int currentChargesPaise;
  final int adjustmentsPaise;
  final int totalDuePaise;
  final int lineItemCount;
  final List<BillNewspaperSummary> newspaperSummaries;
  final String calculationVersion;
  final String finalizedBy;
  final String lastAuditId;
  final String areaId;
  final String assignedEmployeeId;
  final String customerStatus;
  final String billingSource;
  final DateTime? finalizedAt;
}

class BillLinePageCursor {
  const BillLinePageCursor({
    required this.serviceDate,
    required this.chargeKey,
  });

  final String serviceDate;
  final String chargeKey;
}

class BillLinePage {
  const BillLinePage({
    required this.items,
    required this.nextCursor,
    required this.hasMore,
  });

  final List<MonthlyBillLineItem> items;
  final BillLinePageCursor? nextCursor;
  final bool hasMore;
}

class BillingMonthlyPrice {
  const BillingMonthlyPrice({
    required this.id,
    required this.businessId,
    required this.billingMonth,
    required this.newspaperId,
    required this.newspaperName,
    required this.pricePaise,
    required this.pricingBasis,
    this.updatedBy = '',
    this.updatedAt,
  });

  factory BillingMonthlyPrice.fromMap(String id, Map<String, Object?> data) =>
      BillingMonthlyPrice(
        id: id,
        businessId: data['businessId'] as String? ?? '',
        billingMonth: data['billingMonth'] as String? ?? '',
        newspaperId: data['newspaperId'] as String? ?? '',
        newspaperName: data['newspaperName'] as String? ?? '',
        pricePaise: (data['pricePaise'] as num?)?.toInt() ?? 0,
        pricingBasis: PricingBasis.fromValue(data['pricingBasis']),
        updatedBy: data['updatedBy'] as String? ?? '',
        updatedAt: data['updatedAt'] as DateTime?,
      );

  final String id;
  final String businessId;
  final String billingMonth;
  final String newspaperId;
  final String newspaperName;
  final int pricePaise;
  final PricingBasis pricingBasis;
  final String updatedBy;
  final DateTime? updatedAt;

  Map<String, Object> toMap() => {
    'businessId': businessId,
    'billingMonth': billingMonth,
    'newspaperId': newspaperId,
    'newspaperName': newspaperName,
    'pricePaise': pricePaise,
    'pricingBasis': pricingBasis.value,
    'updatedBy': updatedBy,
  };
}

class BillingWorkspaceRow {
  const BillingWorkspaceRow({
    required this.customerId,
    required this.customerCode,
    required this.customerName,
    required this.areaId,
    required this.finalizedBill,
    this.assignedEmployeeId = '',
    this.publicationId = '',
    this.publicationName = '',
    this.publicationIds = const {},
    this.hasPricing = true,
    this.estimatedTotalPaise = 0,
    this.hasFailed = false,
    this.lastFailureReason,
  });

  final String customerId;
  final String customerCode;
  final String customerName;
  final String areaId;
  final FinalizedMonthlyBill? finalizedBill;
  final String assignedEmployeeId;
  final String publicationId;
  final String publicationName;
  final Set<String> publicationIds;
  final bool hasPricing;
  final int estimatedTotalPaise;
  final bool hasFailed;
  final String? lastFailureReason;
}

class BillingWorkspaceCursor {
  const BillingWorkspaceCursor({
    required this.searchName,
    required this.customerId,
  });

  final String searchName;
  final String customerId;
}

class BillingWorkspaceResult {
  const BillingWorkspaceResult({
    required this.rows,
    required this.nextCursor,
    required this.hasMore,
  });

  final List<BillingWorkspaceRow> rows;
  final BillingWorkspaceCursor? nextCursor;
  final bool hasMore;
}

class MonthlyBillPlanner {
  const MonthlyBillPlanner();

  List<MonthlyBillLineItem> calculate({
    required String customerId,
    required LocalDate month,
    required List<BillingTermSnapshot> terms,
    required List<BillingPauseSnapshot> pauses,
    required List<BillingDeliveryExceptionSnapshot> deliveryExceptions,
    required Map<String, BillingNewspaperSnapshot> newspapers,
  }) {
    billingMonthKey(month);
    _validateTermTimelines(terms);
    final seen = <String>{};
    final lines = <MonthlyBillLineItem>[];
    final noDelivery = {
      for (final exception in deliveryExceptions)
        '${exception.subscriptionId}:${exception.serviceDate}',
    };

    for (final term in terms) {
      _validateTerm(term);
      final paper = newspapers[term.newspaperId];
      if (paper == null) {
        throw AppException(
          'Missing newspaper ${term.newspaperId} for subscription '
          '${term.subscriptionId}.',
          code: 'missing-newspaper',
        );
      }
      if (paper.name.trim().length < 2 ||
          paper.defaultPricePaise < 0 ||
          paper.defaultPricePaise > 1000000) {
        throw AppException(
          'Missing or invalid default price for ${paper.name}.',
          code: 'missing-price',
        );
      }
      final monthlyRules =
          paper.rules
              .where(
                (rule) =>
                    !rule.isExactDate &&
                    rule.pricingBasis == PricingBasis.monthly &&
                    !rule.startDate.isAfter(
                      LocalDate(month.year, month.month, month.daysInMonth),
                    ) &&
                    !rule.endDate.isBefore(
                      LocalDate(month.year, month.month, 1),
                    ),
              )
              .toList();
      if (monthlyRules.isNotEmpty) {
        final monthlyRule = monthlyRules.single;
        final activeDates = <LocalDate>[];
        for (var day = 1; day <= month.daysInMonth; day++) {
          final date = LocalDate(month.year, month.month, day);
          if (!term.includes(date)) continue;
          if (pauses.any(
            (p) => p.subscriptionId == term.subscriptionId && p.includes(date),
          )) {
            continue;
          }
          if (noDelivery.contains('${term.subscriptionId}:$date')) continue;
          activeDates.add(date);
        }
        if (activeDates.isNotEmpty) {
          final key =
              '$customerId:${term.subscriptionId}:${month.year}-${month.month.toString().padLeft(2, '0')}';
          if (!seen.add(key)) {
            throw AppException(
              'Overlapping subscription versions would duplicate $month for ${paper.name}.',
              code: 'ambiguous-subscription-terms',
            );
          }
          final hasCustomerOverride = term.customPricePaise != null;
          lines.add(
            MonthlyBillLineItem(
              chargeKey: key,
              serviceDate: activeDates.first,
              subscriptionId: term.subscriptionId,
              versionId: term.versionId,
              newspaperId: term.newspaperId,
              newspaperName: paper.name,
              unitPricePaise:
                  hasCustomerOverride
                      ? term.customPricePaise!
                      : monthlyRule.pricePaise,
              quantity: term.quantity,
              priceSource:
                  hasCustomerOverride
                      ? BillPriceSource.customerSpecific
                      : BillPriceSource.effectivePeriod,
              priceSourceId:
                  hasCustomerOverride
                      ? term.subscriptionId
                      : monthlyRule.ruleId,
              priceRuleRevision: hasCustomerOverride ? 0 : monthlyRule.revision,
            ),
          );
        }
        continue;
      }

      for (var day = 1; day <= month.daysInMonth; day++) {
        final date = LocalDate(month.year, month.month, day);
        if (!term.includes(date)) continue;
        if (pauses.any(
          (pause) =>
              pause.subscriptionId == term.subscriptionId &&
              pause.includes(date),
        )) {
          continue;
        }
        if (noDelivery.contains('${term.subscriptionId}:$date')) continue;

        final key = '$customerId:${term.subscriptionId}:$date';
        if (!seen.add(key)) {
          throw AppException(
            'Overlapping subscription versions would duplicate $date for '
            '${paper.name}.',
            code: 'ambiguous-subscription-terms',
          );
        }
        final price = _resolvePrice(term: term, paper: paper, date: date);
        lines.add(
          MonthlyBillLineItem(
            chargeKey: key,
            serviceDate: date,
            subscriptionId: term.subscriptionId,
            versionId: term.versionId,
            newspaperId: term.newspaperId,
            newspaperName: paper.name,
            unitPricePaise: price.$1,
            quantity: term.quantity,
            priceSource: price.$2,
            priceSourceId: price.$3,
            priceRuleRevision: price.$4,
          ),
        );
      }
    }
    lines.sort((left, right) {
      final byDate = left.serviceDate.compareTo(right.serviceDate);
      return byDate != 0
          ? byDate
          : left.subscriptionId.compareTo(right.subscriptionId);
    });
    if (lines.length > maximumAtomicBillLineItems) {
      throw const AppException(
        'This bill has too many daily lines for one safe atomic finalization. '
        'Split the account configuration before finalizing.',
        code: 'bill-too-large',
      );
    }
    return List.unmodifiable(lines);
  }

  void _validateTerm(BillingTermSnapshot term) {
    if (term.subscriptionId.isEmpty ||
        term.versionId.isEmpty ||
        term.newspaperId.isEmpty ||
        term.quantity < 1 ||
        term.quantity > 50 ||
        term.deliveryWeekdays.isEmpty ||
        term.deliveryWeekdays.any((day) => day < 1 || day > 7) ||
        (term.effectiveTo != null &&
            term.effectiveTo!.isBefore(term.effectiveFrom)) ||
        (term.customPricePaise != null &&
            (term.customPricePaise! < 0 || term.customPricePaise! > 1000000))) {
      throw AppException(
        'Subscription version ${term.versionId} is invalid.',
        code: 'invalid-subscription-version',
      );
    }
  }

  void _validateTermTimelines(List<BillingTermSnapshot> terms) {
    final grouped = <String, List<BillingTermSnapshot>>{};
    for (final term in terms) {
      _validateTerm(term);
      grouped.putIfAbsent(term.subscriptionId, () => []).add(term);
    }
    for (final entry in grouped.entries) {
      final timeline =
          entry.value..sort(
            (left, right) => left.effectiveFrom.compareTo(right.effectiveFrom),
          );
      for (var index = 1; index < timeline.length; index++) {
        final previousEnd = timeline[index - 1].effectiveTo;
        if (previousEnd == null ||
            !previousEnd.isBefore(timeline[index].effectiveFrom)) {
          throw AppException(
            'Overlapping subscription versions exist for ${entry.key}.',
            code: 'ambiguous-subscription-terms',
          );
        }
      }
    }
  }

  (int, BillPriceSource, String, int) _resolvePrice({
    required BillingTermSnapshot term,
    required BillingNewspaperSnapshot paper,
    required LocalDate date,
  }) {
    final custom = term.customPricePaise;
    if (custom != null) {
      return (custom, BillPriceSource.customerSpecific, term.versionId, 0);
    }
    final matching = paper.rules.where((rule) => rule.includes(date)).toList();
    final exact = matching.where((rule) => rule.isExactDate).toList();
    final periods = matching.where((rule) => !rule.isExactDate).toList();
    if (exact.length > 1 || periods.length > 1) {
      throw AppException(
        'Ambiguous active pricing for ${paper.name} on $date.',
        code: 'ambiguous-price',
      );
    }
    if (exact.isNotEmpty) {
      final rule = exact.single;
      _validateResolvedRule(rule, paper.name);
      return (
        rule.pricePaise,
        BillPriceSource.exactDate,
        rule.ruleId,
        rule.revision,
      );
    }
    if (periods.isNotEmpty) {
      final rule = periods.single;
      _validateResolvedRule(rule, paper.name);
      return (
        rule.pricePaise,
        BillPriceSource.effectivePeriod,
        rule.ruleId,
        rule.revision,
      );
    }
    return (
      paper.defaultPricePaise,
      BillPriceSource.defaultPrice,
      paper.newspaperId,
      0,
    );
  }

  void _validateResolvedRule(BillingPriceRuleSnapshot rule, String name) {
    if (rule.ruleId.isEmpty ||
        rule.revision < 1 ||
        rule.pricePaise < 0 ||
        rule.pricePaise > 1000000) {
      throw AppException(
        'Missing or invalid price source for $name.',
        code: 'missing-price',
      );
    }
  }
}

enum ManualBillCalculationMode {
  monthWise('Month wise'),
  dayWise('Day wise'),
  dateWise('Date wise');

  const ManualBillCalculationMode(this.label);
  final String label;
}

class ManualDailyEntry {
  const ManualDailyEntry({
    required this.date,
    required this.unitPricePaise,
    this.isPaused = false,
  });

  final LocalDate date;
  final int unitPricePaise;
  final bool isPaused;
}

class ManualBillInput {
  const ManualBillInput({
    required this.customerId,
    required this.subscriptionId,
    required this.month,
    required this.mode,
    this.monthWiseAmountPaise,
    this.dailyEntries = const [],
    this.deliveryChargePaise = 0,
    this.discountPaise = 0,
  });

  final String customerId;
  final String subscriptionId;
  final LocalDate month;
  final ManualBillCalculationMode mode;
  final int? monthWiseAmountPaise;
  final List<ManualDailyEntry> dailyEntries;
  final int deliveryChargePaise;
  final int discountPaise;
}
