import 'package:paper_route/core/domain/local_date.dart';
import 'package:paper_route/core/errors/app_exception.dart';

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

enum BillPriceSource {
  customerSpecific('customerSpecific', 'Customer-specific'),
  exactDate('exactDate', 'Exact-date rule'),
  effectivePeriod('effectivePeriod', 'Effective-period rule'),
  defaultPrice('defaultPrice', 'Newspaper default');

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
  });

  final String ruleId;
  final LocalDate startDate;
  final LocalDate endDate;
  final int pricePaise;
  final bool isExactDate;
  final int revision;

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
        billingMonth: data['billingMonth'] as String? ?? '',
        amountPaise: data['amountPaise'] as int? ?? 0,
        reason: data['reason'] as String? ?? '',
        referenceBillMonth: data['referenceBillMonth'] as String? ?? '',
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
        unitPricePaise: data['unitPricePaise'] as int? ?? 0,
        quantity: data['quantity'] as int? ?? 0,
        priceSource: BillPriceSource.fromValue(data['priceSource']),
        priceSourceId: data['priceSourceId'] as String? ?? '',
        priceRuleRevision: data['priceRuleRevision'] as int? ?? 0,
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
        deliveryCount: data['deliveryCount'] as int? ?? 0,
        subtotalPaise: data['subtotalPaise'] as int? ?? 0,
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
    this.finalizedAt,
  });

  factory FinalizedMonthlyBill.fromMap(String id, Map<String, Object?> data) =>
      FinalizedMonthlyBill(
        id: id,
        businessId: data['businessId'] as String? ?? '',
        customerId: data['customerId'] as String? ?? '',
        customerCode: data['customerCode'] as String? ?? '',
        customerName: data['customerName'] as String? ?? '',
        customerAddress: data['customerAddress'] as String? ?? '',
        billingMonth: data['billingMonth'] as String? ?? id,
        openingBalancePaise: data['openingBalancePaise'] as int? ?? 0,
        previousBillId: data['previousBillId'] as String? ?? '',
        previousOutstandingPaise: data['previousOutstandingPaise'] as int? ?? 0,
        priorBalancePaise: data['priorBalancePaise'] as int? ?? 0,
        currentChargesPaise: data['currentChargesPaise'] as int? ?? 0,
        adjustmentsPaise: data['adjustmentsPaise'] as int? ?? 0,
        totalDuePaise: data['totalDuePaise'] as int? ?? 0,
        lineItemCount: data['lineItemCount'] as int? ?? 0,
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
        calculationVersion: data['calculationVersion'] as String? ?? '',
        finalizedBy: data['finalizedBy'] as String? ?? '',
        lastAuditId: data['lastAuditId'] as String? ?? '',
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

class BillingWorkspaceRow {
  const BillingWorkspaceRow({
    required this.customerId,
    required this.customerCode,
    required this.customerName,
    required this.areaId,
    required this.finalizedBill,
  });

  final String customerId;
  final String customerCode;
  final String customerName;
  final String areaId;
  final FinalizedMonthlyBill? finalizedBill;
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
