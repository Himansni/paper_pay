import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:paper_route/core/presentation/async_state_cards.dart';
import 'package:paper_route/features/areas/domain/delivery_area.dart';
import 'package:paper_route/features/areas/presentation/area_providers.dart';
import 'package:paper_route/features/auth/domain/app_user.dart';
import 'package:paper_route/features/customers/domain/customer_assignment.dart';
import 'package:paper_route/features/customers/presentation/customer_assignment_providers.dart';
import 'package:paper_route/features/employees/domain/employee_member.dart';
import 'package:paper_route/features/employees/presentation/employee_providers.dart';

class CustomerAssignmentsPage extends ConsumerStatefulWidget {
  const CustomerAssignmentsPage({required this.user, super.key});

  final AppUser user;

  @override
  ConsumerState<CustomerAssignmentsPage> createState() =>
      _CustomerAssignmentsPageState();
}

class _CustomerAssignmentsPageState
    extends ConsumerState<CustomerAssignmentsPage> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final businessId = widget.user.businessId!;
    final customers = ref.watch(customerAssignmentsProvider(businessId));
    final members = ref.watch(employeeMembersProvider(businessId));
    final areas = ref.watch(deliveryAreasProvider(businessId));

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.go('/')),
        title: const Text('Customer assignments'),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Text(
              'Assignment desk',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            const Text(
              'Assign or transfer existing customers. Customer creation and editing remain in Phase 3.',
              style: TextStyle(color: Color(0xFF627D98), height: 1.4),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Find customer',
                prefixIcon: const Icon(Icons.search),
                suffixIcon:
                    _query.isEmpty
                        ? null
                        : IconButton(
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                          icon: const Icon(Icons.clear),
                        ),
              ),
              onChanged: (value) => setState(() => _query = value.trim()),
            ),
            const SizedBox(height: 20),
            customers.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error:
                  (error, _) => AsyncErrorCard(
                    message: 'Could not load customers. $error',
                    onRetry:
                        () => ref.invalidate(
                          customerAssignmentsProvider(businessId),
                        ),
                  ),
              data:
                  (items) => members.when(
                    loading:
                        () => const Center(child: CircularProgressIndicator()),
                    error:
                        (error, _) => AsyncErrorCard(
                          message: 'Could not load employees. $error',
                          onRetry:
                              () => ref.invalidate(
                                employeeMembersProvider(businessId),
                              ),
                        ),
                    data:
                        (team) => areas.when(
                          loading:
                              () => const Center(
                                child: CircularProgressIndicator(),
                              ),
                          error:
                              (error, _) => AsyncErrorCard(
                                message: 'Could not load areas. $error',
                                onRetry:
                                    () => ref.invalidate(
                                      deliveryAreasProvider(businessId),
                                    ),
                              ),
                          data:
                              (areaItems) =>
                                  _buildCustomers(items, team, areaItems),
                        ),
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomers(
    List<CustomerAssignment> customers,
    List<EmployeeMember> members,
    List<DeliveryArea> areas,
  ) {
    if (customers.isEmpty) {
      return const EmptyStateCard(
        icon: Icons.person_search_outlined,
        title: 'No customer records yet',
        message:
            'This screen reads real Firestore customers only. Add customer CRUD in Phase 3 before assignments can appear here.',
      );
    }
    final normalized = _query.toLowerCase();
    final filtered =
        customers.where((customer) {
          if (normalized.isEmpty) return true;
          return customer.name.toLowerCase().contains(normalized) ||
              customer.phone.contains(normalized) ||
              customer.customerCode.toLowerCase().contains(normalized);
        }).toList();
    if (filtered.isEmpty) {
      return const EmptyStateCard(
        icon: Icons.search_off_outlined,
        title: 'No matching customers',
        message: 'Try a different name, phone number, or customer code.',
      );
    }

    final employeeById = {
      for (final member in members.where((member) => member.isEmployee))
        member.uid: member,
    };
    final areaById = {for (final area in areas) area.id: area};
    return Column(
      children: [
        for (final customer in filtered) ...[
          Card(
            child: ListTile(
              contentPadding: const EdgeInsets.fromLTRB(18, 8, 10, 8),
              leading: const CircleAvatar(child: Icon(Icons.person_outline)),
              title: Text(customer.name),
              subtitle: Text(
                '${customer.customerCode}${customer.phone.isEmpty ? '' : ' • ${customer.phone}'}\n'
                'Area: ${areaById[customer.areaId]?.name ?? 'Unassigned'} • '
                'Employee: ${employeeById[customer.assignedEmployeeId]?.displayName ?? 'Unassigned'}',
              ),
              isThreeLine: true,
              trailing: IconButton(
                onPressed: () => _assignCustomer(customer, members, areas),
                tooltip: 'Change assignment',
                icon: const Icon(Icons.swap_horiz),
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  Future<void> _assignCustomer(
    CustomerAssignment customer,
    List<EmployeeMember> members,
    List<DeliveryArea> areas,
  ) async {
    final activeEmployees =
        members
            .where((member) => member.isEmployee && member.isActive)
            .toList();
    final activeAreas = areas.where((area) => area.isActive).toList();
    final draft = await showDialog<_CustomerAssignmentDraft>(
      context: context,
      builder:
          (context) => _CustomerAssignmentDialog(
            customer: customer,
            employees: activeEmployees,
            areas: activeAreas,
          ),
    );
    if (draft == null || !mounted) return;
    try {
      await ref
          .read(customerAssignmentRepositoryProvider)
          .assignCustomer(
            businessId: widget.user.businessId!,
            actorId: widget.user.uid,
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
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }
}

class _CustomerAssignmentDraft {
  const _CustomerAssignmentDraft({
    required this.employeeId,
    required this.areaId,
  });

  final String employeeId;
  final String areaId;
}

class _CustomerAssignmentDialog extends StatefulWidget {
  const _CustomerAssignmentDialog({
    required this.customer,
    required this.employees,
    required this.areas,
  });

  final CustomerAssignment customer;
  final List<EmployeeMember> employees;
  final List<DeliveryArea> areas;

  @override
  State<_CustomerAssignmentDialog> createState() =>
      _CustomerAssignmentDialogState();
}

class _CustomerAssignmentDialogState extends State<_CustomerAssignmentDialog> {
  late String _areaId;
  late String _employeeId;

  List<EmployeeMember> get _availableEmployees {
    if (_areaId.isEmpty) return widget.employees;
    return widget.employees
        .where((employee) => employee.areaIds.contains(_areaId))
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _areaId =
        widget.areas.any((area) => area.id == widget.customer.areaId)
            ? widget.customer.areaId
            : '';
    final candidates =
        _areaId.isEmpty
            ? widget.employees
            : widget.employees.where(
              (employee) => employee.areaIds.contains(_areaId),
            );
    _employeeId =
        candidates.any(
              (employee) => employee.uid == widget.customer.assignedEmployeeId,
            )
            ? widget.customer.assignedEmployeeId
            : '';
  }

  @override
  Widget build(BuildContext context) {
    final availableEmployees = _availableEmployees;
    return AlertDialog(
      title: Text('Assign ${widget.customer.name}'),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: _areaId,
              decoration: const InputDecoration(labelText: 'Delivery area'),
              items: [
                const DropdownMenuItem(value: '', child: Text('Unassigned')),
                for (final area in widget.areas)
                  DropdownMenuItem(value: area.id, child: Text(area.name)),
              ],
              onChanged:
                  (value) => setState(() {
                    _areaId = value ?? '';
                    if (!_availableEmployees.any(
                      (employee) => employee.uid == _employeeId,
                    )) {
                      _employeeId = '';
                    }
                  }),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              value: _employeeId,
              decoration: const InputDecoration(labelText: 'Employee'),
              items: [
                const DropdownMenuItem(value: '', child: Text('Unassigned')),
                for (final employee in availableEmployees)
                  DropdownMenuItem(
                    value: employee.uid,
                    child: Text(employee.displayName),
                  ),
              ],
              onChanged: (value) => setState(() => _employeeId = value ?? ''),
            ),
            if (_areaId.isNotEmpty && availableEmployees.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text(
                  'No active employee is assigned to this area yet.',
                  style: TextStyle(color: Color(0xFF9B5C00)),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed:
              () => Navigator.pop(
                context,
                _CustomerAssignmentDraft(
                  employeeId: _employeeId,
                  areaId: _areaId,
                ),
              ),
          child: const Text('Save assignment'),
        ),
      ],
    );
  }
}
