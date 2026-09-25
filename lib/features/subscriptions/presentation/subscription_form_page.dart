import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:paper_route/core/domain/local_date.dart';
import 'package:paper_route/core/errors/app_exception.dart';
import 'package:paper_route/core/presentation/async_state_cards.dart';
import 'package:paper_route/features/auth/domain/access_policy.dart';
import 'package:paper_route/features/auth/domain/app_user.dart';
import 'package:paper_route/features/customers/domain/customer.dart';
import 'package:paper_route/features/customers/presentation/customer_providers.dart';
import 'package:paper_route/features/newspapers/domain/newspaper.dart';
import 'package:paper_route/features/newspapers/presentation/newspaper_providers.dart';
import 'package:paper_route/features/subscriptions/domain/customer_subscription.dart';
import 'package:paper_route/features/subscriptions/presentation/subscription_providers.dart';

class SubscriptionFormRoutePage extends ConsumerWidget {
  const SubscriptionFormRoutePage({
    required this.user,
    required this.customerId,
    this.subscriptionId,
    super.key,
  });

  final AppUser user;
  final String customerId;
  final String? subscriptionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customerKey = (businessId: user.businessId!, customerId: customerId);
    final customer = ref.watch(customerProvider(customerKey));
    final id = subscriptionId;
    final subscriptionKey =
        id == null
            ? null
            : (
              businessId: user.businessId!,
              customerId: customerId,
              subscriptionId: id,
            );
    final subscription =
        subscriptionKey == null
            ? const AsyncData<CustomerSubscription?>(null)
            : ref.watch(customerSubscriptionProvider(subscriptionKey));

    if (customer.isLoading || subscription.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (customer.hasError || subscription.hasError) {
      final error = customer.error ?? subscription.error;
      return Scaffold(
        appBar: AppBar(title: const Text('Subscription')),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: AsyncErrorCard(
            message: 'Could not load the subscription form. $error',
            onRetry: () {
              ref.invalidate(customerProvider(customerKey));
              if (subscriptionKey != null) {
                ref.invalidate(customerSubscriptionProvider(subscriptionKey));
              }
            },
          ),
        ),
      );
    }
    final customerValue = customer.value;
    final subscriptionValue = subscription.value;
    if (customerValue == null || (id != null && subscriptionValue == null)) {
      return Scaffold(
        appBar: AppBar(title: const Text('Subscription')),
        body: const Padding(
          padding: EdgeInsets.all(20),
          child: EmptyStateCard(
            icon: Icons.event_busy_outlined,
            title: 'Subscription unavailable',
            message: 'The customer or subscription no longer exists.',
          ),
        ),
      );
    }
    return SubscriptionFormPage(
      user: user,
      customer: customerValue,
      subscription: subscriptionValue,
    );
  }
}

class SubscriptionFormPage extends ConsumerStatefulWidget {
  const SubscriptionFormPage({
    required this.user,
    required this.customer,
    this.subscription,
    super.key,
  });

  final AppUser user;
  final Customer customer;
  final CustomerSubscription? subscription;

  @override
  ConsumerState<SubscriptionFormPage> createState() =>
      _SubscriptionFormPageState();
}

class _SubscriptionFormPageState extends ConsumerState<SubscriptionFormPage> {
  static const _policy = AccessPolicy();
  final _formKey = GlobalKey<FormState>();
  final _start = TextEditingController();
  final _end = TextEditingController();
  final _quantity = TextEditingController(text: '1');
  final _customPrice = TextEditingController();
  final _customPriceReason = TextEditingController();
  Set<int> _weekdays = {...DeliveryWeekday.all};
  List<Newspaper> _newspapers = const [];
  String _newspaperId = '';
  bool _loadingNewspapers = true;
  bool _isBusy = false;
  String? _loadError;

  bool get _isChanging => widget.subscription != null;
  bool get _isRestarting => widget.subscription?.isEnded ?? false;

  @override
  void initState() {
    super.initState();
    final current = widget.subscription;
    if (current != null) {
      _newspaperId = current.newspaperId;
      _quantity.text = current.quantity.toString();
      _start.text = (current.isEnded ? LocalDate.fromDateTime(DateTime.now()) : current.startDate).toString();
      // An ended subscription's end date belongs to its closed history. A
      // restart is a new service period and must not inherit that old date as
      // its planned end.
      _end.text = current.isEnded ? '' : current.endDate?.toString() ?? '';
      _weekdays = {...current.deliveryWeekdays};
      _customPrice.text =
          current.customPricePaise == null
              ? ''
              : NewspaperMoney.formatPaiseForInput(current.customPricePaise!);
      _customPriceReason.text = current.customPriceReason;
    } else {
      _start.text = LocalDate.fromDateTime(DateTime.now()).toString();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadNewspapers());
  }

  @override
  void dispose() {
    _start.dispose();
    _end.dispose();
    _quantity.dispose();
    _customPrice.dispose();
    _customPriceReason.dispose();
    super.dispose();
  }

  Future<void> _loadNewspapers() async {
    setState(() {
      _loadingNewspapers = true;
      _loadError = null;
    });
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
      if (!mounted) return;
      final papers = [...page.newspapers];
      final current = widget.subscription;
      if (current != null &&
          !papers.any((paper) => paper.id == current.newspaperId)) {
        // Archived publications remain visible for historical subscriptions.
        final archived = await ref
            .read(newspaperRepositoryProvider)
            .fetchNewspapers(
              NewspaperListRequest(
                businessId: widget.user.businessId!,
                requesterId: widget.user.uid,
                status: NewspaperStatus.archived,
                pageSize: 50,
              ),
            );
        papers.addAll(
          archived.newspapers.where((paper) => paper.id == current.newspaperId),
        );
      }
      final uniqueMap = <String, Newspaper>{};
      for (final p in papers) {
        uniqueMap.putIfAbsent(p.id, () => p);
      }
      final deduplicated = uniqueMap.values.toList();
      setState(() {
        _newspapers = deduplicated;
        _newspaperId =
            current?.newspaperId ??
            (_newspaperId.isNotEmpty
                ? _newspaperId
                : (deduplicated.isEmpty ? '' : deduplicated.first.id));
      });
    } on Object catch (error) {
      if (mounted) setState(() => _loadError = error.toString());
    } finally {
      if (mounted) setState(() => _loadingNewspapers = false);
    }
  }

  LocalDate? _tryParseDate(String text) {
    try {
      return LocalDate.parse(text);
    } catch (_) {
      return null;
    }
  }

  Future<void> _pickStartDate() async {
    final initial = _start.text.trim().isNotEmpty
        ? (_tryParseDate(_start.text.trim())?.toDateTime() ?? DateTime.now())
        : DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      final selectedLocalDate = LocalDate.fromDateTime(picked);
      setState(() {
        _start.text = selectedLocalDate.toString();
        if (_end.text.trim().isNotEmpty) {
          final currentEnd = _tryParseDate(_end.text.trim());
          if (currentEnd != null && currentEnd.isBefore(selectedLocalDate)) {
            _end.clear();
          }
        }
      });
    }
  }

  Future<void> _pickEndDate() async {
    final startDate = _tryParseDate(_start.text.trim());
    final now = DateTime.now();
    final minDate = startDate != null ? startDate.toDateTime() : DateTime(2000);
    DateTime initial = _end.text.trim().isNotEmpty
        ? (_tryParseDate(_end.text.trim())?.toDateTime() ?? now)
        : (startDate != null && startDate.toDateTime().isAfter(now)
            ? startDate.toDateTime()
            : now);
    if (initial.isBefore(minDate)) {
      initial = minDate;
    }
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: minDate,
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _end.text = LocalDate.fromDateTime(picked).toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final allowed = _policy.canManageSubscription(
      member: widget.user,
      customerBusinessId: widget.customer.businessId,
      assignedEmployeeId: widget.customer.assignedEmployeeId,
      customerAreaId: widget.customer.areaId,
      isCustomerArchived: widget.customer.isArchived,
    );
    if (!allowed) {
      return Scaffold(
        appBar: AppBar(title: const Text('Subscription')),
        body: const Padding(
          padding: EdgeInsets.all(20),
          child: EmptyStateCard(
            icon: Icons.lock_outline,
            title: 'Subscription action unavailable',
            message:
                'Your role, permission, assignment, or the customer status does not allow this change.',
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: _back),
        title: Text(
          _isRestarting
              ? 'Restart subscription'
              : _isChanging
              ? 'Change subscription terms'
              : 'New subscription',
        ),
      ),
      body: SafeArea(
        top: false,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
            children: [
              Text(
                widget.customer.name,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _isChanging
                    ? 'Existing terms remain in immutable version history. Enter the date on which the new terms begin.'
                    : 'Each newspaper has one stable subscription series. Later changes create dated versions.',
                style: const TextStyle(color: Color(0xFF486581), height: 1.4),
              ),
              const SizedBox(height: 20),
              if (_loadingNewspapers)
                const Center(child: CircularProgressIndicator())
              else if (_loadError != null)
                AsyncErrorCard(
                  message: 'Could not load active newspapers. $_loadError',
                  onRetry: _loadNewspapers,
                )
              else if (_newspapers.isEmpty)
                const EmptyStateCard(
                  icon: Icons.newspaper_outlined,
                  title: 'No active newspapers',
                  message:
                      'The Head must create an active catalog publication before adding a subscription.',
                )
              else
                DropdownButtonFormField<String>(
                  value: _newspaperId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Newspaper'),
                  items: [
                    for (final newspaper in _newspapers)
                      DropdownMenuItem(
                        value: newspaper.id,
                        child: Text(
                          newspaper.displayName,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged:
                      _isChanging
                          ? null
                          : (value) =>
                              setState(() => _newspaperId = value ?? ''),
                ),
              const SizedBox(height: 14),
              TextFormField(
                key: const ValueKey('subscription-start-date-field'),
                controller: _start,
                decoration: InputDecoration(
                  labelText:
                      _isChanging
                          ? 'New terms effective date'
                          : 'Subscription start date',
                  hintText: 'YYYY-MM-DD',
                  helperText: 'Calendar date only; no time zone is stored.',
                  suffixIcon: IconButton(
                    key: const ValueKey('subscription-start-date-picker-button'),
                    icon: const Icon(Icons.calendar_today_outlined),
                    tooltip: 'Select start date',
                    onPressed: _pickStartDate,
                  ),
                ),
                validator: _requiredDate,
              ),
              const SizedBox(height: 14),
              TextFormField(
                key: const ValueKey('subscription-end-date-field'),
                controller: _end,
                decoration: InputDecoration(
                  labelText: 'Planned end date (optional)',
                  hintText: 'YYYY-MM-DD',
                  suffixIcon: _end.text.isNotEmpty
                      ? IconButton(
                          key: const ValueKey('clear-planned-end-date'),
                          icon: const Icon(Icons.clear),
                          tooltip: 'Clear planned end date',
                          onPressed: () => setState(() => _end.clear()),
                        )
                      : IconButton(
                          key: const ValueKey('subscription-end-date-picker-button'),
                          icon: const Icon(Icons.calendar_today_outlined),
                          tooltip: 'Select planned end date',
                          onPressed: _pickEndDate,
                        ),
                ),
                validator: _optionalDate,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _quantity,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Daily quantity'),
                validator: (value) {
                  final parsed = int.tryParse(value?.trim() ?? '');
                  return parsed == null || parsed < 1 || parsed > 50
                      ? 'Enter a quantity between 1 and 50.'
                      : null;
                },
              ),
              const SizedBox(height: 20),
              Text(
                'Delivery weekdays',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final entry in DeliveryWeekday.labels.entries)
                    FilterChip(
                      label: Text(entry.value),
                      selected: _weekdays.contains(entry.key),
                      onSelected:
                          (selected) => setState(() {
                            selected
                                ? _weekdays.add(entry.key)
                                : _weekdays.remove(entry.key);
                          }),
                    ),
                ],
              ),
              if (_weekdays.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Select at least one delivery weekday.',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              const SizedBox(height: 22),
              if (widget.user.isHead) ...[
                Text(
                  'Customer-specific price exception',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Optional. This Head-authorized fixed unit price takes precedence over catalog prices until terms change.',
                  style: TextStyle(color: Color(0xFF486581), height: 1.4),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _customPrice,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Fixed unit price (₹, optional)',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _customPriceReason,
                  maxLength: 200,
                  decoration: const InputDecoration(
                    labelText: 'Authorization reason',
                  ),
                ),
              ] else if (_isChanging &&
                  widget.subscription!.customPricePaise != null) ...[
                const Text(
                  'The existing Head-authorized customer price will be preserved. Employees cannot change privileged pricing.',
                  style: TextStyle(color: Color(0xFF486581), height: 1.4),
                ),
              ],
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed:
                    _isBusy || _loadingNewspapers || _newspapers.isEmpty
                        ? null
                        : _submit,
                icon:
                    _isBusy
                        ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Icon(Icons.save_outlined),
                label: Text(
                  _isRestarting
                      ? 'Restart subscription'
                      : _isChanging
                      ? 'Save as new terms version'
                      : 'Create subscription',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _requiredDate(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Enter a date.';
    try {
      LocalDate.parse(text);
      return null;
    } on FormatException {
      return 'Use a real calendar date in YYYY-MM-DD format.';
    }
  }

  String? _optionalDate(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    final parseResult = _requiredDate(text);
    if (parseResult != null) return parseResult;
    final end = _tryParseDate(text);
    final start = _tryParseDate(_start.text.trim());
    if (end != null && start != null && end.isBefore(start)) {
      return 'Subscription end date cannot be before its start date.';
    }
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _weekdays.isEmpty) return;
    setState(() => _isBusy = true);
    try {
      final current = widget.subscription;
      final effectiveFrom = LocalDate.parse(_start.text.trim());
      final customPrice =
          widget.user.isHead
              ? (_customPrice.text.trim().isEmpty
                  ? null
                  : NewspaperMoney.parseRupeesToPaise(_customPrice.text))
              : current?.customPricePaise;
      final customReason =
          widget.user.isHead
              ? _customPriceReason.text
              : (current?.customPriceReason ?? '');
      final input = SubscriptionInput(
        newspaperId: _newspaperId,
        startDate:
            current == null || current.isEnded
                ? effectiveFrom
                : current.startDate,
        endDate:
            _end.text.trim().isEmpty ? null : LocalDate.parse(_end.text.trim()),
        quantity: int.parse(_quantity.text.trim()),
        deliveryWeekdays: _weekdays,
        customPricePaise: customPrice,
        customPriceReason: customReason,
      );
      input.validate();
      final repository = ref.read(subscriptionRepositoryProvider);
      if (current == null) {
        final id = await repository.createSubscription(
          actor: widget.user,
          customerId: widget.customer.id,
          input: input,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Subscription $id created.')));
      } else {
        await repository.replaceTerms(
          actor: widget.user,
          customerId: widget.customer.id,
          subscriptionId: current.id,
          effectiveFrom: effectiveFrom,
          replacement: input,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              current.isEnded
                  ? 'Subscription restarted with a new history version.'
                  : 'New subscription terms saved without rewriting history.',
            ),
          ),
        );
      }
      _back(result: true);
    } on AppException catch (error) {
      _showError(error.message);
    } on Object catch (error) {
      _showError(error.toString());
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  void _back({bool result = false}) {
    if (context.canPop()) {
      context.pop(result);
    } else {
      context.go('/customers/${Uri.encodeComponent(widget.customer.id)}');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
