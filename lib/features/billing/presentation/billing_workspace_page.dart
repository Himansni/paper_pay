import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:paper_route/core/domain/local_date.dart';
import 'package:paper_route/core/presentation/async_state_cards.dart';
import 'package:paper_route/features/auth/domain/app_user.dart';
import 'package:paper_route/features/billing/domain/monthly_bill.dart';
import 'package:paper_route/features/billing/presentation/billing_providers.dart';
import 'package:paper_route/l10n/app_localizations.dart';

class BillingWorkspacePage extends ConsumerStatefulWidget {
  const BillingWorkspacePage({required this.user, super.key});

  final AppUser user;

  @override
  ConsumerState<BillingWorkspacePage> createState() =>
      _BillingWorkspacePageState();
}

class _BillingWorkspacePageState extends ConsumerState<BillingWorkspacePage> {
  final _rows = <BillingWorkspaceRow>[];
  late LocalDate _month;
  BillingWorkspaceCursor? _cursor;
  bool _hasMore = false;
  bool _loading = false;
  String? _error;
  int _requestVersion = 0;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = LocalDate(now.year, now.month, 1);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load(reset: true));
  }

  Future<void> _load({required bool reset}) async {
    if (_loading && !reset) return;
    final version = ++_requestVersion;
    if (reset) _cursor = null;
    setState(() {
      _loading = true;
      _error = null;
      if (reset) _rows.clear();
    });
    try {
      final page = await ref
          .read(billingRepositoryProvider)
          .fetchWorkspace(
            actor: widget.user,
            month: _month,
            cursor: reset ? null : _cursor,
          );
      if (!mounted || version != _requestVersion) return;
      setState(() {
        _rows.addAll(page.rows);
        _cursor = page.nextCursor;
        _hasMore = page.hasMore;
        _loading = false;
      });
    } on Object catch (error) {
      if (!mounted || version != _requestVersion) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _selectMonth() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _month.toDateTime(),
      firstDate: DateTime.utc(2020),
      lastDate: DateTime.utc(2100, 12, 31),
      helpText: 'Select any date in the billing month',
    );
    if (selected == null || !mounted) return;
    setState(() => _month = LocalDate(selected.year, selected.month, 1));
    await _load(reset: true);
  }

  Future<void> _open(BillingWorkspaceRow row) async {
    final month = billingMonthKey(_month);
    final location =
        row.finalizedBill == null && widget.user.isHead
            ? '/billing/${row.customerId}/$month/preview'
            : '/billing/${row.customerId}/$month';
    if (row.finalizedBill == null && !widget.user.isHead) return;
    await context.push<void>(location);
    if (mounted) await _load(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final monthLabel = DateFormat.yMMMM().format(_month.toDateTime());
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.go('/')),
        title: Text(l10n?.billingTitle ?? 'Monthly billing'),
      ),
      body: RefreshIndicator(
        onRefresh: () => _load(reset: true),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Text(
              widget.user.isHead
                  ? (l10n?.billingWorkspace ?? 'Billing workspace')
                  : (l10n?.assignedBills ?? 'Assigned bills'),
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              widget.user.isHead
                  ? (l10n?.billingWorkspaceSubtitle ??
                      'Review deterministic daily charges before finalization. Previews never write data.')
                  : (l10n?.assignedBillsSubtitle ??
                      'You can read finalized bills only for customers currently assigned to you.'),
              style: const TextStyle(color: Color(0xFF486581), height: 1.4),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              key: const ValueKey('billing-month-selector'),
              onPressed: _selectMonth,
              icon: const Icon(Icons.calendar_month_outlined),
              label: Text(monthLabel),
            ),
            const SizedBox(height: 16),
            if (_error != null)
              AsyncErrorCard(
                message: _error!,
                onRetry: () => _load(reset: true),
              )
            else if (_rows.isEmpty && _loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_rows.isEmpty)
              EmptyStateCard(
                icon: Icons.receipt_long_outlined,
                title: l10n?.noActiveCustomers ?? 'No active customers',
                message:
                    l10n?.noActiveCustomersDesc ??
                    'There are no accessible active customers to bill.',
              )
            else ...[
              for (final row in _rows)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Card(
                    child: ListTile(
                      onTap: () => _open(row),
                      leading: Icon(
                        row.finalizedBill == null
                            ? Icons.pending_actions_outlined
                            : Icons.verified_outlined,
                      ),
                      title: Text(row.customerName),
                      subtitle: Text(
                        '${row.customerCode} • Area ${row.areaId}\n'
                        '${row.finalizedBill == null ? 'Not finalized' : 'Finalized • ${_money(row.finalizedBill!.totalDuePaise)}'}',
                      ),
                      isThreeLine: true,
                      trailing:
                          row.finalizedBill == null && !widget.user.isHead
                              ? const Tooltip(
                                message:
                                    'Only the Head can preview or finalize',
                                child: Icon(Icons.lock_outline),
                              )
                              : const Icon(Icons.chevron_right),
                    ),
                  ),
                ),
              if (_hasMore)
                OutlinedButton(
                  onPressed: _loading ? null : () => _load(reset: false),
                  child:
                      _loading
                          ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : Text(l10n?.loadMoreCustomers ?? 'Load more customers'),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

String _money(int paise) => BillingMoney.formatPaise(paise);
