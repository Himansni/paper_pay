import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:paper_route/core/domain/local_date.dart';
import 'package:paper_route/core/presentation/async_state_cards.dart';
import 'package:paper_route/features/auth/domain/app_user.dart';
import 'package:paper_route/features/billing/domain/monthly_bill.dart';
import 'package:paper_route/features/billing/presentation/billing_providers.dart';
import 'package:paper_route/features/newspapers/domain/newspaper.dart';
import 'package:paper_route/features/newspapers/presentation/newspaper_providers.dart';
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

  // Gate 3 V1 Batch Billing Filter States
  String? _selectedPublicationId;
  String? _selectedEmployeeId;
  String? _selectedCustomerId;
  final Set<String> _selectedCustomerIds = {};

  // Billing Price Resolution state: newspaperId -> { pricePaise, basis, isBillingOnly, isGlobalPrice }
  final Map<String, _BillingPriceSetting> _priceSettings = {};

  bool _isBatchRunning = false;
  int _batchCompleted = 0;
  int _batchTotal = 0;
  String _batchCurrentCustomer = '';

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
      if (reset) {
        _rows.clear();
        _selectedCustomerIds.clear();
      }
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

  List<BillingWorkspaceRow> _getFilteredRows() {
    return _rows.where((row) {
      if (_selectedEmployeeId != null && _selectedEmployeeId!.isNotEmpty) {
        if (row.assignedEmployeeId != _selectedEmployeeId) return false;
      }
      if (_selectedPublicationId != null &&
          _selectedPublicationId!.isNotEmpty) {
        if (!row.publicationIds.contains(_selectedPublicationId)) {
          return false;
        }
      }
      if (_selectedCustomerId != null && _selectedCustomerId!.isNotEmpty) {
        if (row.customerId != _selectedCustomerId) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  List<String> _getDistinctEmployeeIds() {
    final ids = <String>{};
    for (final row in _rows) {
      if (row.assignedEmployeeId.isNotEmpty) {
        ids.add(row.assignedEmployeeId);
      }
    }
    final list = ids.toList()..sort();
    return list;
  }

  List<({String id, String name, String code})> _getDistinctCustomers() {
    final seen = <String>{};
    final list = <({String id, String name, String code})>[];
    for (final row in _rows) {
      if (seen.add(row.customerId)) {
        list.add((
          id: row.customerId,
          name: row.customerName,
          code: row.customerCode,
        ),);
      }
    }
    list.sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  _BillingPriceSetting? _getActivePriceSetting(
    List<Newspaper> publications,
    List<BillingMonthlyPrice> monthlyPrices,
  ) {
    final pubId =
        _selectedPublicationId ??
        (publications.isNotEmpty ? publications.first.id : null);
    if (pubId == null) return null;

    final matchingMonthly = monthlyPrices
        .where((p) => p.newspaperId == pubId)
        .firstOrNull;
    if (matchingMonthly != null) {
      return _BillingPriceSetting(
        newspaperId: pubId,
        pricePaise: matchingMonthly.pricePaise,
        basis: matchingMonthly.pricingBasis,
        isBillingOnly: true,
        isGlobalPrice: false,
      );
    }

    return _priceSettings[pubId];
  }

  Future<void> _showSetBillingPriceModal(
    List<Newspaper> publications,
    List<BillingMonthlyPrice> monthlyPrices,
  ) async {
    if (publications.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No active publication found to set pricing.'),
        ),
      );
      return;
    }

    String selectedPubId = _selectedPublicationId ?? publications.first.id;
    final activeSetting = _getActivePriceSetting(publications, monthlyPrices);

    final priceController = TextEditingController(
      text:
          activeSetting != null
              ? NewspaperMoney.formatPaiseForInput(activeSetting.pricePaise)
              : '250.00',
    );
    PricingBasis selectedBasis = activeSetting?.basis ?? PricingBasis.monthly;
    bool useForThisBillingOnly = activeSetting?.isBillingOnly ?? true;
    bool saveAsGlobalPrice = activeSetting?.isGlobalPrice ?? false;

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: const Text('Set Billing Price'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Select Publication:'),
                    const SizedBox(height: 4),
                    DropdownButtonFormField<String>(
                      key: const ValueKey('modal-publication-dropdown'),
                      value: selectedPubId,
                      items: [
                        for (final pub in publications)
                          DropdownMenuItem(
                            value: pub.id,
                            child: Text(pub.name),
                          ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setModalState(() => selectedPubId = val);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      key: const ValueKey('price-input'),
                      controller: priceController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Price (in ₹)',
                        hintText: 'e.g. 250.00',
                        prefixText: '₹ ',
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('Pricing Basis:'),
                    Row(
                      children: [
                        Radio<PricingBasis>(
                          value: PricingBasis.monthly,
                          groupValue: selectedBasis,
                          onChanged: (val) {
                            if (val != null) {
                              setModalState(() => selectedBasis = val);
                            }
                          },
                        ),
                        const Text('Monthly'),
                        const SizedBox(width: 16),
                        Radio<PricingBasis>(
                          value: PricingBasis.daily,
                          groupValue: selectedBasis,
                          onChanged: (val) {
                            if (val != null) {
                              setModalState(() => selectedBasis = val);
                            }
                          },
                        ),
                        const Text('Daily'),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(),
                    CheckboxListTile(
                      key: const ValueKey('use-for-this-billing-only-checkbox'),
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Use for this billing only'),
                      subtitle: const Text(
                        'Stores a billing-specific price snapshot without mutating reusable global rules.',
                        style: TextStyle(fontSize: 12),
                      ),
                      value: useForThisBillingOnly,
                      onChanged: (val) {
                        setModalState(() {
                          useForThisBillingOnly = val ?? false;
                          if (useForThisBillingOnly) saveAsGlobalPrice = false;
                        });
                      },
                    ),
                    CheckboxListTile(
                      key: const ValueKey('save-as-global-price-checkbox'),
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Save as Global Price'),
                      subtitle: const Text(
                        'Updates canonical reusable global price rules.',
                        style: TextStyle(fontSize: 12),
                      ),
                      value: saveAsGlobalPrice,
                      onChanged: (val) {
                        setModalState(() {
                          saveAsGlobalPrice = val ?? false;
                          if (saveAsGlobalPrice) useForThisBillingOnly = false;
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  key: const ValueKey('save-price-btn'),
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    final navigator = Navigator.of(dialogCtx);
                    try {
                      final paise = NewspaperMoney.parseRupeesToPaise(
                        priceController.text,
                      );
                      if (saveAsGlobalPrice) {
                        final repo = ref.read(newspaperRepositoryProvider);
                        await repo.createPriceRule(
                          actor: widget.user,
                          newspaperId: selectedPubId,
                          input: PriceRuleInput(
                            kind: PriceRuleKind.period,
                            startDate: _month,
                            pricePaise: paise,
                            pricingBasis: selectedBasis,
                            reason:
                                'V1 Monthly Billing acceptance global price',
                          ),
                        );
                      }
                      if (useForThisBillingOnly) {
                        final billingRepo = ref.read(billingRepositoryProvider);
                        final monthKey = billingMonthKey(_month);
                        final pubName = publications
                                .where((p) => p.id == selectedPubId)
                                .firstOrNull
                                ?.name ??
                            'Publication';
                        await billingRepo.saveBillingMonthlyPrice(
                          actor: widget.user,
                          billingMonth: monthKey,
                          newspaperId: selectedPubId,
                          newspaperName: pubName,
                          pricePaise: paise,
                          pricingBasis: selectedBasis,
                        );
                      }
                      _priceSettings[selectedPubId] = _BillingPriceSetting(
                        newspaperId: selectedPubId,
                        pricePaise: paise,
                        basis: selectedBasis,
                        isBillingOnly: useForThisBillingOnly,
                        isGlobalPrice: saveAsGlobalPrice,
                      );
                      navigator.pop(true);
                    } catch (e) {
                      messenger.showSnackBar(
                        SnackBar(content: Text(e.toString())),
                      );
                    }
                  },
                  child: const Text('Save Price'),
                ),
              ],
            );
          },
        );
      },
    );

    if (saved == true && mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Billing price updated successfully.')),
      );
    }
  }

  Future<void> _runBatchBilling(List<BillingWorkspaceRow> targetRows) async {
    final readyRows = targetRows.where((r) => r.finalizedBill == null).toList();
    if (readyRows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No ready-to-bill customers selected.')),
      );
      return;
    }

    setState(() {
      _isBatchRunning = true;
      _batchTotal = readyRows.length;
      _batchCompleted = 0;
      _batchCurrentCustomer = readyRows.first.customerName;
    });

    final repo = ref.read(billingRepositoryProvider);
    final monthKey = billingMonthKey(_month);
    var successCount = 0;
    var failedCount = 0;

    for (var i = 0; i < readyRows.length; i++) {
      final row = readyRows[i];
      if (!mounted) break;
      setState(() {
        _batchCompleted = i;
        _batchCurrentCustomer = row.customerName;
      });
      try {
        await repo.finalizeBill(
          actor: widget.user,
          customerId: row.customerId,
          month: _month,
        );
        successCount++;
      } catch (e) {
        failedCount++;
        try {
          await repo.recordBillingFailure(
            actor: widget.user,
            customerId: row.customerId,
            billingMonth: monthKey,
            error: e.toString(),
          );
        } catch (_) {}
      }
    }

    if (mounted) {
      setState(() {
        _isBatchRunning = false;
        _batchCompleted = _batchTotal;
        _batchCurrentCustomer = 'Done';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Batch complete: $successCount succeeded${failedCount > 0 ? ', $failedCount failed' : ''} of $_batchTotal bills.',
          ),
          backgroundColor: failedCount > 0 ? Colors.orange.shade800 : null,
        ),
      );
      await _load(reset: true);
    }
  }

  Future<void> _retryRow(BillingWorkspaceRow row) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _loading = true);
    final repo = ref.read(billingRepositoryProvider);
    final monthKey = billingMonthKey(_month);
    try {
      await repo.finalizeBill(
        actor: widget.user,
        customerId: row.customerId,
        month: _month,
      );
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'Successfully finalized bill for ${row.customerName}.',
            ),
          ),
        );
        await _load(reset: true);
      }
    } catch (e) {
      if (mounted) {
        try {
          await repo.recordBillingFailure(
            actor: widget.user,
            customerId: row.customerId,
            billingMonth: monthKey,
            error: e.toString(),
          );
        } catch (_) {}
        messenger.showSnackBar(
          SnackBar(
            content: Text('Retry failed for ${row.customerName}: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
        await _load(reset: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final monthLabel = DateFormat.yMMMM().format(_month.toDateTime());

    final businessId = widget.user.businessId ?? '';
    final newspapersAsync = ref.watch(
      activeNewspapersListProvider(
        (
          businessId: businessId,
          requesterId: widget.user.uid,
        ),
      ),
    );

    final monthlyPricesAsync = ref.watch(
      monthlyBillingPricesProvider(
        (
          businessId: businessId,
          billingMonth: billingMonthKey(_month),
        ),
      ),
    );

    final publications = newspapersAsync.value ?? const [];
    final monthlyPrices = monthlyPricesAsync.value ?? const [];
    final filteredRows = _getFilteredRows();
    final employees = _getDistinctEmployeeIds();
    final customers = _getDistinctCustomers();

    final totalEligible = filteredRows.length;
    final finalizedCount =
        filteredRows.where((r) => r.finalizedBill != null).length;
    final readyToBillCount =
        filteredRows.where((r) => r.finalizedBill == null).length;
    final failedCount =
        filteredRows.where((r) => r.hasFailed && r.finalizedBill == null).length;
    final selectedCount = _selectedCustomerIds.length;

    final activePriceSetting = _getActivePriceSetting(
      publications,
      monthlyPrices,
    );

    final mediaWidth = MediaQuery.of(context).size.width;
    final isMobile = mediaWidth < 600;

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.go('/')),
        title: Text(l10n?.billingTitle ?? 'Monthly billing'),
      ),
      body: RefreshIndicator(
        onRefresh: () => _load(reset: true),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            isMobile ? 16 : 20,
            12,
            isMobile ? 16 : 20,
            32,
          ),
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

            // Top Control Bar: Month Picker & Dropdowns
            if (isMobile)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  OutlinedButton.icon(
                    key: const ValueKey('billing-month-selector'),
                    onPressed: _selectMonth,
                    icon: const Icon(Icons.calendar_month_outlined),
                    label: Text(monthLabel),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String?>(
                    key: const ValueKey('publication-filter'),
                    isExpanded: true,
                    value: _selectedPublicationId,
                    decoration: const InputDecoration(
                      labelText: 'Publication',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('All Publications'),
                      ),
                      for (final pub in publications)
                        DropdownMenuItem<String?>(
                          value: pub.id,
                          child: Text(
                            pub.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (val) {
                      setState(() => _selectedPublicationId = val);
                    },
                  ),
                  if (employees.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String?>(
                      key: const ValueKey('employee-filter'),
                      isExpanded: true,
                      value: _selectedEmployeeId,
                      decoration: const InputDecoration(
                        labelText: 'Assigned Employee',
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('All Employees'),
                        ),
                        for (final empId in employees)
                          DropdownMenuItem<String?>(
                            value: empId,
                            child: Text(
                              'Employee: $empId',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (val) {
                        setState(() => _selectedEmployeeId = val);
                      },
                    ),
                  ],
                  if (customers.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String?>(
                      key: const ValueKey('customer-filter'),
                      isExpanded: true,
                      value: _selectedCustomerId,
                      decoration: const InputDecoration(
                        labelText: 'Customer',
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('All Customers'),
                        ),
                        for (final cust in customers)
                          DropdownMenuItem<String?>(
                            value: cust.id,
                            child: Text(
                              '${cust.name} (${cust.code})',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (val) {
                        setState(() => _selectedCustomerId = val);
                      },
                    ),
                  ],
                ],
              )
            else
              Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  OutlinedButton.icon(
                    key: const ValueKey('billing-month-selector'),
                    onPressed: _selectMonth,
                    icon: const Icon(Icons.calendar_month_outlined),
                    label: Text(monthLabel),
                  ),

                  SizedBox(
                    width: 220,
                    child: DropdownButtonFormField<String?>(
                      key: const ValueKey('publication-filter'),
                      isExpanded: true,
                      value: _selectedPublicationId,
                      decoration: const InputDecoration(
                        labelText: 'Publication',
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('All Publications'),
                        ),
                        for (final pub in publications)
                          DropdownMenuItem<String?>(
                            value: pub.id,
                            child: Text(
                              pub.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (val) {
                        setState(() => _selectedPublicationId = val);
                      },
                    ),
                  ),

                  if (employees.isNotEmpty)
                    SizedBox(
                      width: 200,
                      child: DropdownButtonFormField<String?>(
                        key: const ValueKey('employee-filter'),
                        isExpanded: true,
                        value: _selectedEmployeeId,
                        decoration: const InputDecoration(
                          labelText: 'Assigned Employee',
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('All Employees'),
                          ),
                          for (final empId in employees)
                            DropdownMenuItem<String?>(
                              value: empId,
                              child: Text(
                                'Employee: $empId',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: (val) {
                          setState(() => _selectedEmployeeId = val);
                        },
                      ),
                    ),

                  if (customers.isNotEmpty)
                    SizedBox(
                      width: 220,
                      child: DropdownButtonFormField<String?>(
                        key: const ValueKey('customer-filter'),
                        isExpanded: true,
                        value: _selectedCustomerId,
                        decoration: const InputDecoration(
                          labelText: 'Customer',
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('All Customers'),
                          ),
                          for (final cust in customers)
                            DropdownMenuItem<String?>(
                              value: cust.id,
                              child: Text(
                                '${cust.name} (${cust.code})',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: (val) {
                          setState(() => _selectedCustomerId = val);
                        },
                      ),
                    ),
                ],
              ),
            const SizedBox(height: 16),

            // Price Resolution Banner
            if (widget.user.isHead)
              Card(
                color:
                    activePriceSetting != null
                        ? const Color(0xFFEBF8FF)
                        : const Color(0xFFFFF5F5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(
                    color:
                        activePriceSetting != null
                            ? const Color(0xFF3182CE)
                            : const Color(0xFFE53E3E),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child:
                      isMobile
                          ? Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    activePriceSetting != null
                                        ? Icons.sell_outlined
                                        : Icons.warning_amber_rounded,
                                    color:
                                        activePriceSetting != null
                                            ? const Color(0xFF2B6CB0)
                                            : const Color(0xFFC53030),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          activePriceSetting != null
                                              ? 'Billing Price ${_money(activePriceSetting.pricePaise)}/${activePriceSetting.basis == PricingBasis.monthly ? 'month' : 'day'}'
                                              : 'No billing price set',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                            color:
                                                activePriceSetting != null
                                                    ? const Color(0xFF2B6CB0)
                                                    : const Color(0xFFC53030),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          activePriceSetting != null
                                              ? (activePriceSetting
                                                      .isBillingOnly
                                                  ? 'Use for this billing only'
                                                  : 'Global Price')
                                              : 'Configure billing price before batch finalization.',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF4A5568),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              ElevatedButton.icon(
                                key: const ValueKey('set-billing-price-btn'),
                                onPressed:
                                    () => _showSetBillingPriceModal(
                                      publications,
                                      monthlyPrices,
                                    ),
                                icon: const Icon(Icons.edit_note, size: 18),
                                label: Text(
                                  activePriceSetting != null
                                      ? 'Change Price'
                                      : 'Set Billing Price',
                                ),
                              ),
                            ],
                          )
                          : Row(
                            children: [
                              Icon(
                                activePriceSetting != null
                                    ? Icons.sell_outlined
                                    : Icons.warning_amber_rounded,
                                color:
                                    activePriceSetting != null
                                        ? const Color(0xFF2B6CB0)
                                        : const Color(0xFFC53030),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      activePriceSetting != null
                                          ? 'Billing Price ${_money(activePriceSetting.pricePaise)}/${activePriceSetting.basis == PricingBasis.monthly ? 'month' : 'day'} — ${activePriceSetting.isBillingOnly ? 'Use for this billing only' : 'Global Price'}'
                                          : 'No billing price set',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color:
                                            activePriceSetting != null
                                                ? const Color(0xFF2B6CB0)
                                                : const Color(0xFFC53030),
                                      ),
                                    ),
                                    Text(
                                      activePriceSetting != null
                                          ? (activePriceSetting.isBillingOnly
                                              ? 'Billing-specific price snapshot active for this month.'
                                              : 'Canonical reusable global price rule active.')
                                          : 'Configure billing price before batch finalization.',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF4A5568),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              ElevatedButton.icon(
                                key: const ValueKey('set-billing-price-btn'),
                                onPressed:
                                    () => _showSetBillingPriceModal(
                                      publications,
                                      monthlyPrices,
                                    ),
                                icon: const Icon(Icons.edit_note, size: 18),
                                label: Text(
                                  activePriceSetting != null
                                      ? 'Change Price'
                                      : 'Set Billing Price',
                                ),
                              ),
                            ],
                          ),
                ),
              ),
            const SizedBox(height: 12),

            // Customer Eligibility Summary & Batch Action Controls
            if (widget.user.isHead && _rows.isNotEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isMobile)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Eligibility Summary',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$selectedCount selected of $readyToBillCount ready',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 12.5,
                                color: Color(0xFF2B6CB0),
                              ),
                            ),
                          ],
                        )
                      else
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Eligibility Summary',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              '$selectedCount selected of $readyToBillCount ready',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF2B6CB0),
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 10),

                      // Eligibility summary badges in responsive layout
                      if (isMobile)
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _summaryChip(
                              'Eligible',
                              '$totalEligible',
                              Colors.blue,
                            ),
                            _summaryChip(
                              'Ready',
                              '$readyToBillCount',
                              Colors.green,
                            ),
                            if (failedCount > 0)
                              _summaryChip(
                                'Failed',
                                '$failedCount',
                                Colors.red,
                              ),
                            _summaryChip(
                              'Finalized',
                              '$finalizedCount',
                              Colors.grey,
                            ),
                          ],
                        )
                      else
                        Wrap(
                          spacing: 16,
                          runSpacing: 8,
                          children: [
                            _summaryChip(
                              'Eligible',
                              '$totalEligible',
                              Colors.blue,
                            ),
                            _summaryChip(
                              'Ready',
                              '$readyToBillCount',
                              Colors.green,
                            ),
                            if (failedCount > 0)
                              _summaryChip(
                                'Failed',
                                '$failedCount',
                                Colors.red,
                              ),
                            _summaryChip(
                              'Finalized',
                              '$finalizedCount',
                              Colors.grey,
                            ),
                          ],
                        ),
                      const Divider(height: 24),

                      // Select All / Batch Actions
                      if (isMobile)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            InkWell(
                              onTap: () {
                                setState(() {
                                  if (readyToBillCount > 0 &&
                                      selectedCount == readyToBillCount) {
                                    _selectedCustomerIds.clear();
                                  } else {
                                    _selectedCustomerIds.addAll(
                                      filteredRows
                                          .where((r) => r.finalizedBill == null)
                                          .map((r) => r.customerId),
                                    );
                                  }
                                });
                              },
                              child: Row(
                                children: [
                                  Checkbox(
                                    value:
                                        readyToBillCount > 0 &&
                                        selectedCount == readyToBillCount,
                                    onChanged: (val) {
                                      setState(() {
                                        if (val == true) {
                                          _selectedCustomerIds.addAll(
                                            filteredRows
                                                .where(
                                                  (r) => r.finalizedBill == null,
                                                )
                                                .map((r) => r.customerId),
                                          );
                                        } else {
                                          _selectedCustomerIds.clear();
                                        }
                                      });
                                    },
                                  ),
                                  const Text(
                                    'Select All Ready',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            ElevatedButton.icon(
                              key: const ValueKey('create-all-bills-btn'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                              onPressed:
                                  readyToBillCount == 0 || _isBatchRunning
                                      ? null
                                      : () => _runBatchBilling(filteredRows),
                              icon: const Icon(Icons.flash_on_outlined),
                              label: const Text(
                                'Create All',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                              key: const ValueKey('create-selected-bills-btn'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                              onPressed:
                                  selectedCount == 0 || _isBatchRunning
                                      ? null
                                      : () {
                                        final targets =
                                            filteredRows
                                                .where(
                                                  (r) => _selectedCustomerIds
                                                      .contains(r.customerId),
                                                )
                                                .toList();
                                        _runBatchBilling(targets);
                                      },
                              icon: const Icon(Icons.checklist_rtl_outlined),
                              label: Text('Create Selected ($selectedCount)'),
                            ),
                          ],
                        )
                      else
                        Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Checkbox(
                                  value:
                                      readyToBillCount > 0 &&
                                      selectedCount == readyToBillCount,
                                  onChanged: (val) {
                                    setState(() {
                                      if (val == true) {
                                        _selectedCustomerIds.addAll(
                                          filteredRows
                                              .where(
                                                (r) => r.finalizedBill == null,
                                              )
                                              .map((r) => r.customerId),
                                        );
                                      } else {
                                        _selectedCustomerIds.clear();
                                      }
                                    });
                                  },
                                ),
                                const Text('Select All Ready'),
                              ],
                            ),

                            // Create Selected Bills Button
                            OutlinedButton.icon(
                              key: const ValueKey('create-selected-bills-btn'),
                              onPressed:
                                  selectedCount == 0 || _isBatchRunning
                                      ? null
                                      : () {
                                        final targets =
                                            filteredRows
                                                .where(
                                                  (r) => _selectedCustomerIds
                                                      .contains(r.customerId),
                                                )
                                                .toList();
                                        _runBatchBilling(targets);
                                      },
                              icon: const Icon(Icons.checklist_rtl_outlined),
                              label: Text('Create Selected ($selectedCount)'),
                            ),

                            // Create All Button
                            ElevatedButton.icon(
                              key: const ValueKey('create-all-bills-btn'),
                              onPressed:
                                  readyToBillCount == 0 || _isBatchRunning
                                      ? null
                                      : () => _runBatchBilling(filteredRows),
                              icon: const Icon(Icons.flash_on_outlined),
                              label: const Text('Create All'),
                            ),
                          ],
                        ),

                      // Batch progress status
                      if (_isBatchRunning) ...[
                        const SizedBox(height: 12),
                        LinearProgressIndicator(
                          value:
                              _batchTotal > 0
                                  ? _batchCompleted / _batchTotal
                                  : 0,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Processing $_batchCompleted of $_batchTotal: $_batchCurrentCustomer...',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
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
            else if (filteredRows.isEmpty)
              EmptyStateCard(
                icon: Icons.receipt_long_outlined,
                title: l10n?.noActiveCustomers ?? 'No active customers',
                message:
                    l10n?.noActiveCustomersDesc ??
                    'There are no accessible active customers matching the selected filters.',
              )
            else ...[
              for (final row in filteredRows)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _buildCustomerCard(context, row),
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
                          : Text(
                            l10n?.loadMoreCustomers ?? 'Load more customers',
                          ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerCard(BuildContext context, BillingWorkspaceRow row) {
    final isFailed = row.hasFailed && row.finalizedBill == null;
    final isFinalized = row.finalizedBill != null;

    return Card(
      elevation: 0,
      color: isFailed ? const Color(0xFFFFF5F5) : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isFailed ? const Color(0xFFFEB2B2) : const Color(0xFFCBD5E1),
          width: isFailed ? 1.5 : 1.0,
        ),
      ),
      child: InkWell(
        onTap: () => _open(row),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row: Selection Checkbox + Customer Name + Status Icon
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (widget.user.isHead && !isFinalized)
                    Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: Checkbox(
                          value: _selectedCustomerIds.contains(row.customerId),
                          onChanged: (val) {
                            setState(() {
                              if (val == true) {
                                _selectedCustomerIds.add(row.customerId);
                              } else {
                                _selectedCustomerIds.remove(row.customerId);
                              }
                            });
                          },
                        ),
                      ),
                    ),
                  Expanded(
                    child: Text(
                      row.customerName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Color(0xFF102A43),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (isFinalized)
                    const Icon(
                      Icons.verified_outlined,
                      color: Colors.green,
                      size: 22,
                    )
                  else if (isFailed)
                    const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 22,
                    )
                  else
                    const Icon(
                      Icons.pending_actions_outlined,
                      color: Colors.orange,
                      size: 22,
                    ),
                ],
              ),
              const SizedBox(height: 6),

              // Code, Area & Employee info
              Text(
                '${row.customerCode} • Area ${row.areaId}${row.assignedEmployeeId.isNotEmpty ? ' • Emp: ${row.assignedEmployeeId}' : ''}',
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF486581),
                  height: 1.3,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10),

              // Status / Failure reason & Action button
              if (isFinalized)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Finalized • ${_money(row.finalizedBill!.totalDuePaise)}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.green.shade800,
                    ),
                  ),
                )
              else if (isFailed)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            size: 18,
                            color: Colors.red.shade700,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Failed: ${row.lastFailureReason ?? 'Finalization error'}',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w500,
                                color: Colors.red.shade900,
                              ),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: OutlinedButton.icon(
                          key: ValueKey('retry-bill-${row.customerId}'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red.shade800,
                            side: BorderSide(color: Colors.red.shade300),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed:
                              _isBatchRunning || _loading
                                  ? null
                                  : () => _retryRow(row),
                          icon: const Icon(Icons.refresh, size: 16),
                          label: const Text(
                            'Retry',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Row(
                  children: [
                    Text(
                      'Not finalized',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.orange.shade800,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    if (!widget.user.isHead)
                      const Tooltip(
                        message: 'Only the Head can preview or finalize',
                        child: Icon(
                          Icons.lock_outline,
                          size: 16,
                          color: Colors.grey,
                        ),
                      )
                    else
                      const Icon(
                        Icons.chevron_right,
                        size: 18,
                        color: Colors.grey,
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _summaryChip(String label, String value, Color color) {
    return Chip(
      avatar: CircleAvatar(
        backgroundColor: color,
        child: Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      label: Text(label),
      backgroundColor: color.withValues(alpha: 0.1),
    );
  }
}

class _BillingPriceSetting {
  const _BillingPriceSetting({
    required this.newspaperId,
    required this.pricePaise,
    required this.basis,
    required this.isBillingOnly,
    required this.isGlobalPrice,
  });

  final String newspaperId;
  final int pricePaise;
  final PricingBasis basis;
  final bool isBillingOnly;
  final bool isGlobalPrice;
}

String _money(int paise) => BillingMoney.formatPaise(paise);
