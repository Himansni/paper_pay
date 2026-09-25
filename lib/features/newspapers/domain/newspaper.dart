import 'package:paper_route/core/domain/local_date.dart';
import 'package:paper_route/core/errors/app_exception.dart';

enum NewspaperStatus {
  active('active', 'Active'),
  archived('archived', 'Archived');

  const NewspaperStatus(this.value, this.label);

  final String value;
  final String label;

  static NewspaperStatus fromValue(Object? value) =>
      value == archived.value ? archived : active;
}

enum NewspaperSearchField {
  name('name', 'Name'),
  newspaperCode('code', 'Newspaper code');

  const NewspaperSearchField(this.key, this.label);

  final String key;
  final String label;
}

class Newspaper {
  const Newspaper({
    required this.id,
    required this.businessId,
    required this.newspaperCode,
    required this.name,
    required this.searchName,
    required this.edition,
    required this.language,
    required this.defaultPricePaise,
    required this.status,
    required this.createdBy,
    required this.updatedBy,
    required this.lastAuditId,
    this.createdAt,
    this.updatedAt,
  });

  factory Newspaper.fromMap(String id, Map<String, Object?> data) => Newspaper(
    id: id,
    businessId: data['businessId'] as String? ?? '',
    newspaperCode: data['newspaperCode'] as String? ?? id,
    name: data['name'] as String? ?? '',
    searchName: data['searchName'] as String? ?? '',
    edition: data['edition'] as String? ?? '',
    language: data['language'] as String? ?? '',
    defaultPricePaise: data['defaultPricePaise'] as int? ?? 0,
    status: NewspaperStatus.fromValue(data['status']),
    createdBy: data['createdBy'] as String? ?? '',
    updatedBy: data['updatedBy'] as String? ?? '',
    lastAuditId: data['lastAuditId'] as String? ?? '',
    createdAt: data['createdAt'] as DateTime?,
    updatedAt: data['updatedAt'] as DateTime?,
  );

  final String id;
  final String businessId;
  final String newspaperCode;
  final String name;
  final String searchName;
  final String edition;
  final String language;
  final int defaultPricePaise;
  final NewspaperStatus status;
  final String createdBy;
  final String updatedBy;
  final String lastAuditId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isArchived => status == NewspaperStatus.archived;

  String get displayName {
    final suffix = [edition, language].where((value) => value.isNotEmpty);
    return suffix.isEmpty ? name : '$name (${suffix.join(' • ')})';
  }

  NewspaperProfileInput get profileInput =>
      NewspaperProfileInput(name: name, edition: edition, language: language);
}

class NewspaperInput {
  const NewspaperInput({
    required this.name,
    required this.edition,
    required this.language,
    required this.defaultPricePaise,
  });

  final String name;
  final String edition;
  final String language;
  final int defaultPricePaise;

  NewspaperInput normalized() => NewspaperInput(
    name: name.trim(),
    edition: edition.trim(),
    language: language.trim(),
    defaultPricePaise: defaultPricePaise,
  );

  void validate() {
    final value = normalized();
    NewspaperProfileInput(
      name: value.name,
      edition: value.edition,
      language: value.language,
    ).validate();
    NewspaperMoney.validatePrice(value.defaultPricePaise);
  }
}

class NewspaperProfileInput {
  const NewspaperProfileInput({
    required this.name,
    required this.edition,
    required this.language,
  });

  final String name;
  final String edition;
  final String language;

  NewspaperProfileInput normalized() => NewspaperProfileInput(
    name: name.trim(),
    edition: edition.trim(),
    language: language.trim(),
  );

  void validate() {
    final value = normalized();
    if (value.name.length < 2 || value.name.length > 120) {
      throw const AppException(
        'Enter a newspaper name between 2 and 120 characters.',
      );
    }
    if (value.edition.length > 80 || value.language.length > 80) {
      throw const AppException(
        'Edition and language must each be 80 characters or fewer.',
      );
    }
  }
}

abstract final class NewspaperSearchIndex {
  static String normalizeText(String value) =>
      value
          .trim()
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();

  static String tokenFor(NewspaperSearchField field, String term) {
    if (field == NewspaperSearchField.newspaperCode) {
      final code = term.trim().toUpperCase();
      if (code.length < 3) {
        throw const AppException('Enter at least 3 newspaper-code characters.');
      }
      return code;
    }
    final normalized = normalizeText(term);
    if (normalized.length < 2) {
      throw const AppException('Enter at least 2 characters to search.');
    }
    return normalized;
  }
}

abstract final class NewspaperMoney {
  static const maximumPricePaise = 1000000;

  static int parseRupeesToPaise(String value) {
    final normalized = value.trim().replaceAll(',', '');
    if (!RegExp(r'^\d{1,5}(\.\d{1,2})?$').hasMatch(normalized)) {
      throw const AppException(
        'Enter a price in rupees with at most two decimal places.',
      );
    }
    final parts = normalized.split('.');
    final rupees = int.parse(parts.first);
    final paise =
        parts.length == 1 ? 0 : int.parse(parts.last.padRight(2, '0'));
    final result = rupees * 100 + paise;
    validatePrice(result);
    return result;
  }

  static void validatePrice(int pricePaise) {
    if (pricePaise < 0 || pricePaise > maximumPricePaise) {
      throw const AppException('Price must be between ₹0 and ₹10,000.');
    }
  }

  static String formatPaiseForInput(int paise) {
    final rupees = paise ~/ 100;
    final remainder = (paise % 100).toString().padLeft(2, '0');
    return '$rupees.$remainder';
  }
}

class NewspaperPageCursor {
  const NewspaperPageCursor({
    required this.searchName,
    required this.newspaperId,
  });

  final String searchName;
  final String newspaperId;
}

class NewspaperListRequest {
  const NewspaperListRequest({
    required this.businessId,
    required this.requesterId,
    this.status = NewspaperStatus.active,
    this.searchField,
    this.searchTerm = '',
    this.cursor,
    this.pageSize = 25,
  });

  final String businessId;
  final String requesterId;
  final NewspaperStatus status;
  final NewspaperSearchField? searchField;
  final String searchTerm;
  final NewspaperPageCursor? cursor;
  final int pageSize;

  String? get searchToken {
    final field = searchField;
    if (field == null || searchTerm.trim().isEmpty) return null;
    return NewspaperSearchIndex.tokenFor(field, searchTerm);
  }

  bool get isCodeSearch =>
      searchField == NewspaperSearchField.newspaperCode &&
      searchTerm.trim().isNotEmpty;
}

class NewspaperPage {
  const NewspaperPage({
    required this.newspapers,
    required this.nextCursor,
    required this.hasMore,
  });

  final List<Newspaper> newspapers;
  final NewspaperPageCursor? nextCursor;
  final bool hasMore;
}

enum PriceRuleKind {
  exactDate('exactDate', 'Exact date'),
  period('period', 'Effective period');

  const PriceRuleKind(this.value, this.label);

  final String value;
  final String label;

  static PriceRuleKind fromValue(Object? value) =>
      value == period.value ? period : exactDate;
}

enum PriceRuleStatus {
  active('active', 'Active'),
  superseded('superseded', 'Superseded');

  const PriceRuleStatus(this.value, this.label);

  final String value;
  final String label;

  static PriceRuleStatus fromValue(Object? value) =>
      value == superseded.value ? superseded : active;
}

class NewspaperPriceRule {
  const NewspaperPriceRule({
    required this.id,
    required this.businessId,
    required this.newspaperId,
    required this.kind,
    required this.startDate,
    required this.endDate,
    required this.pricePaise,
    required this.status,
    required this.supersedesRuleId,
    required this.supersededByRuleId,
    required this.revision,
    required this.reason,
    required this.createdBy,
    required this.updatedBy,
    required this.lastAuditId,
    this.createdAt,
    this.updatedAt,
  });

  factory NewspaperPriceRule.fromMap(String id, Map<String, Object?> data) =>
      NewspaperPriceRule(
        id: id,
        businessId: data['businessId'] as String? ?? '',
        newspaperId: data['newspaperId'] as String? ?? '',
        kind: PriceRuleKind.fromValue(data['kind']),
        startDate: LocalDate.parse(data['startDate'] as String? ?? ''),
        endDate:
            data['endDate'] is String
                ? LocalDate.parse(data['endDate']! as String)
                : null,
        pricePaise: data['pricePaise'] as int? ?? 0,
        status: PriceRuleStatus.fromValue(data['status']),
        supersedesRuleId: data['supersedesRuleId'] as String? ?? '',
        supersededByRuleId: data['supersededByRuleId'] as String? ?? '',
        revision: data['revision'] as int? ?? 1,
        reason: data['reason'] as String? ?? '',
        createdBy: data['createdBy'] as String? ?? '',
        updatedBy: data['updatedBy'] as String? ?? '',
        lastAuditId: data['lastAuditId'] as String? ?? '',
        createdAt: data['createdAt'] as DateTime?,
        updatedAt: data['updatedAt'] as DateTime?,
      );

  final String id;
  final String businessId;
  final String newspaperId;
  final PriceRuleKind kind;
  final LocalDate startDate;
  final LocalDate? endDate;
  final int pricePaise;
  final PriceRuleStatus status;
  final String supersedesRuleId;
  final String supersededByRuleId;
  final int revision;
  final String reason;
  final String createdBy;
  final String updatedBy;
  final String lastAuditId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isActive => status == PriceRuleStatus.active;
  LocalDate get effectiveEnd => endDate ?? startDate;

  bool appliesOn(LocalDate date) =>
      isActive && !date.isBefore(startDate) && !date.isAfter(effectiveEnd);
}

class PriceRuleInput {
  const PriceRuleInput({
    required this.kind,
    required this.startDate,
    this.endDate,
    required this.pricePaise,
    this.reason = '',
  });

  final PriceRuleKind kind;
  final LocalDate startDate;
  final LocalDate? endDate;
  final int pricePaise;
  final String reason;

  PriceRuleInput normalized() => PriceRuleInput(
    kind: kind,
    startDate: startDate,
    endDate: kind == PriceRuleKind.exactDate ? null : endDate,
    pricePaise: pricePaise,
    reason: reason.trim(),
  );

  LocalDate get effectiveEnd =>
      kind == PriceRuleKind.exactDate ? startDate : (endDate ?? startDate);

  void validate() {
    final value = normalized();
    NewspaperMoney.validatePrice(value.pricePaise);
    if (value.kind == PriceRuleKind.period && value.endDate == null) {
      throw const AppException('Select an end date for the effective period.');
    }
    if (value.effectiveEnd.isBefore(value.startDate)) {
      throw const AppException('Price period end cannot precede its start.');
    }
    if (value.reason.length > 300) {
      throw const AppException(
        'Pricing reason cannot exceed 300 characters.',
      );
    }
  }
}

class PriceRulePageCursor {
  const PriceRulePageCursor({required this.startDate, required this.ruleId});

  final LocalDate startDate;
  final String ruleId;
}

class PriceRuleListRequest {
  const PriceRuleListRequest({
    required this.businessId,
    required this.newspaperId,
    this.cursor,
    this.pageSize = 25,
  });

  final String businessId;
  final String newspaperId;
  final PriceRulePageCursor? cursor;
  final int pageSize;
}

class PriceRulePage {
  const PriceRulePage({
    required this.rules,
    required this.nextCursor,
    required this.hasMore,
  });

  final List<NewspaperPriceRule> rules;
  final PriceRulePageCursor? nextCursor;
  final bool hasMore;
}

enum ResolvedPriceSource { defaultPrice, period, exactDate }

class ResolvedNewspaperPrice {
  const ResolvedNewspaperPrice({
    required this.pricePaise,
    required this.source,
    this.ruleId,
  });

  final int pricePaise;
  final ResolvedPriceSource source;
  final String? ruleId;
}

abstract final class DateSpecificPriceResolver {
  static ResolvedNewspaperPrice resolve({
    required int defaultPricePaise,
    required LocalDate date,
    required Iterable<NewspaperPriceRule> rules,
  }) {
    NewspaperMoney.validatePrice(defaultPricePaise);
    final matching = rules.where((rule) => rule.appliesOn(date)).toList();
    final exact =
        matching.where((rule) => rule.kind == PriceRuleKind.exactDate).toList();
    final periods =
        matching.where((rule) => rule.kind == PriceRuleKind.period).toList();
    if (exact.length > 1 || periods.length > 1) {
      throw const AppException(
        'Overlapping active price rules must be corrected before pricing.',
      );
    }
    if (exact.isNotEmpty) {
      return ResolvedNewspaperPrice(
        pricePaise: exact.single.pricePaise,
        source: ResolvedPriceSource.exactDate,
        ruleId: exact.single.id,
      );
    }
    if (periods.isNotEmpty) {
      return ResolvedNewspaperPrice(
        pricePaise: periods.single.pricePaise,
        source: ResolvedPriceSource.period,
        ruleId: periods.single.id,
      );
    }
    return ResolvedNewspaperPrice(
      pricePaise: defaultPricePaise,
      source: ResolvedPriceSource.defaultPrice,
    );
  }
}

class NewspaperAuditEntry {
  const NewspaperAuditEntry({
    required this.id,
    required this.action,
    required this.actorId,
    required this.createdAt,
    this.changedFields = const [],
    this.priceRuleId = '',
    this.replacedPriceRuleId = '',
  });

  factory NewspaperAuditEntry.fromMap(String id, Map<String, Object?> data) =>
      NewspaperAuditEntry(
        id: id,
        action: data['action'] as String? ?? 'newspaperUpdated',
        actorId: data['actorId'] as String? ?? '',
        createdAt: data['createdAt'] as DateTime?,
        changedFields:
            data['changedFields'] is List
                ? (data['changedFields'] as List).whereType<String>().toList()
                : const [],
        priceRuleId: data['priceRuleId'] as String? ?? '',
        replacedPriceRuleId: data['replacedPriceRuleId'] as String? ?? '',
      );

  final String id;
  final String action;
  final String actorId;
  final DateTime? createdAt;
  final List<String> changedFields;
  final String priceRuleId;
  final String replacedPriceRuleId;
}
