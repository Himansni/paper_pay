import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:paper_route/core/presentation/async_state_cards.dart';
import 'package:paper_route/features/areas/domain/delivery_area.dart';
import 'package:paper_route/features/areas/presentation/area_providers.dart';
import 'package:paper_route/features/auth/domain/access_policy.dart';
import 'package:paper_route/features/auth/domain/app_user.dart';
import 'package:paper_route/features/employees/domain/employee_invitation.dart';
import 'package:paper_route/features/employees/domain/employee_member.dart';
import 'package:paper_route/features/employees/presentation/employee_providers.dart';

class EmployeesPage extends ConsumerWidget {
  const EmployeesPage({required this.user, super.key});

  final AppUser user;

  static const Map<String, String> _permissionLabels = {
    PermissionKey.addCustomers: 'Add customers',
    PermissionKey.editAssignedCustomers: 'Edit assigned customers',
    PermissionKey.manageAssignedSubscriptions:
        'Manage assigned customer subscriptions',
    PermissionKey.recordPayments: 'Record payments',
    PermissionKey.recordDeliveryExceptions: 'Record delivery exceptions',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final businessId = user.businessId!;
    final members = ref.watch(employeeMembersProvider(businessId));
    final invitations = ref.watch(employeeInvitationsProvider(businessId));
    final areas =
        ref.watch(deliveryAreasProvider(businessId)).asData?.value ??
        const <DeliveryArea>[];

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.go('/')),
        title: const Text('Employees'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _createInvitation(context, ref, areas),
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Invite employee'),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
          children: [
            Text(
              'Team access',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            const Text(
              'Invite verified employees, control their operational permissions, and suspend access without deleting history.',
              style: TextStyle(color: Color(0xFF627D98), height: 1.4),
            ),
            const SizedBox(height: 20),
            members.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error:
                  (error, _) => AsyncErrorCard(
                    message: 'Could not load members. $error',
                    onRetry:
                        () =>
                            ref.invalidate(employeeMembersProvider(businessId)),
                  ),
              data:
                  (items) => _MemberList(
                    members: items,
                    onEdit: (member) => _editMember(context, ref, member),
                  ),
            ),
            const SizedBox(height: 28),
            Text(
              'Invitations',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            invitations.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error:
                  (error, _) => AsyncErrorCard(
                    message: 'Could not load invitations. $error',
                    onRetry:
                        () => ref.invalidate(
                          employeeInvitationsProvider(businessId),
                        ),
                  ),
              data:
                  (items) => _InvitationList(
                    invitations: items,
                    onRevoke:
                        (invitation) =>
                            _revokeInvitation(context, ref, invitation),
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createInvitation(
    BuildContext context,
    WidgetRef ref,
    List<DeliveryArea> areas,
  ) async {
    final draft = await showDialog<_InvitationDraft>(
      context: context,
      builder:
          (context) => _InvitationDialog(
            areas: areas.where((area) => area.isActive).toList(),
            permissionLabels: _permissionLabels,
          ),
    );
    if (draft == null || !context.mounted) return;

    try {
      final code = await ref
          .read(employeeRepositoryProvider)
          .createInvitation(
            businessId: user.businessId!,
            actorId: user.uid,
            email: draft.email,
            permissions: draft.permissions,
            areaIds: draft.areaIds,
            expiresAt: DateTime.now().add(const Duration(days: 7)),
          );
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder:
            (dialogContext) => AlertDialog(
              title: const Text('Invitation created'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Share this one-time code and the business ID through a trusted channel:',
                  ),
                  const SizedBox(height: 12),
                  SelectableText(
                    code,
                    style: Theme.of(dialogContext).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text('Business ID: ${user.businessId}'),
                ],
              ),
              actions: [
                TextButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: code));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Invitation code copied.')),
                    );
                  },
                  icon: const Icon(Icons.copy),
                  label: const Text('Copy code'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Done'),
                ),
              ],
            ),
      );
    } on Object catch (error) {
      if (context.mounted) _showError(context, error);
    }
  }

  Future<void> _editMember(
    BuildContext context,
    WidgetRef ref,
    EmployeeMember member,
  ) async {
    if (member.isHead) return;
    final draft = await showDialog<_MemberDraft>(
      context: context,
      builder:
          (context) => _MemberDialog(
            member: member,
            permissionLabels: _permissionLabels,
          ),
    );
    if (draft == null || !context.mounted) return;
    try {
      await ref
          .read(employeeRepositoryProvider)
          .updateMemberAccess(
            businessId: user.businessId!,
            actorId: user.uid,
            memberId: member.uid,
            displayName: draft.displayName,
            phone: draft.phone,
            notes: draft.notes,
            isActive: draft.isActive,
            permissions: draft.permissions,
          );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Employee access updated.')),
        );
      }
    } on Object catch (error) {
      if (context.mounted) _showError(context, error);
    }
  }

  Future<void> _revokeInvitation(
    BuildContext context,
    WidgetRef ref,
    EmployeeInvitation invitation,
  ) async {
    try {
      await ref
          .read(employeeRepositoryProvider)
          .revokeInvitation(
            businessId: user.businessId!,
            actorId: user.uid,
            invitationId: invitation.id,
          );
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Invitation revoked.')));
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

class _MemberList extends StatelessWidget {
  const _MemberList({required this.members, required this.onEdit});

  final List<EmployeeMember> members;
  final ValueChanged<EmployeeMember> onEdit;

  @override
  Widget build(BuildContext context) {
    if (members.isEmpty) {
      return const EmptyStateCard(
        icon: Icons.group_outlined,
        title: 'No members found',
        message: 'Create an invitation to onboard the first employee.',
      );
    }
    return Column(
      children: [
        for (final member in members) ...[
          Card(
            child: ListTile(
              contentPadding: const EdgeInsets.fromLTRB(18, 8, 10, 8),
              leading: CircleAvatar(
                child: Text(
                  member.displayName.isEmpty
                      ? '?'
                      : member.displayName.substring(0, 1).toUpperCase(),
                ),
              ),
              title: Text(
                member.displayName.isEmpty ? member.email : member.displayName,
              ),
              subtitle: Text(
                '${member.isHead ? 'Head' : 'Employee'} • ${member.isActive ? 'Active' : 'Inactive'}\n'
                '${member.permissions.length} permissions • ${member.areaIds.length} areas',
              ),
              isThreeLine: true,
              trailing:
                  member.isHead
                      ? const Chip(label: Text('Owner'))
                      : IconButton(
                        onPressed: () => onEdit(member),
                        tooltip: 'Manage employee',
                        icon: const Icon(Icons.manage_accounts_outlined),
                      ),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _InvitationList extends StatelessWidget {
  const _InvitationList({required this.invitations, required this.onRevoke});

  final List<EmployeeInvitation> invitations;
  final ValueChanged<EmployeeInvitation> onRevoke;

  @override
  Widget build(BuildContext context) {
    if (invitations.isEmpty) {
      return const EmptyStateCard(
        icon: Icons.mark_email_unread_outlined,
        title: 'No invitations yet',
        message: 'Pending and accepted invitations will appear here.',
      );
    }
    return Column(
      children: [
        for (final invitation in invitations) ...[
          Card(
            child: ListTile(
              contentPadding: const EdgeInsets.fromLTRB(18, 8, 10, 8),
              title: Text(invitation.email),
              subtitle: Text(
                '${invitation.status.toUpperCase()} • expires ${_date(invitation.expiresAt)}\n'
                'Code: ${invitation.id}',
              ),
              isThreeLine: true,
              trailing:
                  invitation.isPending && !invitation.isExpired
                      ? TextButton(
                        onPressed: () => onRevoke(invitation),
                        child: const Text('Revoke'),
                      )
                      : null,
            ),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  static String _date(DateTime value) =>
      value.toLocal().toIso8601String().split('T').first;
}

class _InvitationDraft {
  const _InvitationDraft({
    required this.email,
    required this.permissions,
    required this.areaIds,
  });

  final String email;
  final Set<String> permissions;
  final Set<String> areaIds;
}

class _InvitationDialog extends StatefulWidget {
  const _InvitationDialog({
    required this.areas,
    required this.permissionLabels,
  });

  final List<DeliveryArea> areas;
  final Map<String, String> permissionLabels;

  @override
  State<_InvitationDialog> createState() => _InvitationDialogState();
}

class _InvitationDialogState extends State<_InvitationDialog> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final Set<String> _permissions = {};
  final Set<String> _areaIds = {};

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Invite employee'),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Employee email',
                  ),
                  validator: (value) {
                    final email = value?.trim() ?? '';
                    return email.contains('@') ? null : 'Enter a valid email.';
                  },
                ),
                const SizedBox(height: 18),
                const Text('Permissions'),
                for (final entry in widget.permissionLabels.entries)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _permissions.contains(entry.key),
                    title: Text(entry.value),
                    onChanged:
                        (selected) => setState(() {
                          selected == true
                              ? _permissions.add(entry.key)
                              : _permissions.remove(entry.key);
                        }),
                  ),
                const SizedBox(height: 10),
                const Text('Initial areas'),
                if (widget.areas.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'No active areas yet. You can assign areas later.',
                      style: TextStyle(color: Color(0xFF627D98)),
                    ),
                  )
                else
                  for (final area in widget.areas)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _areaIds.contains(area.id),
                      title: Text(area.name),
                      onChanged:
                          (selected) => setState(() {
                            selected == true
                                ? _areaIds.add(area.id)
                                : _areaIds.remove(area.id);
                          }),
                    ),
              ],
            ),
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
              _InvitationDraft(
                email: _emailController.text,
                permissions: Set.unmodifiable(_permissions),
                areaIds: Set.unmodifiable(_areaIds),
              ),
            );
          },
          child: const Text('Create invitation'),
        ),
      ],
    );
  }
}

class _MemberDraft {
  const _MemberDraft({
    required this.displayName,
    required this.phone,
    required this.notes,
    required this.isActive,
    required this.permissions,
  });

  final String displayName;
  final String phone;
  final String notes;
  final bool isActive;
  final Set<String> permissions;
}

class _MemberDialog extends StatefulWidget {
  const _MemberDialog({required this.member, required this.permissionLabels});

  final EmployeeMember member;
  final Map<String, String> permissionLabels;

  @override
  State<_MemberDialog> createState() => _MemberDialogState();
}

class _MemberDialogState extends State<_MemberDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _notesController;
  late bool _isActive;
  late Set<String> _permissions;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.member.displayName);
    _phoneController = TextEditingController(text: widget.member.phone);
    _notesController = TextEditingController(text: widget.member.notes);
    _isActive = widget.member.isActive;
    _permissions = {...widget.member.permissions};
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Manage employee'),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Display name'),
                  validator:
                      (value) =>
                          (value?.trim().isEmpty ?? true)
                              ? 'Enter the employee name.'
                              : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Phone'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notesController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Internal notes',
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _isActive,
                  title: const Text('Active access'),
                  subtitle: const Text(
                    'Inactive employees cannot access business data.',
                  ),
                  onChanged: (value) => setState(() => _isActive = value),
                ),
                const Divider(),
                for (final entry in widget.permissionLabels.entries)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _permissions.contains(entry.key),
                    title: Text(entry.value),
                    onChanged:
                        (selected) => setState(() {
                          selected == true
                              ? _permissions.add(entry.key)
                              : _permissions.remove(entry.key);
                        }),
                  ),
              ],
            ),
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
              _MemberDraft(
                displayName: _nameController.text,
                phone: _phoneController.text,
                notes: _notesController.text,
                isActive: _isActive,
                permissions: Set.unmodifiable(_permissions),
              ),
            );
          },
          child: const Text('Save changes'),
        ),
      ],
    );
  }
}
