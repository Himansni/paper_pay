import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:paper_route/core/domain/local_date.dart';
import 'package:paper_route/core/errors/app_exception.dart';
import 'package:paper_route/core/presentation/async_state_cards.dart';
import 'package:paper_route/features/auth/domain/access_policy.dart';
import 'package:paper_route/features/auth/domain/app_user.dart';
import 'package:paper_route/features/billing/domain/billing_repository.dart';
import 'package:paper_route/features/billing/domain/monthly_bill.dart';
import 'package:paper_route/features/billing/presentation/billing_providers.dart';
import 'package:paper_route/features/business/domain/business_profile.dart';
import 'package:paper_route/features/business/presentation/business_providers.dart';
import 'package:paper_route/features/newspapers/domain/newspaper.dart';
import 'package:paper_route/features/newspapers/domain/newspaper_master_catalog.dart';
import 'package:paper_route/features/newspapers/presentation/master_catalog_picker_sheet.dart';
import 'package:paper_route/features/newspapers/presentation/newspaper_providers.dart';

class DailyPricingPage extends ConsumerStatefulWidget {
  const DailyPricingPage({required this.user, super.key});

  final AppUser user;

  @override
  ConsumerState<DailyPricingPage> createState() => _DailyPricingPageState();
}

class _DailyPricingPageState extends ConsumerState<DailyPricingPage>
    with SingleTickerProviderStateMixin {
  static const _accessPolicy = AccessPolicy();
  late TabController _tabController;

  // Catalog
  List<Newspaper> _newspapers = const [];
  bool _loading = true;
  String? _error;

  // Single-day quick pricing (legacy compatible)
  final _date = TextEditingController();
  final _reason = TextEditingController();
  final Map<String, TextEditingController> _priceControllers = {};
  Map<String, ResolvedNewspaperPrice> _resolvedPrices = {};
  Map<String, String> _rowErrors = {};
  bool _savingDaily = false;

  // Central Global Publication Pricing Rule
  Newspaper? _selectedPaper;
  PricingBasis _pricingBasis = PricingBasis.monthly;
  final _globalPriceController = TextEditingController();
  final _ruleReasonController = TextEditingController();
  late LocalDate _effectiveFrom;
  late LocalDate _effectiveUntil;
  PricingImpactPreview? _impactPreview;
  bool _loadingImpact = false;
  bool _savingGlobalRule = false;
  String? _globalRuleError;

  // Bulk Month-End Billing
  late LocalDate _bulkBillingMonth;
  Newspaper? _bulkSelectedPaper;
  BulkMonthEndBillSummary? _bulkSummary;
  bool _loadingBulkPreview = false;
  bool _generatingBulk = false;
  BulkMonthEndProgress? _bulkProgress;
  StreamSubscription<BulkMonthEndProgress>? _bulkSubscription;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    final now = DateTime.now();
    _date.text = DateFormat('yyyy-MM-dd').format(now);

    // Default global rule effective period: start of this month to end of this month
    _effectiveFrom = LocalDate(now.year, now.month, 1);
    final nextMonthFirst = now.month == 12
        ? DateTime(now.year + 1, 1, 1)
        : DateTime(now.year, now.month + 1, 1);
    final lastDayThisMonth = nextMonthFirst.subtract(const Duration(days: 1));
    _effectiveUntil = LocalDate(now.year, now.month, lastDayThisMonth.day);

    _bulkBillingMonth = LocalDate(now.year, now.month, 1);

    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _tabController.dispose();
    _date.dispose();
    _reason.dispose();
    _globalPriceController.dispose();
    _ruleReasonController.dispose();
    _bulkSubscription?.cancel();
    for (final controller in _priceControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repository = ref.read(newspaperRepositoryProvider);
      final all = <Newspaper>[];
      NewspaperPageCursor? cursor;
      while (true) {
        final page = await repository.fetchNewspapers(
          NewspaperListRequest(
            businessId: widget.user.businessId!,
            requesterId: widget.user.uid,
            status: NewspaperStatus.active,
            pageSize: 50,
            cursor: cursor,
          ),
        );
        all.addAll(page.newspapers);
        if (!page.hasMore || page.nextCursor == null) break;
        if (cursor != null && cursor.newspaperId == page.nextCursor!.newspaperId) {
          break;
        }
        cursor = page.nextCursor;
      }
      final uniqueMap = <String, Newspaper>{};
      for (final n in all) {
        final key = n.displayName.trim().toLowerCase();
        uniqueMap.putIfAbsent(key.isEmpty ? n.id : key, () => n);
      }
      final deduplicated = uniqueMap.values.toList();
      for (final p in deduplicated) {
        _priceControllers.putIfAbsent(p.id, () => TextEditingController());
      }
      if (!mounted) return;
      setState(() {
        _newspapers = deduplicated;
        if (_selectedPaper != null) {
          _selectedPaper =
              deduplicated.where((p) => p.id == _selectedPaper!.id).firstOrNull;
        }
        if (_selectedPaper == null && deduplicated.isNotEmpty) {
          _selectedPaper = deduplicated.first;
          _globalPriceController.text = NewspaperMoney.formatPaiseForInput(
            _pricingBasis == PricingBasis.monthly
                ? deduplicated.first.defaultPricePaise * 30
                : deduplicated.first.defaultPricePaise,
          );
        }
        if (_bulkSelectedPaper != null) {
          _bulkSelectedPaper = deduplicated
              .where((p) => p.id == _bulkSelectedPaper!.id)
              .firstOrNull;
        }
        if (_bulkSelectedPaper == null && deduplicated.isNotEmpty) {
          _bulkSelectedPaper = deduplicated.first;
        }
      });
      await _resolveAll();
      if (_selectedPaper != null) {
        _fetchImpactPreview();
      }
    } on Object catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resolveAll() async {
    if (_newspapers.isEmpty) return;
    try {
      final date = LocalDate.parse(_date.text.trim());
      final resolved = <String, ResolvedNewspaperPrice>{};
      final repository = ref.read(newspaperRepositoryProvider);
      for (final paper in _newspapers) {
        final r = await repository.resolvePriceOn(
          businessId: widget.user.businessId!,
          newspaperId: paper.id,
          date: date,
        );
        resolved[paper.id] = r;
        final controller = _priceControllers[paper.id];
        if (controller != null) {
          controller.text = NewspaperMoney.formatPaiseForInput(r.pricePaise);
        }
      }
      if (mounted) {
        setState(() {
          _resolvedPrices = resolved;
          _rowErrors.clear();
        });
      }
    } on Object catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  Future<void> _fetchImpactPreview() async {
    if (_selectedPaper == null) return;
    final text = _globalPriceController.text.trim();
    int pricePaise;
    try {
      pricePaise = NewspaperMoney.parseRupeesToPaise(text);
      if (pricePaise <= 0) return;
    } catch (_) {
      return;
    }

    setState(() {
      _loadingImpact = true;
      _globalRuleError = null;
    });

    try {
      final input = PriceRuleInput(
        kind: PriceRuleKind.period,
        startDate: _effectiveFrom,
        endDate: _effectiveUntil,
        pricePaise: pricePaise,
        pricingBasis: _pricingBasis,
      );
      final impact = await ref.read(newspaperRepositoryProvider).calculatePricingImpact(
        actor: widget.user,
        newspaperId: _selectedPaper!.id,
        input: input,
      );
      if (mounted) {
        setState(() {
          _impactPreview = impact;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _globalRuleError = e.toString());
      }
    } finally {
      if (mounted) setState(() => _loadingImpact = false);
    }
  }

  Future<void> _confirmAndApplyGlobalPrice() async {
    if (_selectedPaper == null) return;
    final text = _globalPriceController.text.trim();
    int pricePaise;
    try {
      pricePaise = NewspaperMoney.parseRupeesToPaise(text);
      NewspaperMoney.validatePrice(pricePaise);
    } catch (e) {
      setState(() => _globalRuleError = e is AppException ? e.message : 'Invalid price');
      return;
    }

    if (_effectiveUntil.isBefore(_effectiveFrom)) {
      setState(() => _globalRuleError = 'End date cannot be earlier than start date.');
      return;
    }

    // Explicit financial confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Review price update'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _selectedPaper!.name,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 6),
            Text(
              '${BillingMoney.formatPaise(pricePaise)} (${_pricingBasis.label} rate)\nEffective: $_effectiveFrom → $_effectiveUntil',
              style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 12),
            const Text(
              'This will become the global applicable price for active subscriptions during the selected period.',
              style: TextStyle(fontSize: 13, color: Color(0xFF475569)),
            ),
            const SizedBox(height: 8),
            if (_impactPreview != null) ...[
              Text(
                'Affected subscribers: ${_impactPreview!.affectedSubscriptionsCount}',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 4),
            ],
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: const Text(
                'Finalized bills will NOT be changed. Precedence rules (customer exceptions and exact-date overrides) remain strictly preserved.',
                style: TextStyle(fontSize: 12, color: Color(0xFF92400E)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Apply price update'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _savingGlobalRule = true;
      _globalRuleError = null;
    });

    try {
      final input = PriceRuleInput(
        kind: PriceRuleKind.period,
        startDate: _effectiveFrom,
        endDate: _effectiveUntil,
        pricePaise: pricePaise,
        pricingBasis: _pricingBasis,
        reason: _ruleReasonController.text.trim().isNotEmpty
            ? _ruleReasonController.text.trim()
            : 'Global ${_pricingBasis.label} price rule',
      );

      await ref.read(newspaperRepositoryProvider).createPriceRule(
        actor: widget.user,
        newspaperId: _selectedPaper!.id,
        input: input,
      );

      _ruleReasonController.clear();
      await _resolveAll();
      await _fetchImpactPreview();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Global price rule applied for ${_selectedPaper!.name}. Unfinalized periods will resolve this price automatically.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _globalRuleError = e is AppException ? e.message : e.toString());
      }
    } finally {
      if (mounted) setState(() => _savingGlobalRule = false);
    }
  }

  Future<void> _onSelectFromMasterCatalog(MasterNewspaperEntry selected) async {
    final existing = _newspapers.where((p) {
      final nameMatches =
          p.name.trim().toLowerCase() == selected.name.trim().toLowerCase();
      final editionMatches =
          p.edition.trim().toLowerCase() == selected.edition.trim().toLowerCase();
      return nameMatches && (selected.edition.isEmpty || editionMatches);
    }).firstOrNull;

    Newspaper targetPaper;
    if (existing != null) {
      targetPaper = existing;
    } else {
      try {
        final repo = ref.read(newspaperRepositoryProvider);
        final input = NewspaperInput(
          name: selected.name,
          edition: selected.edition,
          language: selected.language,
          defaultPricePaise: selected.defaultPricePaise,
        );
        final newId = await repo.createNewspaper(
          actor: widget.user,
          input: input,
        );
        await _load();
        final newlyCreated =
            _newspapers.where((p) => p.id == newId).firstOrNull;
        if (newlyCreated == null) return;
        targetPaper = newlyCreated;
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not add publication: $e')),
          );
        }
        return;
      }
    }

    if (!mounted) return;
    setState(() {
      _selectedPaper = targetPaper;
      _globalPriceController.text = NewspaperMoney.formatPaiseForInput(
        _pricingBasis == PricingBasis.monthly
            ? selected.defaultPricePaise * 30
            : selected.defaultPricePaise,
      );
    });
    _fetchImpactPreview();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Selected "${targetPaper.name}" from catalogue. Review and apply rate.',
        ),
      ),
    );
  }

  Future<void> _loadBulkPreview() async {
    if (_bulkSelectedPaper == null) return;
    setState(() {
      _loadingBulkPreview = true;
      _bulkSummary = null;
    });
    try {
      final summary = await ref.read(billingRepositoryProvider).previewBulkMonthEndBills(
        actor: widget.user,
        publicationId: _bulkSelectedPaper!.id,
        month: _bulkBillingMonth,
      );
      if (mounted) {
        setState(() {
          _bulkSummary = summary;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load month-end preview: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingBulkPreview = false);
    }
  }

  Future<void> _startBulkBillGeneration() async {
    if (_bulkSelectedPaper == null || _bulkSummary == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm month-end bill generation'),
        content: Text(
          'Generate and finalize monthly bills for ${_bulkSummary!.readyToBillCount} subscriber(s) of ${_bulkSelectedPaper!.name} for ${DateFormat('MMMM yyyy').format(DateTime(_bulkBillingMonth.year, _bulkBillingMonth.month))}?\n\nAlready finalized bills (${_bulkSummary!.alreadyFinalizedCount}) will be skipped safely.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Generate bills'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _generatingBulk = true;
      _bulkProgress = null;
    });

    _bulkSubscription?.cancel();
    final stream = ref.read(billingRepositoryProvider).generateBulkMonthEndBills(
      actor: widget.user,
      publicationId: _bulkSelectedPaper!.id,
      month: _bulkBillingMonth,
    );

    _bulkSubscription = stream.listen(
      (progress) {
        if (mounted) {
          setState(() {
            _bulkProgress = progress;
            if (progress.isDone) {
              _generatingBulk = false;
            }
          });
        }
      },
      onError: (err) {
        if (mounted) {
          setState(() => _generatingBulk = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Bulk billing failed: $err')),
          );
        }
      },
      onDone: () {
        if (mounted) {
          setState(() => _generatingBulk = false);
          _loadBulkPreview();
        }
      },
    );
  }

  Future<void> _saveAllDaily() async {
    final date = LocalDate.parse(_date.text.trim());
    final updates = <DailyPriceUpdateItem>[];
    final errors = <String, String>{};
    final reasonText = _reason.text.trim();

    for (final paper in _newspapers) {
      final controller = _priceControllers[paper.id];
      final text = controller?.text.trim() ?? '';
      final currentResolved = _resolvedPrices[paper.id];
      final currentPaise = currentResolved?.pricePaise ?? paper.defaultPricePaise;
      final currentInput = NewspaperMoney.formatPaiseForInput(currentPaise);

      if (text != currentInput) {
        try {
          final paise = NewspaperMoney.parseRupeesToPaise(text);
          NewspaperMoney.validatePrice(paise);
          updates.add(
            DailyPriceUpdateItem(
              newspaperId: paper.id,
              pricePaise: paise,
              reason: reasonText.isNotEmpty
                  ? reasonText
                  : 'Daily price update for $date',
            ),
          );
        } catch (e) {
          errors[paper.id] = e is AppException ? e.message : 'Invalid price.';
        }
      }
    }

    if (errors.isNotEmpty) {
      setState(() => _rowErrors = errors);
      return;
    }

    if (updates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No prices were changed.')),
      );
      return;
    }

    setState(() {
      _savingDaily = true;
      _error = null;
      _rowErrors.clear();
    });

    try {
      final result = await ref.read(newspaperRepositoryProvider).updateDailyPrices(
        actor: widget.user,
        date: date,
        updates: updates,
      );
      _reason.clear();
      await _resolveAll();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Daily price saved for ${result.updatedCount} newspaper(s). Unfinalized previews will use it automatically.',
            ),
          ),
        );
      }
    } on Object catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _savingDaily = false);
    }
  }

  Future<void> _pickDate() async {
    DateTime initial;
    try {
      final parsed = LocalDate.parse(_date.text.trim());
      initial = DateTime(parsed.year, parsed.month, parsed.day);
    } on Object {
      initial = DateTime.now();
    }
    final selected = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (selected == null) return;
    _date.text = DateFormat('yyyy-MM-dd').format(selected);
    await _resolveAll();
  }

  @override
  Widget build(BuildContext context) {
    final business = ref.watch(businessProfileProvider(widget.user.businessId!));
    final region = business.asData?.value.primaryPricingRegion;
    final canManageGlobal = _accessPolicy.canManageGlobalPricing(widget.user);

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.go('/')),
        title: const Text('Pricing Center'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Global Pricing', icon: Icon(Icons.public, size: 20)),
            Tab(text: 'Month-End Billing', icon: Icon(Icons.receipt_long, size: 20)),
            Tab(text: 'Daily Pricing', icon: Icon(Icons.today, size: 20)),
          ],
        ),
      ),
      body: SafeArea(
        top: false,
        child: TabBarView(
          controller: _tabController,
          children: [
            // Tab 1: Global Publication Pricing
            _buildGlobalPricingTab(canManageGlobal),
            // Tab 2: Month-End Billing
            _buildMonthEndBillingTab(),
            // Tab 3: Daily Pricing (Single-day / exact-date updates)
            _buildDailyPricingTab(region),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // TAB 1: GLOBAL PUBLICATION PRICING
  // -------------------------------------------------------------
  Widget _buildGlobalPricingTab(bool canManageGlobal) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_newspapers.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const EmptyStateCard(
              icon: Icons.newspaper_outlined,
              title: 'No active newspapers',
              message:
                  'Add a custom newspaper or browse the Indian Master Catalogue before setting global publication prices.',
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              key: const ValueKey('browse-catalog-pricing-empty-button'),
              onPressed: () async {
                final selected = await MasterCatalogPickerSheet.show(context);
                if (selected != null && mounted) {
                  await _onSelectFromMasterCatalog(selected);
                }
              },
              icon: const Icon(Icons.menu_book_outlined),
              label: const Text('Browse Indian Master Catalogue'),
            ),
          ],
        ),
      );
    }

    if (!canManageGlobal) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: EmptyStateCard(
          icon: Icons.lock_outline,
          title: 'Permission required',
          message: 'You need the "Allow global publication pricing" permission to update global publication rates.',
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      children: [
        Text(
          'Publication Price Rule',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        const Text(
          'Set a central publication price that automatically applies to all eligible active subscribers during the billing period.',
          style: TextStyle(color: Color(0xFF486581), fontSize: 13, height: 1.4),
        ),
        const SizedBox(height: 16),

        // Publication selector card
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'PUBLICATION / EDITION',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<Newspaper>(
                  value: _newspapers
                      .where((p) => p.id == _selectedPaper?.id)
                      .firstOrNull,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                  items: _newspapers.map((p) {
                    final sub = [p.edition, p.language].where((s) => s.isNotEmpty).join(' • ');
                    return DropdownMenuItem(
                      value: p,
                      child: Text(
                        sub.isNotEmpty ? '${p.name} ($sub)' : p.name,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (p) {
                    if (p != null) {
                      setState(() {
                        _selectedPaper = p;
                        _globalPriceController.text = NewspaperMoney.formatPaiseForInput(
                          _pricingBasis == PricingBasis.monthly
                              ? p.defaultPricePaise * 30
                              : p.defaultPricePaise,
                        );
                      });
                      _fetchImpactPreview();
                    }
                  },
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  key: const ValueKey('browse-catalog-pricing-button'),
                  onPressed: () async {
                    final selected =
                        await MasterCatalogPickerSheet.show(context);
                    if (selected != null && mounted) {
                      await _onSelectFromMasterCatalog(selected);
                    }
                  },
                  icon: const Icon(Icons.menu_book_outlined),
                  label: const Text('Browse Indian Master Catalogue'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Price Rule Configuration Card
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'PRICE RULE',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 12),
                const Text('Pricing basis', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 6),
                SegmentedButton<PricingBasis>(
                  segments: const [
                    ButtonSegment(value: PricingBasis.monthly, label: Text('Monthly rate')),
                    ButtonSegment(value: PricingBasis.daily, label: Text('Daily rate')),
                  ],
                  selected: {_pricingBasis},
                  onSelectionChanged: (set) {
                    setState(() {
                      _pricingBasis = set.first;
                      if (_selectedPaper != null) {
                        _globalPriceController.text = NewspaperMoney.formatPaiseForInput(
                          _pricingBasis == PricingBasis.monthly
                              ? _selectedPaper!.defaultPricePaise * 30
                              : _selectedPaper!.defaultPricePaise,
                        );
                      }
                    });
                    _fetchImpactPreview();
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _globalPriceController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: _pricingBasis == PricingBasis.monthly ? 'Monthly price (₹)' : 'Daily price (₹)',
                    prefixText: '₹ ',
                    helperText: _pricingBasis == PricingBasis.monthly
                        ? 'Applied across the calendar month for active subscribers'
                        : 'Applied to every delivery day in the effective range',
                  ),
                  onChanged: (_) => _fetchImpactPreview(),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final selected = await showDatePicker(
                            context: context,
                            initialDate: DateTime(_effectiveFrom.year, _effectiveFrom.month, _effectiveFrom.day),
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2100),
                          );
                          if (selected != null) {
                            setState(() {
                              _effectiveFrom = LocalDate(selected.year, selected.month, selected.day);
                            });
                            _fetchImpactPreview();
                          }
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Effective from',
                            suffixIcon: Icon(Icons.calendar_today, size: 18),
                          ),
                          child: Text(_effectiveFrom.toString()),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final selected = await showDatePicker(
                            context: context,
                            initialDate: DateTime(_effectiveUntil.year, _effectiveUntil.month, _effectiveUntil.day),
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2100),
                          );
                          if (selected != null) {
                            setState(() {
                              _effectiveUntil = LocalDate(selected.year, selected.month, selected.day);
                            });
                            _fetchImpactPreview();
                          }
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Effective until',
                            suffixIcon: Icon(Icons.calendar_today, size: 18),
                          ),
                          child: Text(_effectiveUntil.toString()),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _ruleReasonController,
                  decoration: const InputDecoration(
                    labelText: 'Audit reason (optional)',
                    hintText: 'e.g. Annual price revision / Publisher hike',
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Scope & Impact Preview Card
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          color: const Color(0xFFF8FAFC),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'IMPACT PREVIEW',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                    ),
                    if (_loadingImpact)
                      const SizedBox.square(dimension: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Applies to all active subscribers of this publication during the selected period. Real-time calculated from Firestore records:',
                  style: TextStyle(color: Color(0xFF475569), fontSize: 13),
                ),
                const SizedBox(height: 12),
                if (_impactPreview != null) ...[
                  _impactRow('Affected active subscriptions', '${_impactPreview!.affectedSubscriptionsCount}'),
                  _impactRow('Unbilled / unfinalized periods', '${_impactPreview!.unfinalizedBillsCount}'),
                  _impactRow('Already finalized bills (unaffected)', '${_impactPreview!.finalizedBillsCount}'),
                  _impactRow('Customer-specific overrides (preserved)', '${_impactPreview!.customerOverridesCount}'),
                  _impactRow('Paused subscriptions during period', '${_impactPreview!.pausedSubscriptionsCount}'),
                  const Divider(height: 16),
                  _impactRow(
                    'Projected additional billing',
                    BillingMoney.formatPaise(_impactPreview!.projectedAdditionalBillingPaise),
                    isBold: true,
                    valueColor: const Color(0xFF0F172A),
                  ),
                ] else
                  const Text('Enter a valid price to calculate real-time impact.', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
              ],
            ),
          ),
        ),
        if (_globalRuleError != null) ...[
          const SizedBox(height: 12),
          Text(_globalRuleError!, style: const TextStyle(color: Colors.red, fontSize: 13)),
        ],
        const SizedBox(height: 20),

        FilledButton.icon(
          key: const ValueKey('review-global-price-rule'),
          onPressed: _savingGlobalRule ? null : _confirmAndApplyGlobalPrice,
          icon: _savingGlobalRule
              ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.check_circle_outline),
          label: Text(_savingGlobalRule ? 'Applying price rule…' : 'Review & Apply Global Price'),
          style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
        ),
      ],
    );
  }

  Widget _impactRow(String label, String value, {bool isBold = false, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: const Color(0xFF475569), fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: valueColor ?? const Color(0xFF0F172A))),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // TAB 2: MONTH-END BILLING (BULK BILL GENERATOR)
  // -------------------------------------------------------------
  Widget _buildMonthEndBillingTab() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_newspapers.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: EmptyStateCard(
          icon: Icons.newspaper_outlined,
          title: 'No active newspapers',
          message: 'Add an active newspaper first.',
        ),
      );
    }

    final recentMonths = List.generate(6, (i) {
      final now = DateTime.now();
      final d = DateTime(now.year, now.month - i, 1);
      return LocalDate(d.year, d.month, 1);
    });

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      children: [
        Text(
          'Month-End Billing',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        const Text(
          'Generate and finalize monthly bills for all subscribers of a publication in one safe, authoritative batch.',
          style: TextStyle(color: Color(0xFF486581), fontSize: 13, height: 1.4),
        ),
        const SizedBox(height: 16),

        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('SELECT MONTH & PUBLICATION', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                const SizedBox(height: 12),
                DropdownButtonFormField<LocalDate>(
                  value: _bulkBillingMonth,
                  decoration: const InputDecoration(
                    labelText: 'Billing month',
                    border: OutlineInputBorder(),
                  ),
                  items: recentMonths.map((m) {
                    return DropdownMenuItem(
                      value: m,
                      child: Text(DateFormat('MMMM yyyy').format(DateTime(m.year, m.month))),
                    );
                  }).toList(),
                  onChanged: _generatingBulk ? null : (m) {
                    if (m != null) {
                      setState(() => _bulkBillingMonth = m);
                      _loadBulkPreview();
                    }
                  },
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<Newspaper>(
                  value: _newspapers
                      .where((p) => p.id == _bulkSelectedPaper?.id)
                      .firstOrNull,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Publication',
                    border: OutlineInputBorder(),
                  ),
                  items: _newspapers.map((p) {
                    return DropdownMenuItem(
                      value: p,
                      child: Text(p.name),
                    );
                  }).toList(),
                  onChanged: _generatingBulk ? null : (p) {
                    if (p != null) {
                      setState(() => _bulkSelectedPaper = p);
                      _loadBulkPreview();
                    }
                  },
                ),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: _loadingBulkPreview || _generatingBulk ? null : _loadBulkPreview,
                  icon: const Icon(Icons.preview),
                  label: const Text('Review subscribers'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        if (_loadingBulkPreview)
          const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
        else if (_bulkSummary != null) ...[
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            color: const Color(0xFFF8FAFC),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('BATCH SUMMARY', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                  const SizedBox(height: 10),
                  _impactRow('Eligible subscribers', '${_bulkSummary!.eligibleSubscribersCount}'),
                  _impactRow('Ready to bill', '${_bulkSummary!.readyToBillCount}'),
                  _impactRow('Already finalized', '${_bulkSummary!.alreadyFinalizedCount}'),
                  _impactRow('Missing pricing', '${_bulkSummary!.missingPricingCount}'),
                  _impactRow('Paused (no charge)', '${_bulkSummary!.pausedNoChargeCount}'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          if (_generatingBulk || _bulkProgress != null) ...[
            Card(
              color: const Color(0xFFEBF8FF),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _bulkProgress?.isDone == true ? 'Batch Complete' : 'Generating bills…',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    LinearProgressIndicator(
                      value: _bulkProgress != null && _bulkProgress!.totalCount > 0
                          ? (_bulkProgress!.completedCount + _bulkProgress!.alreadyFinalizedCount + _bulkProgress!.failedCount) / _bulkProgress!.totalCount
                          : null,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Completed: ${_bulkProgress?.completedCount ?? 0} • Finalized: ${_bulkProgress?.alreadyFinalizedCount ?? 0} • Failed: ${_bulkProgress?.failedCount ?? 0} of ${_bulkProgress?.totalCount ?? 0}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    if (_bulkProgress?.currentCustomerName.isNotEmpty == true)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Current: ${_bulkProgress!.currentCustomerName}',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF2B6CB0)),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          FilledButton.icon(
            key: const ValueKey('generate-bulk-bills-button'),
            onPressed: _generatingBulk || _bulkSummary!.readyToBillCount == 0
                ? null
                : _startBulkBillGeneration,
            icon: _generatingBulk
                ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.bolt),
            label: Text(_generatingBulk ? 'Generating bills in batch…' : 'Generate monthly bills (${_bulkSummary!.readyToBillCount})'),
            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
          ),
        ],
      ],
    );
  }

  // -------------------------------------------------------------
  // TAB 3: DAILY PRICING (EXACT-DATE PRICING OVERRIDES)
  // -------------------------------------------------------------
  Widget _buildDailyPricingTab(PricingRegion? region) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
      children: [
        Text(
          region?.isConfigured == true
              ? "Today's Paper Prices — ${region!.districtCity}"
              : "Today's Paper Prices",
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          region?.isConfigured == true
              ? '${region!.state}${region.editionServiceRegion.isEmpty ? '' : ' · ${region.editionServiceRegion}'}'
              : 'Set single-day price overrides for festival editions or morning newsstand changes.',
          style: const TextStyle(color: Color(0xFF486581)),
        ),
        const SizedBox(height: 18),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  key: const ValueKey('daily-price-date'),
                  controller: _date,
                  decoration: InputDecoration(
                    labelText: 'Delivery date',
                    hintText: 'YYYY-MM-DD',
                    suffixIcon: IconButton(
                      tooltip: 'Choose date',
                      onPressed: _pickDate,
                      icon: const Icon(Icons.calendar_month_outlined),
                    ),
                  ),
                  onFieldSubmitted: (_) => _resolveAll(),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const ValueKey('daily-price-reason'),
                  controller: _reason,
                  maxLength: 300,
                  decoration: const InputDecoration(
                    labelText: 'Pricing / correction reason (optional)',
                    hintText: 'e.g. Festival edition / Special insert',
                    helperText: 'Applies to all changed prices on the selected date.',
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (_loading)
          const Center(child: CircularProgressIndicator())
        else if (_newspapers.isEmpty)
          const EmptyStateCard(
            icon: Icons.newspaper_outlined,
            title: 'No active newspapers',
            message: 'Add a custom newspaper or reactivate one before setting a daily price.',
          )
        else ...[
          for (int i = 0; i < _newspapers.length; i++) ...[
            Builder(
              builder: (context) {
                final paper = _newspapers[i];
                final resolved = _resolvedPrices[paper.id];
                final controller = _priceControllers[paper.id];
                final rowError = _rowErrors[paper.id];
                final currentPaise = resolved?.pricePaise ?? paper.defaultPricePaise;
                final source = resolved?.source ?? ResolvedPriceSource.defaultPrice;

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(
                      color: rowError != null ? Colors.red.shade300 : Colors.grey.shade300,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    paper.name,
                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                                  ),
                                  if (paper.edition.isNotEmpty || paper.language.isNotEmpty)
                                    Text(
                                      [paper.edition, paper.language].where((s) => s.isNotEmpty).join(' • '),
                                      style: const TextStyle(color: Color(0xFF486581), fontSize: 13),
                                    ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0F4F8),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Current: ${_money(currentPaise)}',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334E68)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Precedence: ${_sourceLabel(source)}',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF627D98)),
                        ),
                        const SizedBox(height: 12),
                        KeyedSubtree(
                          key: ValueKey('price-input-${paper.id}'),
                          child: TextFormField(
                            key: i == 0
                                ? const ValueKey('daily-price-amount')
                                : ValueKey('daily-price-amount-${paper.id}'),
                            controller: controller,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                              labelText: 'New daily price (₹)',
                              prefixText: '₹ ',
                              errorText: rowError,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
          const SizedBox(height: 10),
          const Text(
            'Customer-specific exceptions still take priority. Finalized bills and their line snapshots never change.',
            style: TextStyle(color: Color(0xFF486581), height: 1.4),
          ),
          const SizedBox(height: 16),
          KeyedSubtree(
            key: const ValueKey('save-daily-price'),
            child: FilledButton.icon(
              key: const ValueKey('save-all-prices-button'),
              onPressed: _savingDaily ? null : _saveAllDaily,
              icon: _savingDaily
                  ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.save_outlined),
              label: Text(_savingDaily ? 'Saving...' : 'Save all prices'),
            ),
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 14),
          AsyncErrorCard(message: _error!, onRetry: _load),
        ],
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () => context.go('/newspapers/new'),
          icon: const Icon(Icons.add),
          label: const Text('Add Custom Newspaper'),
        ),
      ],
    );
  }

  String _money(int paise) =>
      NumberFormat.currency(locale: 'en_IN', symbol: '₹').format(paise / 100);

  String _sourceLabel(ResolvedPriceSource source) => switch (source) {
    ResolvedPriceSource.exactDate => 'Exact-date price',
    ResolvedPriceSource.period => 'Effective-period price',
    ResolvedPriceSource.defaultPrice => 'Default price',
  };
}
