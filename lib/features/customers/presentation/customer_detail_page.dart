import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:paper_route/core/presentation/async_state_cards.dart';
import 'package:paper_route/features/areas/domain/delivery_area.dart';
import 'package:paper_route/features/areas/presentation/area_providers.dart';
import 'package:paper_route/features/auth/domain/access_policy.dart';
import 'package:paper_route/features/auth/domain/app_user.dart';
import 'package:paper_route/features/customers/domain/customer.dart';
import 'package:paper_route/features/collections/presentation/customer_collection_summary.dart';
import 'package:paper_route/features/customers/presentation/customer_assignment_dialog.dart';
import 'package:paper_route/features/customers/presentation/customer_providers.dart';
import 'package:paper_route/features/employees/domain/employee_member.dart';
import 'package:paper_route/features/employees/presentation/employee_providers.dart';
import 'package:paper_route/features/subscriptions/presentation/subscription_detail_page.dart';

class CustomerDetailPage extends ConsumerWidget {
  const CustomerDetailPage({
    required this.user,
    required this.customerId,
    super.key,
  });

  final AppUser user;
  final String customerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = (businessId: user.businessId!, customerId: customerId);
    final customer = ref.watch(customerProvider(key));
    return customer.when(
      loading:
          () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
      error:
          (error, _) => Scaffold(
            appBar: AppBar(
              leading: BackButton(onPressed: () => _back(context)),
              title: const Text('Customer'),
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
                      leading: BackButton(onPressed: () => _back(context)),
                      title: const Text('Customer'),
                    ),
                    body: const Padding(
                      padding: EdgeInsets.all(20),
                      child: EmptyStateCard(
                        icon: Icons.person_off_outlined,
                        title: 'Customer not found',
                        message: 'This customer record is not available.',
                      ),
                    ),
                  )
                  : _CustomerDetailView(user: user, customer: value),
    );
  }

  static void _back(BuildContext context) {
    if (context.canPop()) {
      context.pop(true);
    } else {
      context.go('/customers');
    }
  }
}

class _CustomerDetailView extends ConsumerStatefulWidget {
  const _CustomerDetailView({required this.user, required this.customer});

  final AppUser user;
  final Customer customer;

  @override
  ConsumerState<_CustomerDetailView> createState() =>
      _CustomerDetailViewState();
}

class _CustomerDetailViewState extends ConsumerState<_CustomerDetailView> {
  static const _accessPolicy = AccessPolicy();
  bool _isBusy = false;

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final customer = widget.customer;
    final businessId = user.businessId!;
    final areas = ref.watch(deliveryAreasProvider(businessId));
    final members =
        user.isHead
            ? ref.watch(employeeMembersProvider(businessId))
            : const AsyncData<List<EmployeeMember>>([]);
    final areaItems = areas.asData?.value ?? const <DeliveryArea>[];
    final memberItems = members.asData?.value ?? const <EmployeeMember>[];
    final areaName = _areaName(areaItems, customer.areaId);
    final employeeName =
        user.isHead
            ? _employeeName(memberItems, customer.assignedEmployeeId)
            : (customer.assignedEmployeeId == user.uid ? 'You' : 'Unavailable');
    final canEdit = _accessPolicy.canEditCustomer(
      member: user,
      customerBusinessId: customer.businessId,
      assignedEmployeeId: customer.assignedEmployeeId,
      isArchived: customer.isArchived,
    );

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(
          onPressed:
              () =>
                  context.canPop()
                      ? context.pop(true)
                      : context.go('/customers'),
        ),
        title: const Text('Customer details'),
        actions: [
          if (canEdit)
            IconButton(
              onPressed:
                  _isBusy
                      ? null
                      : () => context.push<bool>(
                        '/customers/${Uri.encodeComponent(customer.id)}/edit',
                      ),
              tooltip: 'Edit customer',
              icon: const Icon(Icons.edit_outlined),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 28,
                  child: Icon(
                    customer.isArchived
                        ? Icons.person_off_outlined
                        : Icons.person_outline,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        customer.name,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      SelectableText(
                        customer.customerCode,
                        style: const TextStyle(color: Color(0xFF627D98)),
                      ),
                    ],
                  ),
                ),
                Chip(label: Text(customer.status.label)),
              ],
            ),
            const SizedBox(height: 18),
            Card(
              color: const Color(0xFFFFF8E8),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.location_on_outlined),
                        SizedBox(width: 8),
                        Text(
                          'Find the house',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (customer.houseNumber.isNotEmpty)
                      Text(
                        customer.houseNumber,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    if (customer.buildingInfo.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          customer.buildingInfo,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                    const SizedBox(height: 8),
                    SelectableText(
                      customer.address,
                      style: const TextStyle(fontSize: 17, height: 1.45),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'LANDMARK: ${customer.landmark}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF8A4B00),
                      ),
                    ),
                    if (customer.locationNotes.isNotEmpty) ...[
                      const Divider(height: 24),
                      Text(
                        customer.locationNotes,
                        style: const TextStyle(height: 1.4),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            _DetailCard(
              title: 'Contact',
              rows: [
                _DetailRow('Primary phone', customer.phone, selectable: true),
                if (customer.alternatePhone.isNotEmpty)
                  _DetailRow(
                    'Alternate phone',
                    customer.alternatePhone,
                    selectable: true,
                  ),
              ],
            ),
            const SizedBox(height: 14),
            _DetailCard(
              title: 'Delivery assignment',
              rows: [
                _DetailRow('Area', areaName),
                _DetailRow('Employee', employeeName),
                _DetailRow('Placement', customer.deliveryPlacement.label),
                _DetailRow('Billing preference', customer.billingCycle.label),
              ],
              action:
                  user.isHead && !customer.isArchived
                      ? TextButton.icon(
                        onPressed:
                            _isBusy || areas.isLoading || members.isLoading
                                ? null
                                : () =>
                                    _changeAssignment(areaItems, memberItems),
                        icon: const Icon(Icons.swap_horiz),
                        label: const Text('Change assignment'),
                      )
                      : null,
            ),
            const SizedBox(height: 14),
            CustomerSubscriptionsSection(user: user, customer: customer),
            const SizedBox(height: 14),
            CustomerCollectionSummary(user: user, customer: customer),
            if (customer.locationConsent && customer.coordinates != null) ...[
              const SizedBox(height: 14),
              _DetailCard(
                title: 'Consented GPS location',
                rows: [
                  _DetailRow(
                    'Latitude',
                    customer.coordinates!.latitude.toStringAsFixed(6),
                    selectable: true,
                  ),
                  _DetailRow(
                    'Longitude',
                    customer.coordinates!.longitude.toStringAsFixed(6),
                    selectable: true,
                  ),
                ],
              ),
            ],
            if (customer.notes.isNotEmpty) ...[
              const SizedBox(height: 14),
              _DetailCard(
                title: 'Operational notes',
                rows: [_DetailRow('', customer.notes)],
              ),
            ],
            if (user.isHead) ...[
              const SizedBox(height: 14),
              _DetailCard(
                title: 'Financial opening',
                rows: [
                  _DetailRow(
                    'Opening balance',
                    NumberFormat.currency(
                      locale: 'en_IN',
                      symbol: '₹',
                    ).format(customer.openingBalancePaise / 100),
                  ),
                  const _DetailRow(
                    'Protection',
                    'Immutable after creation; future corrections require an audited adjustment.',
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _CustomerHistory(businessId: businessId, customerId: customer.id),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: _isBusy ? null : _toggleArchived,
                icon: Icon(
                  customer.isArchived
                      ? Icons.restore_outlined
                      : Icons.archive_outlined,
                ),
                label: Text(
                  customer.isArchived
                      ? 'Reactivate customer'
                      : 'Archive customer',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _changeAssignment(
    List<DeliveryArea> areas,
    List<EmployeeMember> members,
  ) async {
    final customer = widget.customer;
    final draft = await showCustomerAssignmentDialog(
      context: context,
      customerName: customer.name,
      initialEmployeeId: customer.assignedEmployeeId,
      initialAreaId: customer.areaId,
      employees: members,
      areas: areas,
    );
    if (draft == null || !mounted) return;
    setState(() => _isBusy = true);
    try {
      await ref
          .read(customerRepositoryProvider)
          .assignCustomer(
            actor: widget.user,
            customerId: customer.id,
            employeeId: draft.employeeId,
            areaId: draft.areaId,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Customer assignment updated.')),
        );
      }
    } on Object catch (error) {
      if (mounted) _showError(error);
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _toggleArchived() async {
    final customer = widget.customer;
    final shouldChange = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              customer.isArchived
                  ? 'Reactivate customer?'
                  : 'Archive customer?',
            ),
            content: Text(
              customer.isArchived
                  ? 'The customer will return to active operational lists.'
                  : 'The record and all history will be preserved. Delivery and billing records will not be deleted.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(customer.isArchived ? 'Reactivate' : 'Archive'),
              ),
            ],
          ),
    );
    if (shouldChange != true || !mounted) return;
    setState(() => _isBusy = true);
    try {
      await ref
          .read(customerRepositoryProvider)
          .setCustomerArchived(
            actor: widget.user,
            customerId: customer.id,
            archived: !customer.isArchived,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              customer.isArchived
                  ? 'Customer reactivated.'
                  : 'Customer archived without deleting history.',
            ),
          ),
        );
      }
    } on Object catch (error) {
      if (mounted) _showError(error);
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  void _showError(Object error) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(error.toString())));
  }

  String _areaName(List<DeliveryArea> areas, String areaId) {
    for (final area in areas) {
      if (area.id == areaId) return area.name;
    }
    return areaId.isEmpty ? 'Unassigned' : areaId;
  }

  String _employeeName(List<EmployeeMember> members, String employeeId) {
    if (employeeId.isEmpty) return 'Unassigned';
    for (final member in members) {
      if (member.uid == employeeId) {
        return member.displayName.isEmpty ? member.email : member.displayName;
      }
    }
    return employeeId;
  }
}

class _DetailRow {
  const _DetailRow(this.label, this.value, {this.selectable = false});

  final String label;
  final String value;
  final bool selectable;
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({required this.title, required this.rows, this.action});

  final String title;
  final List<_DetailRow> rows;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (action != null) action!,
              ],
            ),
            for (final row in rows) ...[
              const SizedBox(height: 12),
              if (row.label.isNotEmpty)
                Text(
                  row.label,
                  style: const TextStyle(
                    color: Color(0xFF627D98),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              const SizedBox(height: 3),
              if (row.selectable)
                SelectableText(row.value)
              else
                Text(row.value, style: const TextStyle(height: 1.4)),
            ],
          ],
        ),
      ),
    );
  }
}

class _CustomerHistory extends ConsumerWidget {
  const _CustomerHistory({required this.businessId, required this.customerId});

  final String businessId;
  final String customerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(
      customerAuditProvider((businessId: businessId, customerId: customerId)),
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Assignment and change history',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            history.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error:
                  (error, _) => Text(
                    'Could not load audit history. $error',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
              data:
                  (items) =>
                      items.isEmpty
                          ? const Text(
                            'No customer audit entries are available yet.',
                            style: TextStyle(color: Color(0xFF627D98)),
                          )
                          : Column(
                            children: [
                              for (final entry in items)
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: Icon(_iconFor(entry.action)),
                                  title: Text(_labelFor(entry.action)),
                                  subtitle: Text(_historySubtitle(entry)),
                                ),
                            ],
                          ),
            ),
          ],
        ),
      ),
    );
  }

  String _historySubtitle(CustomerAuditEntry entry) {
    final date = entry.createdAt;
    final parts = <String>[
      if (date != null) DateFormat('d MMM yyyy, h:mm a').format(date.toLocal()),
      if (entry.action == 'customerAssignmentUpdated')
        'Area ${entry.previousAreaId.isEmpty ? 'unassigned' : entry.previousAreaId} → ${entry.areaId}',
      if (entry.action == 'customerAssignmentUpdated')
        'Employee ${entry.previousEmployeeId.isEmpty ? 'unassigned' : entry.previousEmployeeId} → ${entry.employeeId.isEmpty ? 'unassigned' : entry.employeeId}',
      if (entry.changedFields.isNotEmpty)
        'Fields: ${entry.changedFields.join(', ')}',
    ];
    return parts.isEmpty ? 'Recorded by ${entry.actorId}' : parts.join('\n');
  }

  String _labelFor(String action) => switch (action) {
    'customerCreated' => 'Customer created',
    'customerUpdated' => 'Customer details updated',
    'customerArchived' => 'Customer archived',
    'customerReactivated' => 'Customer reactivated',
    'customerAssignmentUpdated' => 'Assignment transferred',
    _ => action,
  };

  IconData _iconFor(String action) => switch (action) {
    'customerCreated' => Icons.person_add_alt_1,
    'customerArchived' => Icons.archive_outlined,
    'customerReactivated' => Icons.restore_outlined,
    'customerAssignmentUpdated' => Icons.swap_horiz,
    _ => Icons.edit_outlined,
  };
}
