import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:paper_route/core/domain/local_date.dart';
import 'package:paper_route/core/presentation/async_state_cards.dart';
import 'package:paper_route/features/areas/domain/delivery_area.dart';
import 'package:paper_route/features/areas/presentation/area_providers.dart';
import 'package:paper_route/features/auth/domain/access_policy.dart';
import 'package:paper_route/features/auth/domain/app_user.dart';
import 'package:paper_route/features/customers/domain/customer.dart';
import 'package:paper_route/features/customers/presentation/customer_providers.dart';
import 'package:paper_route/features/delivery/domain/route_order.dart';
import 'package:paper_route/features/delivery/presentation/delivery_providers.dart';
import 'package:paper_route/features/employees/domain/employee_member.dart';
import 'package:paper_route/features/employees/presentation/employee_providers.dart';
import 'package:paper_route/features/newspapers/domain/newspaper.dart';
import 'package:paper_route/features/newspapers/presentation/newspaper_providers.dart';
import 'package:paper_route/features/subscriptions/domain/customer_subscription.dart';
import 'package:paper_route/features/subscriptions/presentation/subscription_providers.dart';
import 'package:paper_route/l10n/app_localizations.dart';

class CustomerFormRoutePage extends ConsumerWidget {
  const CustomerFormRoutePage({required this.user, this.customerId, super.key});

  final AppUser user;
  final String? customerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = customerId;
    if (id == null) return CustomerFormPage(user: user);
    final key = (businessId: user.businessId!, customerId: id);
    final customer = ref.watch(customerProvider(key));
    final l10n = AppLocalizations.of(context);
    return customer.when(
      loading:
          () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
      error:
          (error, _) => Scaffold(
            appBar: AppBar(
              title: Text(l10n?.customerEditTitle ?? 'Edit Customer'),
            ),
            body: Padding(
              padding: const EdgeInsets.all(20),
              child: AsyncErrorCard(
                message: 'Could not load customer. $error',
                onRetry: () => ref.invalidate(customerProvider(key)),
              ),
            ),
          ),
      data:
          (value) =>
              value == null
                  ? Scaffold(
                    appBar: AppBar(
                      title: Text(l10n?.customerEditTitle ?? 'Edit Customer'),
                    ),
                    body: Padding(
                      padding: const EdgeInsets.all(20),
                      child: EmptyStateCard(
                        icon: Icons.person_off_outlined,
                        title: l10n?.customerNotFound ?? 'Customer not found',
                        message:
                            l10n?.customerNotFoundMessage ??
                            'The record may no longer be available.',
                      ),
                    ),
                  )
                  : CustomerFormPage(user: user, customer: value),
    );
  }
}

class CustomerFormPage extends ConsumerStatefulWidget {
  const CustomerFormPage({
    required this.user,
    this.customer,
    this.isQuickAdd = false,
    super.key,
  });

  final AppUser user;
  final Customer? customer;
  final bool isQuickAdd;

  @override
  ConsumerState<CustomerFormPage> createState() => _CustomerFormPageState();
}

class _CustomerFormPageState extends ConsumerState<CustomerFormPage> {
  static const _accessPolicy = AccessPolicy();
  final _formKey = GlobalKey<FormState>();
  final _nameFocus = FocusNode();

  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _alternatePhone;
  late final TextEditingController _address;
  late final TextEditingController _landmark;
  late final TextEditingController _houseNumber;
  late final TextEditingController _buildingInfo;
  late final TextEditingController _locationNotes;
  late final TextEditingController _latitude;
  late final TextEditingController _longitude;
  late final TextEditingController _openingBalance;
  late final TextEditingController _notes;

  late String _areaId;
  late String _employeeId;
  late bool _locationConsent;
  late DeliveryPlacement _deliveryPlacement;
  late BillingCyclePreference _billingCycle;
  RoutePlacement _routePlacement = RoutePlacement.last;
  String? _afterCustomerId;
  bool _isBusy = false;

  // Phase 3 Quick Add & Subscription state
  late bool _quickAddMode;
  String? _selectedNewspaperId;
  int _subscriptionQuantity = 1;

  bool get _isEditing => widget.customer != null;

  @override
  void initState() {
    super.initState();
    _quickAddMode = widget.isQuickAdd;
    final customer = widget.customer;
    _name = TextEditingController(text: customer?.name ?? '');
    _phone = TextEditingController(text: customer?.phone ?? '');
    _alternatePhone = TextEditingController(
      text: customer?.alternatePhone ?? '',
    );
    _address = TextEditingController(text: customer?.address ?? '');
    _landmark = TextEditingController(text: customer?.landmark ?? '');
    _houseNumber = TextEditingController(text: customer?.houseNumber ?? '');
    _buildingInfo = TextEditingController(text: customer?.buildingInfo ?? '');
    _locationNotes = TextEditingController(text: customer?.locationNotes ?? '');
    _latitude = TextEditingController(
      text: customer?.coordinates?.latitude.toString() ?? '',
    );
    _longitude = TextEditingController(
      text: customer?.coordinates?.longitude.toString() ?? '',
    );
    _openingBalance = TextEditingController(
      text: CustomerMoney.formatPaiseForInput(
        customer?.openingBalancePaise ?? 0,
      ),
    );
    _notes = TextEditingController(text: customer?.notes ?? '');
    _areaId = customer?.areaId ?? '';
    _employeeId =
        customer?.assignedEmployeeId ??
        (widget.user.isHead ? '' : widget.user.uid);
    _locationConsent = customer?.locationConsent ?? false;
    _deliveryPlacement =
        customer?.deliveryPlacement ?? DeliveryPlacement.doorstep;
    _billingCycle = customer?.billingCycle ?? BillingCyclePreference.monthly;

    if (_isEditing) {
      _quickAddMode = false;
    }
  }

  @override
  void dispose() {
    _nameFocus.dispose();
    for (final controller in [
      _name,
      _phone,
      _alternatePhone,
      _address,
      _landmark,
      _houseNumber,
      _buildingInfo,
      _locationNotes,
      _latitude,
      _longitude,
      _openingBalance,
      _notes,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final existing = widget.customer;
    final allowed =
        existing == null
            ? _accessPolicy.canCreateCustomer(widget.user)
            : _accessPolicy.canEditCustomer(
              member: widget.user,
              customerBusinessId: existing.businessId,
              assignedEmployeeId: existing.assignedEmployeeId,
              isArchived: existing.isArchived,
            );
    if (!allowed) {
      return Scaffold(
        appBar: AppBar(
          title: Text(_isEditing ? 'Edit customer' : 'New customer'),
        ),
        body: const Padding(
          padding: EdgeInsets.all(20),
          child: EmptyStateCard(
            icon: Icons.lock_outline,
            title: 'Customer action unavailable',
            message:
                'Your current role, assignment, or permissions do not allow this action.',
          ),
        ),
      );
    }

    final businessId = widget.user.businessId!;
    final areas = ref.watch(deliveryAreasProvider(businessId));
    final members =
        widget.user.isHead && !_isEditing
            ? ref.watch(employeeMembersProvider(businessId))
            : const AsyncData<List<EmployeeMember>>([]);
    final areaItems =
        (areas.asData?.value ?? const <DeliveryArea>[])
            .where(
              (area) =>
                  area.isActive &&
                  (widget.user.isHead || widget.user.areaIds.contains(area.id)),
            )
            .toList();
    final memberItems =
        (members.asData?.value ?? const <EmployeeMember>[])
            .where((member) => member.isEmployee && member.isActive)
            .toList();

    final newspapersAsync = ref.watch(
      activeNewspapersListProvider((
        businessId: businessId,
        requesterId: widget.user.uid,
      ),),
    );
    final newspapers = newspapersAsync.asData?.value ?? const <Newspaper>[];

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(
          onPressed:
              () =>
                  context.canPop() ? context.pop() : context.go('/customers'),
        ),
        title: Text(
          _isEditing
              ? 'Edit customer'
              : (_quickAddMode ? 'Quick Add Customer' : 'New customer'),
        ),
        actions: [
          if (!_isEditing)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton.icon(
                onPressed: () => setState(() => _quickAddMode = !_quickAddMode),
                icon: Icon(
                  _quickAddMode
                      ? Icons.tune_rounded
                      : Icons.bolt_rounded,
                  size: 18,
                ),
                label: Text(_quickAddMode ? 'Detailed Mode' : 'Quick Add'),
              ),
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
            children: [
              Text(
                _isEditing
                    ? existing!.name
                    : (_quickAddMode
                        ? 'Quick Customer Onboarding'
                        : 'Customer profile'),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _isEditing
                    ? 'Customer ID ${existing!.customerCode} is permanent. Assignment and status have separate audited actions.'
                    : (_quickAddMode
                        ? 'Minimal fields for rapid customer entry. Sticky area & publications are retained on Save & Add Next.'
                        : 'A permanent customer ID is generated when this record is saved.'),
                style: const TextStyle(color: Color(0xFF486581), height: 1.4),
              ),
              const SizedBox(height: 16),

              // Identity & Contact Card
              _SectionCard(
                title: 'Identity and contact',
                children: [
                  TextFormField(
                    focusNode: _nameFocus,
                    controller: _name,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Customer name',
                    ),
                    validator: _requiredText,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Primary phone',
                      hintText: 'Optional',
                    ),
                    validator: _optionalPhone,
                  ),
                  if (!_quickAddMode) ...[
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _alternatePhone,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Alternate phone (optional)',
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 14),

              // House & Address Card
              _SectionCard(
                title: 'Address and physical location',
                children: [
                  TextFormField(
                    controller: _houseNumber,
                    decoration: const InputDecoration(
                      labelText: 'House / Flat number',
                      hintText: 'e.g. 402, B-12, A-Block',
                    ),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<DeliveryPlacement>(
                    key: const ValueKey('delivery-placement-dropdown'),
                    value: _deliveryPlacement,
                    decoration: const InputDecoration(
                      labelText: 'Delivery placement point',
                    ),
                    items: [
                      for (final p in DeliveryPlacement.values)
                        DropdownMenuItem(
                          value: p,
                          child: Text(p.label),
                        ),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _deliveryPlacement = val);
                    },
                  ),
                  if (!_quickAddMode) ...[
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _buildingInfo,
                      decoration: const InputDecoration(
                        labelText: 'Building / floor details (optional)',
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _address,
                      minLines: 2,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Full address',
                      ),
                      validator: _requiredText,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _landmark,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Recognizable landmark',
                      ),
                      validator: _requiredText,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _locationNotes,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Location-identification notes (optional)',
                        hintText: 'Gate colour, side lane, delivery point…',
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 14),

              // Area and Route Placement Card
              _SectionCard(
                title: 'Area and route placement',
                children: [
                  if (_isEditing) ...[
                    _ReadOnlyValue(
                      label: 'Delivery area ID',
                      value: existing!.areaId,
                    ),
                    const SizedBox(height: 10),
                    _ReadOnlyValue(
                      label: 'Assigned employee ID',
                      value:
                          existing.assignedEmployeeId.isEmpty
                              ? 'Unassigned'
                              : existing.assignedEmployeeId,
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Use Change assignment on the customer detail screen to transfer the customer.',
                      style: TextStyle(color: Color(0xFF486581)),
                    ),
                  ] else if (areas.isLoading)
                    const Center(child: CircularProgressIndicator())
                  else if (areas.hasError)
                    Text(
                      'Could not load delivery areas: ${areas.error}',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    )
                  else if (areaItems.isEmpty)
                    const Text(
                      'No permitted active area is available. A Head must create and assign an area first.',
                      style: TextStyle(color: Color(0xFF9B5C00)),
                    )
                  else ...[
                    DropdownButtonFormField<String>(
                      key: const ValueKey('customer-area-dropdown'),
                      value:
                          areaItems.any((area) => area.id == _areaId)
                              ? _areaId
                              : '',
                      decoration: const InputDecoration(
                        labelText: 'Delivery area',
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: '',
                          child: Text('Select an area'),
                        ),
                        for (final area in areaItems)
                          DropdownMenuItem(
                            value: area.id,
                            child: Text(area.name),
                          ),
                      ],
                      validator:
                          (value) =>
                              value == null || value.isEmpty
                                  ? 'Select a delivery area.'
                                  : null,
                      onChanged:
                          (value) => setState(() {
                            _areaId = value ?? '';
                            if (!_employeesForArea(
                              memberItems,
                            ).any((employee) => employee.uid == _employeeId)) {
                              _employeeId =
                                  widget.user.isHead ? '' : widget.user.uid;
                            }
                          }),
                    ),
                    if (widget.user.isHead && !_quickAddMode) ...[
                      const SizedBox(height: 14),
                      if (members.isLoading)
                        const Center(child: CircularProgressIndicator())
                      else if (members.hasError)
                        Text(
                          'Could not load employees: ${members.error}',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        )
                      else
                        DropdownButtonFormField<String>(
                          value:
                              memberItems.any(
                                    (member) => member.uid == _employeeId,
                                  )
                                  ? _employeeId
                                  : '',
                          decoration: const InputDecoration(
                            labelText: 'Assigned employee (optional)',
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: '',
                              child: Text('Leave unassigned for now'),
                            ),
                            for (final member in _employeesForArea(memberItems))
                              DropdownMenuItem(
                                value: member.uid,
                                child: Text(member.displayName),
                              ),
                          ],
                          onChanged:
                              (value) =>
                                  setState(() => _employeeId = value ?? ''),
                        ),
                    ] else if (!widget.user.isHead)
                      const Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: Text(
                          'This customer will be assigned to you. Firestore verifies the selected area against your membership.',
                          style: TextStyle(color: Color(0xFF486581)),
                        ),
                      ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<RoutePlacement>(
                      key: const ValueKey('route-placement-dropdown'),
                      value: _routePlacement,
                      decoration: const InputDecoration(
                        labelText: 'Route order placement',
                        helperText: 'Controls morning delivery sequence.',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: RoutePlacement.first,
                          child: Text('Add at start of route (First)'),
                        ),
                        DropdownMenuItem(
                          value: RoutePlacement.last,
                          child: Text('Add at end of route (Last)'),
                        ),
                        DropdownMenuItem(
                          value: RoutePlacement.afterCustomer,
                          child: Text('Place after existing customer…'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _routePlacement = value);
                        }
                      },
                    ),
                    if (_routePlacement == RoutePlacement.afterCustomer) ...[
                      const SizedBox(height: 14),
                      Consumer(
                        builder: (context, ref, _) {
                          if (_areaId.isEmpty) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 4),
                              child: Text(
                                'Select an area above to choose preceding customer.',
                                style: TextStyle(
                                  color: Color(0xFF627D98),
                                  fontSize: 13,
                                ),
                              ),
                            );
                          }
                          final areaCustomersAsync = ref.watch(
                            areaCustomersProvider((
                              businessId: widget.user.businessId!,
                              areaId: _areaId,
                            ),),
                          );
                          return areaCustomersAsync.when(
                            loading: () => const LinearProgressIndicator(),
                            error:
                                (e, _) => Text('Could not load customers: $e'),
                            data: (customers) {
                              final active =
                                  customers
                                      .where(
                                        (c) => c.status == CustomerStatus.active,
                                      )
                                      .toList();
                              if (active.isEmpty) {
                                return const Text(
                                  'No existing customers in this area. Customer will be placed first.',
                                  style: TextStyle(
                                    color: Color(0xFF627D98),
                                    fontSize: 13,
                                  ),
                                );
                              }
                              final selectedValue =
                                  _afterCustomerId != null &&
                                          active.any(
                                            (c) => c.id == _afterCustomerId,
                                          )
                                      ? _afterCustomerId
                                      : active.first.id;
                              return DropdownButtonFormField<String>(
                                value: selectedValue,
                                decoration: const InputDecoration(
                                  labelText: 'Preceding customer',
                                ),
                                items: [
                                  for (final c in active)
                                    DropdownMenuItem(
                                      value: c.id,
                                      child: Text(
                                        '${c.name} (${c.customerCode})',
                                      ),
                                    ),
                                ],
                                onChanged: (val) {
                                  setState(() => _afterCustomerId = val);
                                },
                              );
                            },
                          );
                        },
                      ),
                    ],
                  ],
                ],
              ),
              const SizedBox(height: 14),

              // Initial Publication / Subscription Selector (New Customers)
              if (!_isEditing && newspapers.isNotEmpty) ...[
                _SectionCard(
                  title: 'Initial Subscription (Optional)',
                  subtitle:
                      'Attach a publication right away or configure full details later.',
                  children: [
                    DropdownButtonFormField<String>(
                      key: const ValueKey('initial-newspaper-dropdown'),
                      value: _selectedNewspaperId ?? '',
                      decoration: const InputDecoration(
                        labelText: 'Select Newspaper / Magazine',
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: '',
                          child: Text('None (Set up subscription later)'),
                        ),
                        for (final pub in newspapers)
                          DropdownMenuItem(
                            value: pub.id,
                            child: Text(pub.displayName),
                          ),
                      ],
                      onChanged: (val) {
                        setState(() => _selectedNewspaperId = val);
                      },
                    ),
                    if (_selectedNewspaperId != null &&
                        _selectedNewspaperId!.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          const Text(
                            'Quantity: ',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(width: 10),
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline),
                            onPressed:
                                _subscriptionQuantity > 1
                                    ? () => setState(
                                      () => _subscriptionQuantity--,
                                    )
                                    : null,
                          ),
                          Text(
                            '$_subscriptionQuantity',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline),
                            onPressed:
                                _subscriptionQuantity < 20
                                    ? () => setState(
                                      () => _subscriptionQuantity++,
                                    )
                                    : null,
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 14),
              ],

              // Extended Fields (GPS & Finances) for Detailed Mode
              if (!_quickAddMode) ...[
                _SectionCard(
                  title: 'Optional GPS location',
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Customer consent recorded'),
                      subtitle: const Text(
                        'Enable only after the customer agrees to store coordinates for delivery identification.',
                      ),
                      value: _locationConsent,
                      onChanged:
                          (value) => setState(() {
                            _locationConsent = value;
                            if (!value) {
                              _latitude.clear();
                              _longitude.clear();
                            }
                          }),
                    ),
                    if (_locationConsent) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _latitude,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                    signed: true,
                                  ),
                              decoration: const InputDecoration(
                                labelText: 'Latitude',
                              ),
                              validator: _requiredText,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextFormField(
                              controller: _longitude,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                    signed: true,
                                  ),
                              decoration: const InputDecoration(
                                labelText: 'Longitude',
                              ),
                              validator: _requiredText,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 14),
                _SectionCard(
                  title: 'Financial opening and notes',
                  children: [
                    if (!_isEditing && widget.user.isHead)
                      TextFormField(
                        controller: _openingBalance,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Opening balance (₹)',
                          helperText:
                              'Set once during Head-created onboarding; later corrections require an audited adjustment.',
                        ),
                        validator: _requiredText,
                      )
                    else
                      _ReadOnlyValue(
                        label: 'Opening balance',
                        value:
                            _isEditing && widget.user.isHead
                                ? '₹${CustomerMoney.formatPaiseForInput(existing!.openingBalancePaise)} (immutable)'
                                : _isEditing
                                ? 'Protected — only the Head can view or set opening balance'
                                : '₹0.00 — employees cannot set financial opening data',
                      ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _notes,
                      minLines: 2,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        labelText: 'Operational notes (optional)',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
              ],

              const SizedBox(height: 16),

              // Action Buttons
              if (_isEditing)
                FilledButton.icon(
                  key: const ValueKey('save-customer-button'),
                  onPressed:
                      _isBusy || areaItems.isEmpty ? null : () => _submit(),
                  icon:
                      _isBusy
                          ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : const Icon(Icons.save_outlined),
                  label: const Text('Save customer changes'),
                )
              else
                Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            key: const ValueKey('save-and-add-next-button'),
                            onPressed:
                                _isBusy || areaItems.isEmpty
                                    ? null
                                    : () => _submit(addNext: true),
                            icon: const Icon(Icons.playlist_add_rounded),
                            label: const Text('Save & Add Next'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.icon(
                            key: const ValueKey('save-customer-button'),
                            onPressed:
                                _isBusy || areaItems.isEmpty
                                    ? null
                                    : () => _submit(addNext: false),
                            icon:
                                _isBusy
                                    ? const SizedBox.square(
                                      dimension: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                    : const Icon(Icons.check_circle_outline),
                            label: const Text('Create customer'),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  List<EmployeeMember> _employeesForArea(List<EmployeeMember> employees) =>
      employees
          .where((employee) => employee.areaIds.contains(_areaId))
          .toList();

  String? _requiredText(String? value) =>
      value == null || value.trim().isEmpty ? 'This field is required.' : null;

  String? _optionalPhone(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final digits = CustomerSearchIndex.normalizePhone(value);
    if (value.length > 24 || digits.length < 7 || digits.length > 15) {
      return 'Enter a valid phone number (7-15 digits).';
    }
    return null;
  }

  Future<void> _submit({bool addNext = false}) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isBusy = true);
    try {
      final coordinates =
          _locationConsent &&
                  _latitude.text.trim().isNotEmpty &&
                  _longitude.text.trim().isNotEmpty
              ? CustomerCoordinates(
                latitude: double.parse(_latitude.text.trim()),
                longitude: double.parse(_longitude.text.trim()),
              )
              : null;
      final existing = widget.customer;
      final openingBalance =
          existing?.openingBalancePaise ??
          (widget.user.isHead && _openingBalance.text.trim().isNotEmpty
              ? CustomerMoney.parseRupeesToPaise(_openingBalance.text)
              : 0);

      // Resolve area name for fallback address/landmark
      final businessId = widget.user.businessId!;
      final areas = ref.read(deliveryAreasProvider(businessId));
      final areaName =
          (areas.asData?.value ?? const <DeliveryArea>[])
              .firstWhere(
                (a) => a.id == _areaId,
                orElse:
                    () => const DeliveryArea(
                      id: '',
                      name: 'Area',
                      isActive: true,
                      assignedEmployeeIds: {},
                    ),
              )
              .name;

      var address = _address.text.trim();
      var landmark = _landmark.text.trim();
      final house = _houseNumber.text.trim();

      if (address.isEmpty || address.length < 5) {
        address =
            house.isNotEmpty
                ? 'House / Flat $house, $areaName'
                : '${_name.text.trim()}, $areaName';
      }
      if (landmark.isEmpty || landmark.length < 2) {
        landmark = 'Near $areaName';
      }

      final input = CustomerInput(
        name: _name.text,
        phone: _phone.text,
        alternatePhone: _alternatePhone.text,
        address: address,
        areaId: existing?.areaId ?? _areaId,
        landmark: landmark,
        houseNumber: _houseNumber.text,
        buildingInfo: _buildingInfo.text,
        locationNotes: _locationNotes.text,
        locationConsent: _locationConsent,
        coordinates: coordinates,
        assignedEmployeeId:
            existing?.assignedEmployeeId ??
            (widget.user.isHead ? _employeeId : widget.user.uid),
        deliveryPlacement: _deliveryPlacement,
        billingCycle: _billingCycle,
        openingBalancePaise: openingBalance,
        notes: _notes.text,
      );
      input.validate();

      final repository = ref.read(customerRepositoryProvider);
      if (existing == null) {
        final id = await repository.createCustomer(
          actor: widget.user,
          input: input,
        );

        // Optional route ordering insertion
        try {
          await ref.read(deliveryRepositoryProvider).insertCustomerInRoute(
            businessId: widget.user.businessId!,
            areaId: input.areaId,
            customerId: id,
            placement: _routePlacement,
            afterCustomerId: _afterCustomerId,
            actorUid: widget.user.uid,
          );
          ref.invalidate(morningRouteStopsProvider(widget.user));
        } catch (_) {
          // Route placement error non-fatal
        }

        // Optional initial publication subscription
        if (_selectedNewspaperId != null &&
            _selectedNewspaperId!.isNotEmpty) {
          try {
            await ref.read(subscriptionRepositoryProvider).createSubscription(
              actor: widget.user,
              customerId: id,
              input: SubscriptionInput(
                newspaperId: _selectedNewspaperId!,
                startDate: LocalDate.fromDateTime(DateTime.now()),
                endDate: null,
                quantity: _subscriptionQuantity,
                deliveryWeekdays: DeliveryWeekday.all,
                customPricePaise: null,
                customPriceReason: '',
              ),
            );
          } catch (_) {
            // Subscription setup non-fatal
          }
        }

        if (!mounted) return;
        final l10n = AppLocalizations.of(context);

        if (addNext) {
          // Retain sticky selections (_areaId, _employeeId, _deliveryPlacement, _routePlacement, _selectedNewspaperId)
          setState(() {
            _name.clear();
            _phone.clear();
            _alternatePhone.clear();
            _houseNumber.clear();
            _buildingInfo.clear();
            _address.clear();
            _landmark.clear();
            _locationNotes.clear();
            _notes.clear();
            _latitude.clear();
            _longitude.clear();
            _openingBalance.text = '0';
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Customer $id created! Ready for next customer.',
              ),
              backgroundColor: const Color(0xFF1B5E20),
            ),
          );
          _nameFocus.requestFocus();
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l10n?.customerCreated(id) ?? 'Customer $id created.',
            ),
          ),
        );
      } else {
        await repository.updateCustomerProfile(
          actor: widget.user,
          customerId: existing.id,
          input: input,
        );
        if (!mounted) return;
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l10n?.customerDetailsUpdated ?? 'Customer details updated.',
            ),
          ),
        );
      }

      if (context.canPop()) {
        context.pop(true);
      } else {
        context.go('/customers');
      }
    } on FormatException {
      if (mounted) _showError('Enter valid latitude and longitude values.');
    } on Object catch (error) {
      if (mounted) _showError(error.toString());
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.children,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 5),
              Text(
                subtitle!,
                style: const TextStyle(color: Color(0xFF486581), height: 1.35),
              ),
            ],
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _ReadOnlyValue extends StatelessWidget {
  const _ReadOnlyValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(labelText: label),
      child: SelectableText(value),
    );
  }
}
