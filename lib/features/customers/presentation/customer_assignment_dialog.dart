import 'package:flutter/material.dart';
import 'package:paper_route/features/areas/domain/delivery_area.dart';
import 'package:paper_route/features/employees/domain/employee_member.dart';

class CustomerAssignmentDraft {
  const CustomerAssignmentDraft({
    required this.employeeId,
    required this.areaId,
  });

  final String employeeId;
  final String areaId;
}

Future<CustomerAssignmentDraft?> showCustomerAssignmentDialog({
  required BuildContext context,
  required String customerName,
  required String initialEmployeeId,
  required String initialAreaId,
  required List<EmployeeMember> employees,
  required List<DeliveryArea> areas,
}) => showDialog<CustomerAssignmentDraft>(
  context: context,
  builder:
      (context) => _CustomerAssignmentDialog(
        customerName: customerName,
        initialEmployeeId: initialEmployeeId,
        initialAreaId: initialAreaId,
        employees:
            employees
                .where((item) => item.isEmployee && item.isActive)
                .toList(),
        areas: areas.where((item) => item.isActive).toList(),
      ),
);

class _CustomerAssignmentDialog extends StatefulWidget {
  const _CustomerAssignmentDialog({
    required this.customerName,
    required this.initialEmployeeId,
    required this.initialAreaId,
    required this.employees,
    required this.areas,
  });

  final String customerName;
  final String initialEmployeeId;
  final String initialAreaId;
  final List<EmployeeMember> employees;
  final List<DeliveryArea> areas;

  @override
  State<_CustomerAssignmentDialog> createState() =>
      _CustomerAssignmentDialogState();
}

class _CustomerAssignmentDialogState extends State<_CustomerAssignmentDialog> {
  late String _areaId;
  late String _employeeId;

  List<EmployeeMember> get _availableEmployees =>
      widget.employees
          .where((employee) => employee.areaIds.contains(_areaId))
          .toList();

  @override
  void initState() {
    super.initState();
    _areaId =
        widget.areas.any((area) => area.id == widget.initialAreaId)
            ? widget.initialAreaId
            : '';
    _employeeId =
        _availableEmployees.any(
              (employee) => employee.uid == widget.initialEmployeeId,
            )
            ? widget.initialEmployeeId
            : '';
  }

  @override
  Widget build(BuildContext context) {
    final availableEmployees = _availableEmployees;
    return AlertDialog(
      title: Text('Assign ${widget.customerName}'),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<String>(
              value: _areaId,
              decoration: const InputDecoration(labelText: 'Delivery area'),
              items: [
                const DropdownMenuItem(
                  value: '',
                  child: Text('Select an area'),
                ),
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
                const DropdownMenuItem(
                  value: '',
                  child: Text('Keep unassigned'),
                ),
                for (final employee in availableEmployees)
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
                  _areaId.isEmpty
                      ? null
                      : (value) => setState(() => _employeeId = value ?? ''),
            ),
            if (_areaId.isNotEmpty && availableEmployees.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text(
                  'No active employee is assigned to this area. The customer can remain unassigned.',
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
              _areaId.isEmpty
                  ? null
                  : () => Navigator.pop(
                    context,
                    CustomerAssignmentDraft(
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
