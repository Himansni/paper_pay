import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:paper_route/core/presentation/async_state_cards.dart';
import 'package:paper_route/features/areas/domain/delivery_area.dart';
import 'package:paper_route/features/areas/presentation/area_providers.dart';
import 'package:paper_route/features/auth/domain/app_user.dart';
import 'package:paper_route/features/employees/domain/employee_member.dart';
import 'package:paper_route/features/employees/presentation/employee_providers.dart';

class AreasPage extends ConsumerWidget {
  const AreasPage({required this.user, super.key});

  final AppUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final businessId = user.businessId!;
    final areas = ref.watch(deliveryAreasProvider(businessId));
    final members = ref.watch(employeeMembersProvider(businessId));

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.go('/')),
        title: const Text('Delivery areas'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _createArea(context, ref),
        icon: const Icon(Icons.add_location_alt_outlined),
        label: const Text('New area'),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
          children: [
            Text(
              'Route coverage',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            const Text(
              'Create operational areas and keep employee coverage synchronized with authoritative member records.',
              style: TextStyle(color: Color(0xFF486581), height: 1.4),
            ),
            const SizedBox(height: 20),
            areas.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error:
                  (error, _) => AsyncErrorCard(
                    message: 'Could not load areas. $error',
                    onRetry:
                        () => ref.invalidate(deliveryAreasProvider(businessId)),
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
                        (team) => _AreaList(
                          areas: items,
                          employees:
                              team
                                  .where((member) => member.isEmployee)
                                  .toList(),
                          onEdit: (area) => _editArea(context, ref, area),
                          onAssign:
                              (area) =>
                                  _assignEmployees(context, ref, area, team),
                        ),
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createArea(BuildContext context, WidgetRef ref) async {
    final draft = await showDialog<_AreaDraft>(
      context: context,
      builder: (context) => const _AreaDialog(),
    );
    if (draft == null || !context.mounted) return;
    try {
      await ref
          .read(areaRepositoryProvider)
          .createArea(
            businessId: user.businessId!,
            actorId: user.uid,
            name: draft.name,
          );
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Area created.')));
      }
    } on Object catch (error) {
      if (context.mounted) _showError(context, error);
    }
  }

  Future<void> _editArea(
    BuildContext context,
    WidgetRef ref,
    DeliveryArea area,
  ) async {
    final draft = await showDialog<_AreaDraft>(
      context: context,
      builder: (context) => _AreaDialog(area: area),
    );
    if (draft == null || !context.mounted) return;
    try {
      await ref
          .read(areaRepositoryProvider)
          .updateArea(
            businessId: user.businessId!,
            actorId: user.uid,
            areaId: area.id,
            name: draft.name,
            isActive: draft.isActive,
          );
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Area updated.')));
      }
    } on Object catch (error) {
      if (context.mounted) _showError(context, error);
    }
  }

  Future<void> _assignEmployees(
    BuildContext context,
    WidgetRef ref,
    DeliveryArea area,
    List<EmployeeMember> allMembers,
  ) async {
    final employees = allMembers.where((member) => member.isEmployee).toList();
    final current =
        employees
            .where((member) => member.areaIds.contains(area.id))
            .map((member) => member.uid)
            .toSet();
    final selected = await showDialog<Set<String>>(
      context: context,
      builder:
          (context) => _EmployeeAssignmentDialog(
            area: area,
            employees: employees,
            selectedEmployeeIds: current,
          ),
    );
    if (selected == null || !context.mounted) return;
    try {
      await ref
          .read(areaRepositoryProvider)
          .setEmployeeAssignments(
            businessId: user.businessId!,
            actorId: user.uid,
            areaId: area.id,
            previousEmployeeIds: current,
            employeeIds: selected,
          );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Area assignments updated.')),
        );
      }
    } on Object catch (error) {
      if (context.mounted) _showError(context, error);
    }
  }

  void _showError(BuildContext context, Object error) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(error.toString())));
  }
}

class _AreaList extends StatelessWidget {
  const _AreaList({
    required this.areas,
    required this.employees,
    required this.onEdit,
    required this.onAssign,
  });

  final List<DeliveryArea> areas;
  final List<EmployeeMember> employees;
  final ValueChanged<DeliveryArea> onEdit;
  final ValueChanged<DeliveryArea> onAssign;

  @override
  Widget build(BuildContext context) {
    if (areas.isEmpty) {
      return const EmptyStateCard(
        icon: Icons.map_outlined,
        title: 'No delivery areas',
        message: 'Create the first area before assigning employee coverage.',
      );
    }
    return Column(
      children: [
        for (final area in areas) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 10, 14),
              child: Row(
                children: [
                  Icon(
                    area.isActive ? Icons.location_on_outlined : Icons.block,
                    color:
                        area.isActive
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          area.name,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${area.isActive ? 'Active' : 'Inactive'} • '
                          '${_assignedCount(area, employees)} employees',
                          style: const TextStyle(color: Color(0xFF486581)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => onAssign(area),
                    tooltip: 'Assign employees',
                    icon: const Icon(Icons.group_add_outlined),
                  ),
                  IconButton(
                    onPressed: () => onEdit(area),
                    tooltip: 'Edit area',
                    icon: const Icon(Icons.edit_outlined),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  int _assignedCount(DeliveryArea area, List<EmployeeMember> employees) =>
      employees.where((member) => member.areaIds.contains(area.id)).length;
}

class _AreaDraft {
  const _AreaDraft({required this.name, required this.isActive});

  final String name;
  final bool isActive;
}

class _AreaDialog extends StatefulWidget {
  const _AreaDialog({this.area});

  final DeliveryArea? area;

  @override
  State<_AreaDialog> createState() => _AreaDialogState();
}

class _AreaDialogState extends State<_AreaDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late bool _isActive;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.area?.name ?? '');
    _isActive = widget.area?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.area == null ? 'Create area' : 'Edit area'),
      content: SizedBox(
        width: 440,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Area name'),
                validator:
                    (value) =>
                        (value?.trim().isEmpty ?? true)
                            ? 'Enter an area name.'
                            : null,
              ),
              if (widget.area != null)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _isActive,
                  title: const Text('Active area'),
                  subtitle: const Text(
                    'Inactive areas remain available in historical records.',
                  ),
                  onChanged: (value) => setState(() => _isActive = value),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.pop(
              context,
              _AreaDraft(name: _nameController.text, isActive: _isActive),
            );
          },
          child: Text(widget.area == null ? 'Create area' : 'Save changes'),
        ),
      ],
    );
  }
}

class _EmployeeAssignmentDialog extends StatefulWidget {
  const _EmployeeAssignmentDialog({
    required this.area,
    required this.employees,
    required this.selectedEmployeeIds,
  });

  final DeliveryArea area;
  final List<EmployeeMember> employees;
  final Set<String> selectedEmployeeIds;

  @override
  State<_EmployeeAssignmentDialog> createState() =>
      _EmployeeAssignmentDialogState();
}

class _EmployeeAssignmentDialogState extends State<_EmployeeAssignmentDialog> {
  late Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = {...widget.selectedEmployeeIds};
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Assign ${widget.area.name}'),
      content: SizedBox(
        width: 460,
        child:
            widget.employees.isEmpty
                ? const Text(
                  'No employees have accepted an invitation yet. Create an invitation first.',
                )
                : SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final employee in widget.employees)
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          value: _selected.contains(employee.uid),
                          title: Text(employee.displayName),
                          subtitle: Text(
                            employee.isActive ? employee.email : 'Inactive',
                          ),
                          onChanged:
                              employee.isActive ||
                                      _selected.contains(employee.uid)
                                  ? (selected) => setState(() {
                                    selected == true
                                        ? _selected.add(employee.uid)
                                        : _selected.remove(employee.uid);
                                  })
                                  : null,
                        ),
                    ],
                  ),
                ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, Set.unmodifiable(_selected)),
          child: const Text('Save assignments'),
        ),
      ],
    );
  }
}
