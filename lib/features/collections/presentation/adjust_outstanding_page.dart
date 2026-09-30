import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:paper_route/core/presentation/async_state_cards.dart';
import 'package:paper_route/features/auth/domain/access_policy.dart';
import 'package:paper_route/features/auth/domain/app_user.dart';
import 'package:paper_route/features/billing/domain/monthly_bill.dart';
import 'package:paper_route/features/collections/domain/collection_models.dart';
import 'package:paper_route/features/collections/presentation/collect_payment_page.dart';
import 'package:paper_route/features/collections/presentation/collections_providers.dart';
import 'package:paper_route/features/customers/domain/customer.dart';
import 'package:paper_route/features/customers/presentation/customer_providers.dart';
import 'package:paper_route/features/reports/presentation/reporting_providers.dart';
import 'package:uuid/uuid.dart';

class AdjustOutstandingPage extends ConsumerWidget {
  const AdjustOutstandingPage({
    required this.user,
    required this.customerId,
    this.onConfirmed,
    super.key,
  });

  final AppUser user;
  final String customerId;
  final ValueChanged<AccountAdjustmentResult>? onConfirmed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final businessId = user.businessId!;
    final customerKey = (businessId: businessId, customerId: customerId);
    final customer = ref.watch(customerProvider(customerKey));
    final outstanding = ref.watch(customerOutstandingProvider(customerKey));

    return customer.when(
      loading: () => _loadingScaffold(context),
      error:
          (error, _) => _errorScaffold(
            context,
            message: 'Could not load customer. $error',
            onRetry: () => ref.invalidate(customerProvider(customerKey)),
          ),
      data: (value) {
        if (value == null) {
          return _missingScaffold(context, 'Customer not found');
        }
        const policy = AccessPolicy();
        final canIncreaseOutstanding = policy.canIncreaseOutstanding(
          member: user,
          customerBusinessId: value.businessId,
          assignedEmployeeId: value.assignedEmployeeId,
          customerAreaId: value.areaId,
          isCustomerArchived: value.isArchived,
        );
        final canDecreaseOutstanding = policy.canDecreaseOutstanding(
          member: user,
          customerBusinessId: value.businessId,
          assignedEmployeeId: value.assignedEmployeeId,
          customerAreaId: value.areaId,
          isCustomerArchived: value.isArchived,
        );
        final canAdjust = policy.canAdjustOutstanding(
          member: user,
          customerBusinessId: value.businessId,
          assignedEmployeeId: value.assignedEmployeeId,
          customerAreaId: value.areaId,
          isCustomerArchived: value.isArchived,
        );
        if (!canAdjust) {
          return _missingScaffold(
            context,
            value.isArchived
                ? 'Collections and adjustments are disabled for archived customers.'
                : 'You are not authorized to adjust this customer.',
          );
        }
        return outstanding.when(
          loading: () => _loadingScaffold(context),
          error:
              (error, _) => _errorScaffold(
                context,
                message: 'Could not load the current outstanding. $error',
                onRetry:
                    () => ref.invalidate(
                      customerOutstandingProvider(customerKey),
                    ),
              ),
          data:
              (summary) => _AdjustOutstandingForm(
                user: user,
                customer: value,
                summary: summary,
                canIncreaseOutstanding: canIncreaseOutstanding,
                canDecreaseOutstanding: canDecreaseOutstanding,
                onConfirmed: onConfirmed,
              ),
        );
      },
    );
  }

  Scaffold _loadingScaffold(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: BackButton(onPressed: () => _back(context)),
      title: const Text('Adjust outstanding'),
    ),
    body: const Center(child: CircularProgressIndicator()),
  );

  Scaffold _errorScaffold(
    BuildContext context, {
    required String message,
    required VoidCallback onRetry,
  }) => Scaffold(
    appBar: AppBar(
      leading: BackButton(onPressed: () => _back(context)),
      title: const Text('Adjust outstanding'),
    ),
    body: Padding(
      padding: const EdgeInsets.all(20),
      child: AsyncErrorCard(message: message, onRetry: onRetry),
    ),
  );

  Scaffold _missingScaffold(BuildContext context, String message) => Scaffold(
    appBar: AppBar(
      leading: BackButton(onPressed: () => _back(context)),
      title: const Text('Adjust outstanding'),
    ),
    body: Padding(
      padding: const EdgeInsets.all(20),
      child: EmptyStateCard(
        icon: Icons.lock_outline,
        title: 'Adjustment unavailable',
        message: message,
      ),
    ),
  );

  void _back(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/customers/$customerId');
    }
  }
}

class _AdjustOutstandingForm extends ConsumerStatefulWidget {
  const _AdjustOutstandingForm({
    required this.user,
    required this.customer,
    required this.summary,
    required this.canIncreaseOutstanding,
    required this.canDecreaseOutstanding,
    required this.onConfirmed,
  });

  final AppUser user;
  final Customer customer;
  final CustomerOutstandingSummary summary;
  final bool canIncreaseOutstanding;
  final bool canDecreaseOutstanding;
  final ValueChanged<AccountAdjustmentResult>? onConfirmed;

  @override
  ConsumerState<_AdjustOutstandingForm> createState() =>
      _AdjustOutstandingFormState();
}

class _AdjustOutstandingFormState
    extends ConsumerState<_AdjustOutstandingForm> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _reasonController = TextEditingController();
  late AdjustmentDirection _direction;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _direction =
        widget.canIncreaseOutstanding
            ? AdjustmentDirection.increase
            : AdjustmentDirection.decrease;
    _amountController.addListener(_onFormChanged);
  }

  @override
  void dispose() {
    _amountController.removeListener(_onFormChanged);
    _amountController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  void _onFormChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final customer = widget.customer;
    final summary = widget.summary;
    final hasOutstanding = summary.amountDuePaise > 0;
    final canDecrease = widget.canDecreaseOutstanding && hasOutstanding;
    final canIncrease = widget.canIncreaseOutstanding;
    final canAdjust = canIncrease || canDecrease;

    final parsedPaise = _tryParseAmount(_amountController.text);
    final currentOutstandingPaise = summary.amountDuePaise;

    int calculatedNewOutstandingPaise;
    if (parsedPaise == null || parsedPaise <= 0) {
      calculatedNewOutstandingPaise = currentOutstandingPaise;
    } else if (_direction == AdjustmentDirection.increase) {
      calculatedNewOutstandingPaise = currentOutstandingPaise + parsedPaise;
    } else {
      calculatedNewOutstandingPaise =
          (currentOutstandingPaise - parsedPaise).clamp(0, 999999999999);
    }

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(
          onPressed:
              () =>
                  context.canPop()
                      ? context.pop()
                      : context.go('/customers/${customer.id}'),
        ),
        title: const Text('Adjust outstanding'),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
          children: [
            Text(
              customer.name,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              '${customer.customerCode}\n${customer.addressSummary}',
              style: const TextStyle(color: Color(0xFF486581), height: 1.4),
            ),
            const SizedBox(height: 14),
            Card(
              color: const Color(0xFFE5F5EE),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Current outstanding',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFC6F6D5),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Posted bills',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF22543D),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      BillingMoney.formatPaise(summary.amountDuePaise),
                      key: const ValueKey('collection-outstanding'),
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 6),
                    const Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 14,
                          color: Color(0xFF486581),
                        ),
                        SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'Estimated unbilled charges are excluded until month-end finalization.',
                            style: TextStyle(
                              color: Color(0xFF486581),
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (summary.creditPaise > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Customer credit: ${BillingMoney.formatPaise(summary.creditPaise)}',
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            if (widget.canDecreaseOutstanding && !canDecrease && !canIncrease)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'There is no outstanding balance to decrease.',
                    key: ValueKey('no-outstanding-to-decrease'),
                    style: TextStyle(color: Color(0xFF486581)),
                  ),
                ),
              )
            else if (!canAdjust)
              const EmptyStateCard(
                icon: Icons.lock_outline,
                title: 'Adjustment unavailable',
                message: 'You do not have permission to adjust this customer.',
              )
            else
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SegmentedButton<AdjustmentDirection>(
                      segments: [
                        if (canIncrease)
                          const ButtonSegment(
                            value: AdjustmentDirection.increase,
                            label: Text('Increase'),
                            icon: Icon(Icons.add_circle_outline),
                          ),
                        if (canDecrease)
                          const ButtonSegment(
                            value: AdjustmentDirection.decrease,
                            label: Text('Decrease'),
                            icon: Icon(Icons.remove_circle_outline),
                          ),
                      ],
                      selected: {_direction},
                      onSelectionChanged: (newSelection) {
                        setState(() {
                          _direction = newSelection.first;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      key: const ValueKey('adjustment-amount'),
                      controller: _amountController,
                      enabled: !_submitting,
                      decoration: const InputDecoration(
                        labelText: 'Adjustment amount (₹)',
                        prefixText: '₹ ',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      textInputAction: TextInputAction.next,
                      validator: _validateAmount,
                    ),
                    const SizedBox(height: 14),
                    Card(
                      key: const ValueKey('adjustment-calculation'),
                      color: const Color(0xFFF0F4F8),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Current outstanding: ${BillingMoney.formatPaise(currentOutstandingPaise)}',
                              style: const TextStyle(
                                color: Color(0xFF486581),
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _direction == AdjustmentDirection.increase
                                  ? 'Adjustment: +${BillingMoney.formatPaise(parsedPaise ?? 0)}'
                                  : 'Adjustment: -${BillingMoney.formatPaise(parsedPaise ?? 0)}',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color:
                                    _direction == AdjustmentDirection.increase
                                        ? Colors.amber.shade900
                                        : Colors.teal.shade800,
                                fontSize: 14,
                              ),
                            ),
                            const Divider(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'New outstanding:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                Text(
                                  BillingMoney.formatPaise(
                                    calculatedNewOutstandingPaise,
                                  ),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Color(0xFF102A43),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      key: const ValueKey('adjustment-reason'),
                      controller: _reasonController,
                      enabled: !_submitting,
                      decoration: const InputDecoration(
                        labelText: 'Reason',
                        hintText: 'e.g. Prior unbilled dues / manual arrears',
                      ),
                      maxLength: 300,
                      minLines: 2,
                      maxLines: 4,
                      validator: (value) {
                        final text = value?.trim() ?? '';
                        if (text.length < 3) {
                          return 'Enter a reason with at least 3 characters.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      key: const ValueKey('submit-adjustment'),
                      onPressed: _submitting ? null : _submitAdjustment,
                      icon:
                          _submitting
                              ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                              : const Icon(Icons.check_circle_outline),
                      label: Text(
                        _submitting ? 'Saving with server…' : 'Save adjustment',
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  int? _tryParseAmount(String raw) {
    try {
      final text = raw.trim();
      if (text.isEmpty || text.startsWith('-')) return null;
      return parseRupeesToPaise(text);
    } catch (_) {
      return null;
    }
  }

  String? _validateAmount(String? raw) {
    final text = raw?.trim() ?? '';
    if (text.isEmpty) return 'Enter an adjustment amount in ₹.';
    if (text.startsWith('-')) return 'Enter a positive amount.';
    try {
      final paise = parseRupeesToPaise(text);
      if (paise <= 0) return 'Enter a positive amount.';
      if (_direction == AdjustmentDirection.decrease) {
        if (paise > widget.summary.amountDuePaise) {
          return 'Decrease amount cannot exceed current outstanding.';
        }
      }
      return null;
    } on FormatException {
      return 'Enter rupees with up to two decimal places.';
    }
  }

  Future<void> _submitAdjustment() async {
    if (_submitting) return;
    if (!_formKey.currentState!.validate()) return;

    final amountPaise = parseRupeesToPaise(_amountController.text.trim());
    final reason = _reasonController.text.trim();
    final now = DateTime.now();
    final billingMonth = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final idempotencyKey = const Uuid().v4();

    setState(() => _submitting = true);

    try {
      final result = await ref
          .read(collectionsRepositoryProvider)
          .recordAccountAdjustment(
            actor: widget.user,
            customerId: widget.customer.id,
            input: AccountAdjustmentInput(
              amountPaise: amountPaise,
              direction: _direction,
              reason: reason,
              billingMonth: billingMonth,
              idempotencyKey: idempotencyKey,
            ),
          );

      if (mounted) {
        final businessId = widget.user.businessId!;
        final customerKey = (
          businessId: businessId,
          customerId: widget.customer.id,
        );
        ref.invalidate(customerOutstandingProvider(customerKey));
        ref.invalidate(operationalDashboardProvider(widget.user));

        widget.onConfirmed?.call(result);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Adjusted outstanding by ${BillingMoney.formatPaise(amountPaise)}.',
              ),
            ),
          );
          if (widget.onConfirmed == null) {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/customers/${widget.customer.id}');
            }
          }
        }
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}
