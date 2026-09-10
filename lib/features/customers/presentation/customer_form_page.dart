import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:paper_route/core/presentation/async_state_cards.dart';
import 'package:paper_route/features/areas/domain/delivery_area.dart';
import 'package:paper_route/features/areas/presentation/area_providers.dart';
import 'package:paper_route/features/auth/domain/access_policy.dart';
import 'package:paper_route/features/auth/domain/app_user.dart';
import 'package:paper_route/features/customers/domain/customer.dart';
import 'package:paper_route/features/customers/presentation/customer_providers.dart';
import 'package:paper_route/features/employees/domain/employee_member.dart';
import 'package:paper_route/features/employees/presentation/employee_providers.dart';

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
    return customer.when(
      loading:
          () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
      error:
          (error, _) => Scaffold(
            appBar: AppBar(title: const Text('Edit customer')),
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
                    appBar: AppBar(title: const Text('Edit customer')),
                    body: const Padding(
                      padding: EdgeInsets.all(20),
                      child: EmptyStateCard(
                        icon: Icons.person_off_outlined,
                        title: 'Customer not found',
                        message: 'The record may no longer be available.',
                      ),
                    ),
                  )
                  : CustomerFormPage(user: user, customer: value),
    );
  }
}

class CustomerFormPage extends ConsumerStatefulWidget {
  const CustomerFormPage({required this.user, this.customer, super.key});

  final AppUser user;
  final Customer? customer;

  @override
  ConsumerState<CustomerFormPage> createState() => _CustomerFormPageState();
}

class _CustomerFormPageState extends ConsumerState<CustomerFormPage> {
  static const _accessPolicy = AccessPolicy();
  final _formKey = GlobalKey<FormState>();
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
  bool _isBusy = false;

  bool get _isEditing => widget.customer != null;

  @override
  void initState() {
    super.initState();
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
  }

  @override
  void dispose() {
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

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(
          onPressed:
              () => context.canPop() ? context.pop() : context.go('/customers'),
        ),
        title: Text(_isEditing ? 'Edit customer' : 'New customer'),
      ),
      body: SafeArea(
        top: false,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
            children: [
              Text(
                _isEditing ? existing!.name : 'Customer profile',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _isEditing
                    ? 'Customer ID ${existing!.customerCode} is permanent. Assignment and status have separate audited actions.'
                    : 'A permanent customer ID is generated when this record is saved.',
                style: const TextStyle(color: Color(0xFF627D98), height: 1.4),
              ),
              const SizedBox(height: 20),
              _SectionCard(
                title: 'Identity and contact',
                children: [
                  TextFormField(
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
                    ),
                    validator: _requiredText,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _alternatePhone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Alternate phone (optional)',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _SectionCard(
                title: 'House identification',
                subtitle:
                    'Keep these details clear enough to recognize the correct house outdoors.',
                children: [
                  TextFormField(
                    controller: _houseNumber,
                    decoration: const InputDecoration(
                      labelText: 'House / flat number (optional)',
                    ),
                  ),
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
              ),
              const SizedBox(height: 14),
              _SectionCard(
                title: 'Area and assignment',
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
                      style: TextStyle(color: Color(0xFF627D98)),
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
                    if (widget.user.isHead) ...[
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
                          key: const ValueKey('customer-employee-dropdown'),
                          value:
                              _employeesForArea(memberItems).any(
                                    (employee) => employee.uid == _employeeId,
                                  )
                                  ? _employeeId
                                  : '',
                          decoration: const InputDecoration(
                            labelText: 'Assigned employee',
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: '',
                              child: Text('Unassigned'),
                            ),
                            for (final employee in _employeesForArea(
                              memberItems,
                            ))
                              DropdownMenuItem(
                                value: employee.uid,
                                child: Text(
                                  employee.displayName.isEmpty
                                      ? employee.email
                                      : employee.displayName,
                                ),
                              ),
                          ],
                          onChanged:
                              (value) =>
                                  setState(() => _employeeId = value ?? ''),
                        ),
                    ] else
                      const Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: Text(
                          'This customer will be assigned to you. Firestore verifies the selected area against your membership.',
                          style: TextStyle(color: Color(0xFF627D98)),
                        ),
                      ),
                  ],
                ],
              ),
              const SizedBox(height: 14),
              _SectionCard(
                title: 'Delivery and billing preferences',
                subtitle:
                    'Set delivery and future billing preferences here. Manage dated newspaper subscriptions from the saved customer.',
                children: [
                  DropdownButtonFormField<DeliveryPlacement>(
                    value: _deliveryPlacement,
                    decoration: const InputDecoration(
                      labelText: 'Delivery placement',
                    ),
                    items: [
                      for (final item in DeliveryPlacement.values)
                        DropdownMenuItem(value: item, child: Text(item.label)),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _deliveryPlacement = value);
                      }
                    },
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<BillingCyclePreference>(
                    value: _billingCycle,
                    decoration: const InputDecoration(
                      labelText: 'Preferred billing cycle',
                    ),
                    items: [
                      for (final item in BillingCyclePreference.values)
                        DropdownMenuItem(value: item, child: Text(item.label)),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() => _billingCycle = value);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 14),
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
                            keyboardType: const TextInputType.numberWithOptions(
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
                            keyboardType: const TextInputType.numberWithOptions(
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
              FilledButton.icon(
                onPressed:
                    _isBusy || (!_isEditing && areaItems.isEmpty)
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
                  _isEditing ? 'Save customer changes' : 'Create customer',
                ),
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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isBusy = true);
    try {
      final coordinates =
          _locationConsent
              ? CustomerCoordinates(
                latitude: double.parse(_latitude.text.trim()),
                longitude: double.parse(_longitude.text.trim()),
              )
              : null;
      final existing = widget.customer;
      final openingBalance =
          existing?.openingBalancePaise ??
          (widget.user.isHead
              ? CustomerMoney.parseRupeesToPaise(_openingBalance.text)
              : 0);
      final input = CustomerInput(
        name: _name.text,
        phone: _phone.text,
        alternatePhone: _alternatePhone.text,
        address: _address.text,
        areaId: existing?.areaId ?? _areaId,
        landmark: _landmark.text,
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
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Customer $id created.')));
      } else {
        await repository.updateCustomerProfile(
          actor: widget.user,
          customerId: existing.id,
          input: input,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Customer details updated.')),
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
                style: const TextStyle(color: Color(0xFF627D98), height: 1.35),
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
