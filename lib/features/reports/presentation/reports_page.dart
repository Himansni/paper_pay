import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:paper_route/core/presentation/async_state_cards.dart';
import 'package:paper_route/features/areas/domain/delivery_area.dart';
import 'package:paper_route/features/areas/presentation/area_providers.dart';
import 'package:paper_route/features/auth/domain/app_user.dart';
import 'package:paper_route/features/billing/domain/monthly_bill.dart';
import 'package:paper_route/features/collections/domain/collection_models.dart';
import 'package:paper_route/features/employees/domain/employee_member.dart';
import 'package:paper_route/features/employees/presentation/employee_providers.dart';
import 'package:paper_route/features/newspapers/domain/newspaper.dart';
import 'package:paper_route/features/newspapers/presentation/newspaper_providers.dart';
import 'package:paper_route/features/reports/domain/report_csv.dart';
import 'package:paper_route/features/reports/domain/report_models.dart';
import 'package:paper_route/features/reports/presentation/csv_downloader.dart';
import 'package:paper_route/features/reports/presentation/reporting_providers.dart';

// BEGINNER NOTE:
// [ReportsPage] provides interactive querying and data export across business
// operations: Collections, Monthly Billing, Outstanding Balances, Customers,
// and Subscriptions. It combines server-side aggregated metrics with cursor-based
// paginated list views and instant CSV file downloads.
class ReportsPage extends ConsumerStatefulWidget {
  const ReportsPage({required this.user, this.initialTab = '', super.key});

  final AppUser user;
  final String initialTab;

  @override
  ConsumerState<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends ConsumerState<ReportsPage> {
  final _rows = <ReportRow>[];
  final _customerController = TextEditingController();
  late final TextEditingController _startController;
  late final TextEditingController _endController;
  late final TextEditingController _monthController;
  late ReportFilter _filter;
  ReportSummary? _summary;
  ReportCursor? _cursor;
  bool _hasMore = true;
  bool _loading = false;
  bool _exporting = false;
  String? _error;
  List<Newspaper> _newspapers = const [];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final month = ReportingPeriod.month(now);
    final kind = ReportKind.values.firstWhere(
      (value) => value.name == widget.initialTab,
      orElse: () => ReportKind.collections,
    );
    final monthKey =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}';
    _filter = ReportFilter(
      kind: kind,
      period: month,
      billingMonth: monthKey,
      customerStatus: 'active',
      billStatus: 'finalized',
    );
    _startController = TextEditingController(text: _date(month.start));
    _endController = TextEditingController(
      text: _date(month.endExclusive.subtract(const Duration(days: 1))),
    );
    _monthController = TextEditingController(text: monthKey);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _load(reset: true);
      _loadNewspapers();
    });
  }

  @override
  void dispose() {
    _customerController.dispose();
    _startController.dispose();
    _endController.dispose();
    _monthController.dispose();
    super.dispose();
  }

  Future<void> _loadNewspapers() async {
    try {
      final page = await ref
          .read(newspaperRepositoryProvider)
          .fetchNewspapers(
            NewspaperListRequest(
              businessId: widget.user.businessId!,
              requesterId: widget.user.uid,
              pageSize: 50,
            ),
          );
      if (mounted) setState(() => _newspapers = page.newspapers);
    } on Object {
      // The report itself has an independent error state. A failed optional
      // picker must not hide report rows that can still load.
    }
  }

  Future<void> _load({bool reset = false}) async {
    if (_loading || (!reset && !_hasMore)) return;
    if (reset) {
      _cursor = null;
      _hasMore = true;
      _rows.clear();
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await ref
          .read(reportingRepositoryProvider)
          .fetchReport(actor: widget.user, filter: _filter, cursor: _cursor);
      if (!mounted) return;
      setState(() {
        _rows.addAll(page.rows);
        _summary = page.summary;
        _cursor = page.nextCursor;
        _hasMore = page.hasMore;
      });
    } on Object catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _applyFilters() async {
    try {
      final start = DateTime.parse(_startController.text.trim());
      final inclusiveEnd = DateTime.parse(_endController.text.trim());
      final month = _monthController.text.trim();
      if (!RegExp(r'^\d{4}-\d{2}$').hasMatch(month)) {
        throw const FormatException('Use YYYY-MM for the billing month.');
      }
      final period = ReportingPeriod(
        start: DateTime(start.year, start.month, start.day).toUtc(),
        endExclusive:
            DateTime(
              inclusiveEnd.year,
              inclusiveEnd.month,
              inclusiveEnd.day + 1,
            ).toUtc(),
      );
      period.validate();
      final customerId = _customerController.text.trim();
      setState(() {
        _filter = _filter.copyWith(
          period: period,
          billingMonth: month,
          customerId: customerId,
          employeeId: customerId.isEmpty ? _filter.employeeId : '',
          areaId: customerId.isEmpty ? _filter.areaId : '',
          newspaperId: customerId.isEmpty ? _filter.newspaperId : '',
        );
      });
      await _load(reset: true);
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  Future<void> _export() async {
    setState(() => _exporting = true);
    try {
      final rows = await ref
          .read(reportingRepositoryProvider)
          .fetchExportRows(actor: widget.user, filter: _filter);
      final filename = ReportCsv.safeFilename(_filter, DateTime.now());
      final content = ReportCsv.build(
        kind: _filter.kind,
        filter: _filter,
        rows: rows,
      );
      final message = await saveCsv(filename, content);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final businessId = widget.user.businessId!;
    final areas = ref.watch(deliveryAreasProvider(businessId));
    final members = ref.watch(employeeMembersProvider(businessId));
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.go('/')),
        title: const Text('Reports'),
        actions: [
          IconButton(
            key: const ValueKey('export-report-csv'),
            onPressed: _loading || _exporting ? null : _export,
            tooltip: 'Export filtered CSV',
            icon:
                _exporting
                    ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : const Icon(Icons.download_outlined),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: () => _load(reset: true),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
            children: [
              Text(
                'Business reports',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 5),
              const Text(
                'Server-side totals and paginated records respect the selected filters. CSV exports use the same query scope.',
                style: TextStyle(color: Color(0xFF486581), height: 1.4),
              ),
              const SizedBox(height: 16),
              _ReportKindSelector(
                value: _filter.kind,
                onChanged: (kind) {
                  setState(() => _filter = _filter.copyWith(kind: kind));
                  _load(reset: true);
                },
              ),
              const SizedBox(height: 12),
              _FiltersCard(
                filter: _filter,
                startController: _startController,
                endController: _endController,
                monthController: _monthController,
                customerController: _customerController,
                areas: areas.asData?.value ?? const [],
                members: members.asData?.value ?? const [],
                newspapers: _newspapers,
                onChanged: (filter) => setState(() => _filter = filter),
                onApply: _applyFilters,
                loading: _loading,
              ),
              const SizedBox(height: 16),
              if (_summary != null)
                _SummaryPanel(kind: _filter.kind, summary: _summary!),
              const SizedBox(height: 16),
              if (_rows.isEmpty && _loading)
                const Padding(
                  padding: EdgeInsets.all(36),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_rows.isEmpty && _error != null)
                AsyncErrorCard(
                  message: _error!,
                  onRetry: () => _load(reset: true),
                )
              else if (_rows.isEmpty)
                const EmptyStateCard(
                  icon: Icons.query_stats_outlined,
                  title: 'No matching report rows',
                  message: 'Adjust the date, month, or operational filters.',
                )
              else ...[
                for (final row in _rows) ...[
                  _ReportRowCard(row: row),
                  const SizedBox(height: 10),
                ],
                if (_error != null)
                  AsyncErrorCard(message: _error!, onRetry: _load),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_hasMore)
                  Center(
                    child: OutlinedButton.icon(
                      onPressed: _load,
                      icon: const Icon(Icons.expand_more),
                      label: const Text('Load more results'),
                    ),
                  )
                else
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: Text(
                        'End of filtered results',
                        style: TextStyle(color: Color(0xFF829AB1)),
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static String _date(DateTime date) =>
      DateFormat('yyyy-MM-dd').format(date.toLocal());
}

// BEGINNER NOTE:
// Segmented selector that switches the operational domain of the report.
// Switching kind triggers a complete query reload with cursor reset.
class _ReportKindSelector extends StatelessWidget {
  const _ReportKindSelector({required this.value, required this.onChanged});

  final ReportKind value;
  final ValueChanged<ReportKind> onChanged;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: SegmentedButton<ReportKind>(
      segments: [
        for (final kind in ReportKind.values)
          ButtonSegment(value: kind, label: Text(kind.label)),
      ],
      selected: {value},
      onSelectionChanged: (selection) => onChanged(selection.single),
    ),
  );
}

// BEGINNER NOTE:
// Dynamic filter card providing date pickers, billing month selectors, employee
// assignments, delivery areas, and status drop-downs relevant to the chosen report kind.
// Note that filtering by Customer ID takes precedence and clears other entity dimensions
// to avoid conflicting multi-property index requirements.
class _FiltersCard extends StatelessWidget {
  const _FiltersCard({
    required this.filter,
    required this.startController,
    required this.endController,
    required this.monthController,
    required this.customerController,
    required this.areas,
    required this.members,
    required this.newspapers,
    required this.onChanged,
    required this.onApply,
    required this.loading,
  });

  final ReportFilter filter;
  final TextEditingController startController;
  final TextEditingController endController;
  final TextEditingController monthController;
  final TextEditingController customerController;
  final List<DeliveryArea> areas;
  final List<EmployeeMember> members;
  final List<Newspaper> newspapers;
  final ValueChanged<ReportFilter> onChanged;
  final VoidCallback onApply;
  final bool loading;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width =
              constraints.maxWidth >= 760
                  ? (constraints.maxWidth - 24) / 3
                  : constraints.maxWidth;
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (filter.kind == ReportKind.collections ||
                  filter.kind == ReportKind.customers)
                SizedBox(
                  width: width,
                  child: TextField(
                    controller: startController,
                    decoration: const InputDecoration(
                      labelText: 'From date',
                      hintText: 'YYYY-MM-DD',
                    ),
                  ),
                ),
              if (filter.kind == ReportKind.collections ||
                  filter.kind == ReportKind.customers)
                SizedBox(
                  width: width,
                  child: TextField(
                    controller: endController,
                    decoration: const InputDecoration(
                      labelText: 'Through date',
                      hintText: 'YYYY-MM-DD',
                    ),
                  ),
                ),
              if (filter.kind != ReportKind.customers)
                SizedBox(
                  width: width,
                  child: TextField(
                    controller: monthController,
                    decoration: const InputDecoration(
                      labelText: 'Billing month',
                      hintText: 'YYYY-MM',
                    ),
                  ),
                ),
              if (filter.kind != ReportKind.subscriptions)
                SizedBox(
                  width: width,
                  child: DropdownButtonFormField<String>(
                    value: filter.employeeId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Employee'),
                    items: [
                      const DropdownMenuItem(
                        value: '',
                        child: Text('All employees'),
                      ),
                      for (final member in members.where(
                        (item) => item.isEmployee,
                      ))
                        DropdownMenuItem(
                          value: member.uid,
                          child: Text(
                            member.displayName.isEmpty
                                ? member.email
                                : member.displayName,
                          ),
                        ),
                    ],
                    onChanged: (value) {
                      customerController.clear();
                      onChanged(
                        filter.copyWith(
                          employeeId: value ?? '',
                          areaId: '',
                          customerId: '',
                        ),
                      );
                    },
                  ),
                ),
              if (filter.kind != ReportKind.subscriptions)
                SizedBox(
                  width: width,
                  child: DropdownButtonFormField<String>(
                    value: filter.areaId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Area'),
                    items: [
                      const DropdownMenuItem(
                        value: '',
                        child: Text('All areas'),
                      ),
                      for (final area in areas)
                        DropdownMenuItem(
                          value: area.id,
                          child: Text(area.name),
                        ),
                    ],
                    onChanged: (value) {
                      customerController.clear();
                      onChanged(
                        filter.copyWith(
                          areaId: value ?? '',
                          employeeId: '',
                          customerId: '',
                        ),
                      );
                    },
                  ),
                ),
              if (filter.kind == ReportKind.subscriptions)
                SizedBox(
                  width: width,
                  child: DropdownButtonFormField<String>(
                    value: filter.newspaperId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Newspaper'),
                    items: [
                      const DropdownMenuItem(
                        value: '',
                        child: Text('All newspapers'),
                      ),
                      for (final paper in newspapers)
                        DropdownMenuItem(
                          value: paper.id,
                          child: Text(paper.displayName),
                        ),
                    ],
                    onChanged: (value) {
                      customerController.clear();
                      onChanged(
                        filter.copyWith(
                          newspaperId: value ?? '',
                          customerId: '',
                        ),
                      );
                    },
                  ),
                ),
              if (filter.kind == ReportKind.collections)
                SizedBox(
                  width: width,
                  child: DropdownButtonFormField<String>(
                    value: filter.paymentMethod?.value ?? '',
                    decoration: const InputDecoration(
                      labelText: 'Payment method',
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: '',
                        child: Text('All methods'),
                      ),
                      for (final method in PaymentMethod.values)
                        DropdownMenuItem(
                          value: method.value,
                          child: Text(method.label),
                        ),
                    ],
                    onChanged: (value) {
                      final method =
                          PaymentMethod.values
                              .where((item) => item.value == value)
                              .firstOrNull;
                      onChanged(
                        method == null
                            ? filter.copyWith(clearPaymentMethod: true)
                            : filter.copyWith(paymentMethod: method),
                      );
                    },
                  ),
                ),
              if (filter.kind == ReportKind.customers ||
                  filter.kind == ReportKind.outstanding)
                SizedBox(
                  width: width,
                  child: DropdownButtonFormField<String>(
                    value: filter.customerStatus,
                    decoration: const InputDecoration(
                      labelText: 'Customer status',
                    ),
                    items: const [
                      DropdownMenuItem(value: 'active', child: Text('Active')),
                      DropdownMenuItem(
                        value: 'archived',
                        child: Text('Archived'),
                      ),
                    ],
                    onChanged:
                        (value) => onChanged(
                          filter.copyWith(customerStatus: value ?? ''),
                        ),
                  ),
                ),
              if (filter.kind == ReportKind.outstanding)
                SizedBox(
                  width: width,
                  child: DropdownButtonFormField<String>(
                    value: filter.outstandingStatus?.value ?? '',
                    decoration: const InputDecoration(
                      labelText: 'Payment status',
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: '',
                        child: Text('All balances'),
                      ),
                      for (final status in OutstandingStatus.values)
                        DropdownMenuItem(
                          value: status.value,
                          child: Text(status.label),
                        ),
                    ],
                    onChanged: (value) {
                      final status =
                          OutstandingStatus.values
                              .where((item) => item.value == value)
                              .firstOrNull;
                      onChanged(
                        status == null
                            ? filter.copyWith(clearOutstandingStatus: true)
                            : filter.copyWith(outstandingStatus: status),
                      );
                    },
                  ),
                ),
              if (filter.kind == ReportKind.subscriptions)
                SizedBox(
                  width: width,
                  child: DropdownButtonFormField<String>(
                    value: filter.subscriptionStatus,
                    decoration: const InputDecoration(
                      labelText: 'Subscription status',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: '',
                        child: Text('All subscriptions'),
                      ),
                      DropdownMenuItem(value: 'active', child: Text('Active')),
                      DropdownMenuItem(value: 'paused', child: Text('Paused')),
                      DropdownMenuItem(value: 'ended', child: Text('Ended')),
                    ],
                    onChanged:
                        (value) => onChanged(
                          filter.copyWith(subscriptionStatus: value ?? ''),
                        ),
                  ),
                ),
              SizedBox(
                width: width,
                child: TextField(
                  controller: customerController,
                  decoration: const InputDecoration(
                    labelText: 'Customer ID (optional)',
                  ),
                ),
              ),
              SizedBox(
                width: width,
                child: const Text(
                  'Choose one customer, employee, area, or newspaper scope. Customer ID takes precedence when applied.',
                  style: TextStyle(color: Color(0xFF829AB1), fontSize: 12),
                ),
              ),
              SizedBox(
                width: width,
                child: FilledButton.icon(
                  key: const ValueKey('apply-report-filters'),
                  onPressed: loading ? null : onApply,
                  icon: const Icon(Icons.filter_alt_outlined),
                  label: const Text('Apply filters'),
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}

// BEGINNER NOTE:
// Displays top-level summary metrics (aggregate totals and status breakdowns)
// computed directly on the backend database or aggregated from filtered rows.
class _SummaryPanel extends StatelessWidget {
  const _SummaryPanel({required this.kind, required this.summary});

  final ReportKind kind;
  final ReportSummary summary;

  @override
  Widget build(BuildContext context) {
    final values = switch (kind) {
      ReportKind.collections => {
        'Confirmed': BillingMoney.formatPaise(summary.totalPaise),
        'Reversed': BillingMoney.formatPaise(summary.secondaryPaise),
        'Net': BillingMoney.formatPaise(summary.netPaise),
        'Payments': '${summary.totalCount}',
      },
      ReportKind.billing => {
        'Current charges': BillingMoney.formatPaise(summary.totalPaise),
        'Statement totals': BillingMoney.formatPaise(summary.secondaryPaise),
        'Finalized': '${summary.totalCount}',
        'Not finalized': '${summary.secondaryCount}',
      },
      ReportKind.outstanding => {
        'Outstanding': BillingMoney.formatPaise(summary.totalPaise),
        'Customer accounts': '${summary.totalCount}',
      },
      ReportKind.customers => {
        'Matching customers': '${summary.totalCount}',
        'New in period': '${summary.secondaryCount}',
      },
      ReportKind.subscriptions => {
        'Matching subscriptions': '${summary.totalCount}',
      },
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final value in values.entries)
                  Chip(
                    label: Text('${value.key}: ${value.value}'),
                    side: BorderSide.none,
                  ),
              ],
            ),
            if (summary.breakdown.isNotEmpty) ...[
              const Divider(height: 24),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final value in summary.breakdown.entries)
                    Chip(
                      label: Text(
                        value.key.contains('₹') ||
                                value.key.startsWith('Billing ·')
                            ? '${value.key}: ${BillingMoney.formatPaise(value.value)}'
                            : '${value.key}: ${value.value}',
                      ),
                      backgroundColor: const Color(0xFFF0F4F2),
                      side: BorderSide.none,
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// BEGINNER NOTE:
// Renders an individual report result row card with title, metadata fields, amount,
// and navigation action (e.g. clicking a customer or bill opens the entity page).
class _ReportRowCard extends StatelessWidget {
  const _ReportRowCard({required this.row});

  final ReportRow row;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      onTap: row.route.isEmpty ? null : () => context.go(row.route),
      contentPadding: const EdgeInsets.fromLTRB(18, 8, 12, 8),
      title: Text(
        row.title,
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (row.subtitle.isNotEmpty) Text(row.subtitle),
          if (row.fields.isNotEmpty)
            Text(
              row.fields.entries
                  .where((entry) => entry.value.isNotEmpty)
                  .map((entry) => '${entry.key}: ${entry.value}')
                  .join(' · '),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (row.amountPaise != null)
            Text(
              BillingMoney.formatPaise(row.amountPaise!),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          Text(row.status, style: const TextStyle(fontSize: 12)),
        ],
      ),
    ),
  );
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
