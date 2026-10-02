import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:paper_route/core/domain/local_date.dart';
import 'package:paper_route/core/errors/app_exception.dart';
import 'package:paper_route/core/presentation/async_state_cards.dart';
import 'package:paper_route/features/areas/presentation/area_providers.dart';
import 'package:paper_route/features/auth/domain/access_policy.dart';
import 'package:paper_route/features/auth/domain/app_user.dart';
import 'package:paper_route/features/billing/domain/monthly_bill.dart';
import 'package:paper_route/features/billing/presentation/billing_providers.dart';
import 'package:paper_route/features/customers/domain/customer.dart';
import 'package:paper_route/features/customers/presentation/customer_providers.dart';
import 'package:paper_route/features/employees/presentation/employee_providers.dart';
import 'package:paper_route/features/subscriptions/domain/customer_subscription.dart';
import 'package:paper_route/features/subscriptions/presentation/subscription_providers.dart';

class ManualBillPage extends ConsumerStatefulWidget {
  const ManualBillPage({
    required this.user,
    required this.customerId,
    super.key,
  });

  final AppUser user;
  final String customerId;

  @override
  ConsumerState<ManualBillPage> createState() => _ManualBillPageState();
}

class _ManualBillPageState extends ConsumerState<ManualBillPage> {
  static const _accessPolicy = AccessPolicy();

  late LocalDate _selectedMonth;
  String? _selectedSubscriptionId;
  ManualBillCalculationMode _mode = ManualBillCalculationMode.monthWise;

  final _monthWiseController = TextEditingController(text: '300');
  final _deliveryChargeController = TextEditingController(text: '0');
  final _discountController = TextEditingController(text: '0');
  final Map<int, TextEditingController> _dayControllers = {};

  MonthlyBillPreview? _preview;
  FinalizedMonthlyBill? _finalizedResult;
  bool _isReviewing = false;
  bool _isBusy = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = LocalDate(now.year, now.month, 1);
    _initDayControllers();
  }

  @override
  void dispose() {
    _monthWiseController.dispose();
    _deliveryChargeController.dispose();
    _discountController.dispose();
    for (final c in _dayControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _initDayControllers() {
    for (final c in _dayControllers.values) {
      c.dispose();
    }
    _dayControllers.clear();
    for (var day = 1; day <= _selectedMonth.daysInMonth; day++) {
      _dayControllers[day] = TextEditingController(text: '10');
    }
  }

  void _onMonthChanged(LocalDate newMonth) {
    setState(() {
      _selectedMonth = newMonth;
      _preview = null;
      _isReviewing = false;
      _errorMessage = null;
      _initDayControllers();
    });
  }

  int _calculateSubtotalPaise(CustomerSubscription? sub) {
    final quantity = sub?.quantity ?? 1;
    if (_mode == ManualBillCalculationMode.monthWise) {
      final valRupees = int.tryParse(_monthWiseController.text.trim()) ?? 0;
      return valRupees * 100;
    } else {
      var total = 0;
      for (final entry in _dayControllers.entries) {
        final valRupees = int.tryParse(entry.value.text.trim()) ?? 0;
        total += valRupees * 100 * quantity;
      }
      return total;
    }
  }

  int _calculateDeliveryChargePaise() {
    final val = int.tryParse(_deliveryChargeController.text.trim()) ?? 0;
    return val * 100;
  }

  int _calculateDiscountPaise() {
    final val = int.tryParse(_discountController.text.trim()) ?? 0;
    return val * 100;
  }

  int _calculateFinalBillPaise(CustomerSubscription? sub) {
    final subtotal = _calculateSubtotalPaise(sub);
    final delivery = _calculateDeliveryChargePaise();
    final discount = _calculateDiscountPaise();
    final total = subtotal + delivery - discount;
    return total > 0 ? total : 0;
  }

  ManualBillInput? _buildInput(CustomerSubscription sub) {
    final monthWisePaise = _mode == ManualBillCalculationMode.monthWise
        ? _calculateSubtotalPaise(sub)
        : null;

    final dailyEntries = <ManualDailyEntry>[];
    if (_mode != ManualBillCalculationMode.monthWise) {
      for (var day = 1; day <= _selectedMonth.daysInMonth; day++) {
        final date = LocalDate(_selectedMonth.year, _selectedMonth.month, day);
        final rateRupees = int.tryParse(_dayControllers[day]?.text.trim() ?? '') ?? 0;
        dailyEntries.add(
          ManualDailyEntry(
            date: date,
            unitPricePaise: rateRupees * 100,
          ),
        );
      }
    }

    return ManualBillInput(
      customerId: widget.customerId,
      subscriptionId: sub.id,
      month: _selectedMonth,
      mode: _mode,
      monthWiseAmountPaise: monthWisePaise,
      dailyEntries: dailyEntries,
      deliveryChargePaise: _calculateDeliveryChargePaise(),
      discountPaise: _calculateDiscountPaise(),
    );
  }

  Future<void> _reviewBill(CustomerSubscription sub) async {
    setState(() {
      _isBusy = true;
      _errorMessage = null;
    });
    try {
      final input = _buildInput(sub);
      if (input == null) return;
      final repo = ref.read(billingRepositoryProvider);
      final preview = await repo.previewManualBill(
        actor: widget.user,
        input: input,
      );
      setState(() {
        _preview = preview;
        _isReviewing = true;
      });
    } on AppException catch (error) {
      setState(() => _errorMessage = error.message);
    } catch (error) {
      setState(() => _errorMessage = 'Could not generate bill preview: $error');
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _finalizeBill(CustomerSubscription sub) async {
    setState(() {
      _isBusy = true;
      _errorMessage = null;
    });
    try {
      final input = _buildInput(sub);
      if (input == null) return;
      final repo = ref.read(billingRepositoryProvider);
      final finalized = await repo.finalizeManualBill(
        actor: widget.user,
        input: input,
      );
      setState(() {
        _finalizedResult = finalized;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Monthly bill finalized successfully.')),
        );
      }
    } on AppException catch (error) {
      setState(() => _errorMessage = error.message);
    } catch (error) {
      setState(() => _errorMessage = 'Could not finalize bill: $error');
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final businessId = widget.user.businessId ?? '';
    final custKey = (businessId: businessId, customerId: widget.customerId);
    final customerAsync = ref.watch(customerProvider(custKey));
    final subsAsync = ref.watch(customerSubscriptionsProvider(custKey));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create monthly bill'),
        leading: BackButton(
          onPressed: () {
            if (_isReviewing && _finalizedResult == null) {
              setState(() => _isReviewing = false);
            } else if (context.canPop()) {
              context.pop();
            } else {
              context.go('/customers/${widget.customerId}');
            }
          },
        ),
      ),
      body: customerAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Padding(
          padding: const EdgeInsets.all(16),
          child: AsyncErrorCard(
            message: 'Could not load customer: $err',
            onRetry: () => ref.invalidate(customerProvider(custKey)),
          ),
        ),
        data: (customer) {
          if (customer == null) {
            return const Center(child: Text('Customer not found.'));
          }

          final canCreate = _accessPolicy.canCreateManualBill(
            member: widget.user,
            customerBusinessId: customer.businessId,
            assignedEmployeeId: customer.assignedEmployeeId,
            customerAreaId: customer.areaId,
            isCustomerArchived: customer.isArchived,
          );

          if (!canCreate) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'You do not have permission to create manual bills for this customer.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.red),
                ),
              ),
            );
          }

          return subsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Padding(
              padding: const EdgeInsets.all(16),
              child: AsyncErrorCard(
                message: 'Could not load subscriptions: $err',
                onRetry: () => ref.invalidate(customerSubscriptionsProvider(custKey)),
              ),
            ),
            data: (subscriptions) {
              if (subscriptions.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.menu_book_outlined, size: 48, color: Colors.grey),
                        const SizedBox(height: 12),
                        const Text(
                          'No active subscriptions',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'This customer has no active subscriptions. Add a subscription before creating a monthly bill.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton(
                          onPressed: () => context.push(
                            '/customers/${widget.customerId}/subscriptions/new',
                          ),
                          child: const Text('Add subscription'),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final activeSubs = subscriptions.where((s) => s.isActive).toList();
              final availableSubs = activeSubs.isNotEmpty ? activeSubs : subscriptions;
              final selectedSub = availableSubs.firstWhere(
                (s) => s.id == _selectedSubscriptionId,
                orElse: () => availableSubs.first,
              );
              _selectedSubscriptionId = selectedSub.id;

              return LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_finalizedResult != null)
                          _buildFinalizedSuccessCard(_finalizedResult!)
                        else ...[
                          _buildCustomerSummaryCard(customer),
                          const SizedBox(height: 16),
                          _buildMonthAndSubSelector(availableSubs, selectedSub),
                          const SizedBox(height: 16),
                          if (_preview?.alreadyFinalizedBill != null)
                            _buildExistingBillBanner(_preview!.alreadyFinalizedBill!)
                          else if (_isReviewing && _preview != null)
                            _buildReviewSection(_preview!, selectedSub)
                          else
                            _buildEditingSection(selectedSub),
                        ],
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildCustomerSummaryCard(Customer customer) {
    final areas = ref.watch(deliveryAreasProvider(customer.businessId)).asData?.value ?? [];
    final employees = ref.watch(employeeMembersProvider(customer.businessId)).asData?.value ?? [];

    final area = areas.where((a) => a.id == customer.areaId).firstOrNull;
    final areaName = area?.name ?? (customer.areaId.isNotEmpty ? customer.areaId : 'Unassigned');

    final employee = employees.where((e) => e.uid == customer.assignedEmployeeId).firstOrNull;
    final employeeName = employee?.displayName ?? (customer.assignedEmployeeId.isNotEmpty ? customer.assignedEmployeeId : 'Unassigned');

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: const Color(0xFFE2E8F0),
                  child: const Icon(Icons.person_outline, size: 22, color: Color(0xFF0F172A)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        customer.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined, size: 14, color: Color(0xFF64748B)),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              customer.addressSummary.isNotEmpty
                                  ? '$areaName • ${customer.addressSummary}'
                                  : areaName,
                              style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.badge_outlined, size: 14, color: Color(0xFF64748B)),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              'Assigned: $employeeName',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 20, color: Color(0xFFF1F5F9)),
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Text(
                        'Customer ID: ',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      Flexible(
                        child: Text(
                          customer.customerCode,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy_outlined, size: 16, color: Color(0xFF64748B)),
                  tooltip: 'Copy customer code',
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.all(4),
                  onPressed: () {
                    // Clipboard copy
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Copied ${customer.customerCode} to clipboard')),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthAndSubSelector(List<CustomerSubscription> subs, CustomerSubscription selectedSub) {
    final monthOptions = _generateRecentMonths();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Billing Period & Publication',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<LocalDate>(
              value: _selectedMonth,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Billing month',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              items: monthOptions.map((m) {
                final label = DateFormat('MMMM yyyy').format(DateTime(m.year, m.month));
                return DropdownMenuItem(value: m, child: Text(label));
              }).toList(),
              onChanged: _isReviewing ? null : (m) {
                if (m != null) _onMonthChanged(m);
              },
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              value: selectedSub.id,
              decoration: const InputDecoration(
                labelText: 'Publication / Subscription',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              isExpanded: true,
              items: subs.map((s) {
                final qty = s.quantity;
                final qtyLabel = qty > 1 ? ' ($qty copies)' : '';
                return DropdownMenuItem(
                  value: s.id,
                  child: Text(
                    '${s.newspaperName}$qtyLabel',
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: _isReviewing ? null : (id) {
                if (id != null) {
                  setState(() {
                    _selectedSubscriptionId = id;
                    _preview = null;
                    _isReviewing = false;
                  });
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  List<LocalDate> _generateRecentMonths() {
    final now = DateTime.now();
    return List.generate(6, (i) {
      final d = DateTime(now.year, now.month - i, 1);
      return LocalDate(d.year, d.month, 1);
    });
  }

  Widget _buildEditingSection(CustomerSubscription sub) {
    final pausesKey = (
      businessId: widget.user.businessId ?? '',
      customerId: widget.customerId,
      subscriptionId: sub.id,
    );
    final pausesAsync = ref.watch(subscriptionPausesProvider(pausesKey));
    final pauses = pausesAsync.asData?.value ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Billing calculation mode', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                SegmentedButton<ManualBillCalculationMode>(
                  segments: const [
                    ButtonSegment(value: ManualBillCalculationMode.monthWise, label: Text('Month wise')),
                    ButtonSegment(value: ManualBillCalculationMode.dayWise, label: Text('Day wise')),
                    ButtonSegment(value: ManualBillCalculationMode.dateWise, label: Text('Date wise')),
                  ],
                  selected: {_mode},
                  onSelectionChanged: (selected) {
                    setState(() {
                      _mode = selected.first;
                      _preview = null;
                      _errorMessage = null;
                    });
                  },
                ),
                const SizedBox(height: 16),
                if (_mode == ManualBillCalculationMode.monthWise) ...[
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Subscription Quantity: ${sub.quantity}',
                          style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _monthWiseController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Monthly amount (₹)',
                      prefixText: '₹ ',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ] else ...[
                  Text(
                    'Daily breakdown (${DateFormat('MMM yyyy').format(DateTime(_selectedMonth.year, _selectedMonth.month))})',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  _buildDailyEntriesList(sub, pauses),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        _buildDeliveryAndDiscountCard(),
        const SizedBox(height: 16),
        _buildSummaryCard(sub),
        if (_errorMessage != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFCA5A5)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: Color(0xFFDC2626)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Color(0xFF991B1B), fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 20),
        FilledButton.icon(
          key: const ValueKey('review-bill-action'),
          onPressed: _isBusy ? null : () => _reviewBill(sub),
          icon: _isBusy
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.fact_check_outlined),
          label: const Text('Review bill'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildDailyEntriesList(CustomerSubscription sub, List<SubscriptionPause> pauses) {
    final daysCount = _selectedMonth.daysInMonth;

    return Container(
      constraints: const BoxConstraints(maxHeight: 280),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: daysCount,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final day = index + 1;
          final date = LocalDate(_selectedMonth.year, _selectedMonth.month, day);
          final isPaused = pauses.any((p) {
            return !date.isBefore(p.startDate) && (p.endDate == null || !date.isAfter(p.endDate!));
          });
          final controller = _dayControllers[day];

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                SizedBox(
                  width: 75,
                  child: Text(
                    DateFormat('dd MMM').format(DateTime(date.year, date.month, date.day)),
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
                if (isPaused)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'Paused',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
                    ),
                  )
                else
                  const Spacer(),
                const SizedBox(width: 10),
                SizedBox(
                  width: 90,
                  child: TextFormField(
                    controller: controller,
                    enabled: !isPaused,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      prefixText: '₹ ',
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      border: const OutlineInputBorder(),
                      fillColor: isPaused ? const Color(0xFFF1F5F9) : null,
                      filled: isPaused,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDeliveryAndDiscountCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Delivery & Discounts', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _deliveryChargeController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Delivery charge',
                      prefixText: '₹ ',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _discountController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Discount',
                      prefixText: '₹ ',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(CustomerSubscription sub) {
    final subtotalPaise = _calculateSubtotalPaise(sub);
    final deliveryPaise = _calculateDeliveryChargePaise();
    final discountPaise = _calculateDiscountPaise();
    final finalBillPaise = _calculateFinalBillPaise(sub);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFCBD5E1)),
      ),
      color: const Color(0xFFF8FAFC),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _summaryRow('Subtotal', BillingMoney.formatPaise(subtotalPaise)),
            const SizedBox(height: 6),
            _summaryRow('Delivery', BillingMoney.formatPaise(deliveryPaise)),
            const SizedBox(height: 6),
            _summaryRow('Discount', '- ${BillingMoney.formatPaise(discountPaise)}'),
            const Divider(height: 20),
            _summaryRow(
              'Final bill',
              BillingMoney.formatPaise(finalBillPaise),
              isBold: true,
              fontSize: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewSection(MonthlyBillPreview preview, CustomerSubscription sub) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFF3B82F6)),
          ),
          color: const Color(0xFFEFF6FF),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.rate_review_outlined, color: Color(0xFF1D4ED8)),
                    SizedBox(width: 8),
                    Text(
                      'Bill Review & Verification',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E3A8A)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _summaryRow('Current Charges', BillingMoney.formatPaise(preview.currentChargesPaise)),
                const SizedBox(height: 6),
                _summaryRow('Prior Outstanding', BillingMoney.formatPaise(preview.priorBalancePaise)),
                const SizedBox(height: 6),
                _summaryRow('Signed Adjustments', BillingMoney.formatPaise(preview.adjustmentsPaise)),
                const Divider(height: 20),
                _summaryRow(
                  'Total Due',
                  BillingMoney.formatPaise(preview.totalDuePaise),
                  isBold: true,
                  fontSize: 18,
                  color: const Color(0xFF1E3A8A),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (preview.issues.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFCA5A5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: preview.issues.map((i) => Text('• ${i.message}', style: const TextStyle(color: Color(0xFF991B1B)))).toList(),
            ),
          ),
        if (_errorMessage != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFCA5A5)),
            ),
            child: Text(_errorMessage!, style: const TextStyle(color: Color(0xFF991B1B))),
          ),
        ],
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _isBusy ? null : () => setState(() => _isReviewing = false),
                child: const Text('Back to edit'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                key: const ValueKey('finalize-bill-action'),
                onPressed: _isBusy ? null : () => _finalizeBill(sub),
                icon: _isBusy
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check_circle_outline),
                label: const Text('Finalize bill'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildExistingBillBanner(FinalizedMonthlyBill bill) {
    return Card(
      elevation: 0,
      color: const Color(0xFFFEF3C7),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFFCD34D)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.info_outline, color: Color(0xFFB45309)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Bill already exists for this period',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'A finalized bill (${bill.billingMonth}) with total due ${BillingMoney.formatPaise(bill.totalDuePaise)} already exists. Another bill cannot be created for the same customer in this billing cycle.',
              style: const TextStyle(color: Color(0xFF78350F), fontSize: 13),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => context.push(
                '/customers/${widget.customerId}/bills/${bill.billingMonth}',
              ),
              child: const Text('View existing bill'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFinalizedSuccessCard(FinalizedMonthlyBill bill) {
    return Card(
      elevation: 0,
      color: const Color(0xFFF0FDF4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFF86EFAC)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Icon(Icons.check_circle, color: Color(0xFF16A34A), size: 48),
            const SizedBox(height: 12),
            const Text(
              'Monthly Bill Finalized!',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF15803D)),
            ),
            const SizedBox(height: 6),
            Text(
              'Bill for ${bill.billingMonth} of amount ${BillingMoney.formatPaise(bill.totalDuePaise)} has been written and ledger balances updated.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF166534), fontSize: 14),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton(
                  onPressed: () => context.go('/customers/${widget.customerId}'),
                  child: const Text('Back to customer'),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: () => context.push(
                    '/customers/${widget.customerId}/bills/${bill.billingMonth}',
                  ),
                  child: const Text('View bill details'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value, {bool isBold = false, double fontSize = 14, Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: color ?? const Color(0xFF475569),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: color ?? const Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }
}
