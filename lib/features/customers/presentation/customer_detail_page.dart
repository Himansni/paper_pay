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
import 'package:paper_route/features/customers/domain/customer_removal_request.dart';
import 'package:paper_route/features/collections/presentation/customer_collection_summary.dart';
import 'package:paper_route/features/customers/presentation/customer_assignment_dialog.dart';
import 'package:paper_route/features/customers/presentation/customer_providers.dart';
import 'package:paper_route/features/employees/domain/employee_member.dart';
import 'package:paper_route/features/employees/presentation/employee_providers.dart';
import 'package:paper_route/features/subscriptions/presentation/subscription_detail_page.dart';

import 'package:paper_route/l10n/app_localizations.dart';

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
    final l10n = AppLocalizations.of(context);
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
              title: Text(l10n?.customerDetailsTitle ?? 'Customer'),
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
                      title: Text(l10n?.customerDetailsTitle ?? 'Customer'),
                    ),
                    body: Padding(
                      padding: const EdgeInsets.all(20),
                      child: EmptyStateCard(
                        icon: Icons.person_off_outlined,
                        title: l10n?.customerNotFound ?? 'Customer not found',
                        message:
                            l10n?.customerNotFoundMessage ??
                            'This customer record is not available.',
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
    final l10n = AppLocalizations.of(context);
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
        title: Text(l10n?.customerDetailsTitle ?? 'Customer details'),
        actions: [
          if (canEdit)
            IconButton(
              onPressed:
                  _isBusy
                      ? null
                      : () => context.push<bool>(
                        '/customers/${Uri.encodeComponent(customer.id)}/edit',
                      ),
              tooltip: l10n?.commonEdit ?? 'Edit customer',
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
                        style: const TextStyle(color: Color(0xFF486581)),
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
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined),
                        const SizedBox(width: 8),
                        Text(
                          l10n?.findTheHouse ?? 'Find the house',
                          style: const TextStyle(fontWeight: FontWeight.w800),
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
                      '${l10n?.landmarkPrefix ?? 'LANDMARK: '}${customer.landmark}',
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
              title: l10n?.contactSection ?? 'Contact',
              rows: [
                _DetailRow(l10n?.primaryPhone ?? 'Primary phone', customer.phone, selectable: true),
                if (customer.alternatePhone.isNotEmpty)
                  _DetailRow(
                    l10n?.alternatePhone ?? 'Alternate phone',
                    customer.alternatePhone,
                    selectable: true,
                  ),
              ],
            ),
            const SizedBox(height: 14),
            _DetailCard(
              title: l10n?.deliveryAssignment ?? 'Delivery assignment',
              rows: [
                _DetailRow(l10n?.areaLabel ?? 'Area', areaName),
                _DetailRow(l10n?.employeeLabel ?? 'Employee', employeeName),
                _DetailRow(l10n?.placementLabel ?? 'Placement', customer.deliveryPlacement.label),
                _DetailRow(l10n?.billingPreference ?? 'Billing preference', customer.billingCycle.label),
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
                        label: Text(l10n?.changeAssignment ?? 'Change assignment'),
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
                title: l10n?.consentedGpsLocation ?? 'Consented GPS location',
                rows: [
                  _DetailRow(
                    l10n?.latitude ?? 'Latitude',
                    customer.coordinates!.latitude.toStringAsFixed(6),
                    selectable: true,
                  ),
                  _DetailRow(
                    l10n?.longitude ?? 'Longitude',
                    customer.coordinates!.longitude.toStringAsFixed(6),
                    selectable: true,
                  ),
                ],
              ),
            ],
            if (customer.notes.isNotEmpty) ...[
              const SizedBox(height: 14),
              _DetailCard(
                title: l10n?.operationalNotes ?? 'Operational notes',
                rows: [_DetailRow('', customer.notes)],
              ),
            ],
            if (user.isHead) ...[
              const SizedBox(height: 14),
              _DetailCard(
                title: l10n?.financialOpening ?? 'Financial opening',
                rows: [
                  _DetailRow(
                    l10n?.openingBalance ?? 'Opening balance',
                    NumberFormat.currency(
                      locale: 'en_IN',
                      symbol: '₹',
                    ).format(customer.openingBalancePaise / 100),
                  ),
                  _DetailRow(
                    l10n?.commonNotice ?? 'Protection',
                    l10n?.immutableOpeningNotice ??
                        'Immutable after creation; future corrections require an audited adjustment.',
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _CustomerHistory(businessId: businessId, customerId: customer.id),
            ],
            const SizedBox(height: 20),

            // Pending Removal Request Card if active for this customer
            Builder(
              builder: (context) {
                final pendingAsync = ref.watch(
                  pendingRemovalRequestsProvider(
                    (
                      businessId: businessId,
                      requesterId: user.uid,
                      isHead: user.isHead,
                    ),
                  ),
                );
                final pendingRequests =
                    pendingAsync.asData?.value ??
                    const <CustomerRemovalRequest>[];
                final matchingRequest = pendingRequests
                    .where((r) => r.customerId == customer.id)
                    .firstOrNull;

                if (matchingRequest != null) {
                  return Card(
                    color: const Color(0xFFFFEBEE),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: Color(0xFFFFCDD2), width: 1.5),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFD32F2F),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'REMOVAL PENDING APPROVAL',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 11,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Requested by: ${matchingRequest.requestedByName}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFFFCDD2)),
                            ),
                            child: Text(
                              'Reason: ${matchingRequest.reason}',
                              style: const TextStyle(
                                color: Color(0xFF334E68),
                                fontSize: 13.5,
                              ),
                            ),
                          ),
                          if (user.isHead) ...[
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                OutlinedButton(
                                  onPressed:
                                      _isBusy
                                          ? null
                                          : () => _reviewRemoval(
                                            matchingRequest,
                                            approved: false,
                                          ),
                                  child: const Text('Reject Request'),
                                ),
                                const SizedBox(width: 10),
                                FilledButton.icon(
                                  onPressed:
                                      _isBusy
                                          ? null
                                          : () => _reviewRemoval(
                                            matchingRequest,
                                            approved: true,
                                          ),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFFD32F2F),
                                  ),
                                  icon: const Icon(
                                    Icons.archive_outlined,
                                    size: 18,
                                  ),
                                  label: const Text('Approve & Archive'),
                                ),
                              ],
                            ),
                          ] else ...[
                            const SizedBox(height: 8),
                            const Row(
                              children: [
                                Icon(
                                  Icons.hourglass_empty_rounded,
                                  size: 16,
                                  color: Color(0xFFD32F2F),
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'Awaiting Agency Head review and approval',
                                  style: TextStyle(
                                    color: Color(0xFFD32F2F),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }

                if (!customer.isArchived) {
                  return Column(
                    children: [
                      if (user.isHead) ...[
                        OutlinedButton.icon(
                          onPressed: _isBusy ? null : _toggleArchived,
                          icon: const Icon(Icons.archive_outlined),
                          label: Text(l10n?.archiveCustomer ?? 'Archive customer'),
                        ),
                        const SizedBox(height: 8),
                      ],
                      OutlinedButton.icon(
                        onPressed: _isBusy ? null : _requestRemoval,
                        icon: const Icon(
                          Icons.person_remove_outlined,
                          color: Color(0xFFD32F2F),
                        ),
                        label: const Text(
                          'Request customer removal',
                          style: TextStyle(color: Color(0xFFD32F2F)),
                        ),
                      ),
                    ],
                  );
                }

                if (user.isHead && customer.isArchived) {
                  return FilledButton.icon(
                    onPressed: _isBusy ? null : _toggleArchived,
                    icon: const Icon(Icons.restore_outlined),
                    label: Text(
                      l10n?.reactivateCustomer ?? 'Reactivate customer',
                    ),
                  );
                }

                return const SizedBox.shrink();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _requestRemoval() async {
    final customer = widget.customer;
    final reasonController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final shouldSubmit = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Request Removal: ${customer.name}'),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Submit a customer removal request for Agency Head review. Historical bills, ledger entries, and payment records remain 100% preserved.',
                    style: TextStyle(color: Color(0xFF486581), fontSize: 13),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: reasonController,
                    autofocus: true,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Reason for removal *',
                      hintText:
                          'e.g. Relocated to another city, Stopped reading newspaper',
                    ),
                    validator: (val) {
                      if (val == null || val.trim().length < 3) {
                        return 'Please provide a valid reason (min 3 characters).';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  if (formKey.currentState!.validate()) {
                    Navigator.pop(context, true);
                  }
                },
                child: const Text('Submit Request'),
              ),
            ],
          ),
    );

    if (shouldSubmit != true || !mounted) return;
    setState(() => _isBusy = true);
    try {
      await ref
          .read(customerRepositoryProvider)
          .requestCustomerRemoval(
            actor: widget.user,
            customerId: customer.id,
            reason: reasonController.text.trim(),
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Customer removal request submitted for Head review.'),
          ),
        );
      }
    } on Object catch (error) {
      if (mounted) _showError(error);
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _reviewRemoval(
    CustomerRemovalRequest req, {
    required bool approved,
  }) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              approved
                  ? 'Approve Customer Removal & Archive?'
                  : 'Reject Removal Request?',
            ),
            content: Text(
              approved
                  ? 'Approving will archive "${req.customerName}". All bills, ledger lines, and payment records will be preserved.'
                  : 'Rejecting will keep "${req.customerName}" active.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style:
                    approved
                        ? FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFD32F2F),
                        )
                        : null,
                onPressed: () => Navigator.pop(context, true),
                child: Text(approved ? 'Approve & Archive' : 'Reject Request'),
              ),
            ],
          ),
    );

    if (confirm != true || !mounted) return;
    setState(() => _isBusy = true);
    try {
      await ref
          .read(customerRepositoryProvider)
          .reviewRemovalRequest(
            actor: widget.user,
            requestId: req.id,
            approved: approved,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              approved
                  ? 'Customer removed and archived.'
                  : 'Removal request rejected.',
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
    final l10n = AppLocalizations.of(context);
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
          SnackBar(
            content: Text(
              l10n?.customerAssignmentUpdated ?? 'Customer assignment updated.',
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

  Future<void> _toggleArchived() async {
    final customer = widget.customer;
    final l10n = AppLocalizations.of(context);
    final shouldChange = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              customer.isArchived
                  ? (l10n?.reactivateCustomerConfirm ?? 'Reactivate customer?')
                  : (l10n?.archiveCustomerConfirm ?? 'Archive customer?'),
            ),
            content: Text(
              customer.isArchived
                  ? (l10n?.reactivateCustomerDesc ??
                      'The customer will return to active operational lists.')
                  : (l10n?.archiveCustomerDesc ??
                      'The record and all history will be preserved. Delivery and billing records will not be deleted.'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(l10n?.commonCancel ?? 'Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(
                  customer.isArchived
                      ? (l10n?.reactivateCustomer ?? 'Reactivate')
                      : (l10n?.archiveCustomer ?? 'Archive'),
                ),
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
                  ? (l10n?.customerReactivated ?? 'Customer reactivated.')
                  : (l10n?.customerArchivedNotice ??
                      'Customer archived without deleting history.'),
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
                    color: Color(0xFF486581),
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
    final l10n = AppLocalizations.of(context);
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
              l10n?.assignmentAndChangeHistory ?? 'Assignment and change history',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            history.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error:
                  (error, _) => Text(
                    l10n?.couldNotLoadAuditHistory(error.toString()) ??
                        'Could not load audit history. $error',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
              data:
                  (items) =>
                      items.isEmpty
                          ? Text(
                            l10n?.noCustomerAuditEntries ??
                                'No customer audit entries are available yet.',
                            style: const TextStyle(color: Color(0xFF486581)),
                          )
                          : Column(
                            children: [
                              for (final entry in items)
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: Icon(_iconFor(entry.action)),
                                  title: Text(_labelFor(entry.action, l10n)),
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

  String _labelFor(String action, AppLocalizations? l10n) => switch (action) {
    'customerCreated' => l10n?.auditCustomerCreated ?? 'Customer created',
    'customerUpdated' => l10n?.auditCustomerUpdated ?? 'Customer details updated',
    'customerArchived' => l10n?.auditCustomerArchived ?? 'Customer archived',
    'customerReactivated' => l10n?.auditCustomerReactivated ?? 'Customer reactivated',
    'customerAssignmentUpdated' => l10n?.auditCustomerAssignmentTransferred ?? 'Assignment transferred',
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
