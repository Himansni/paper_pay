import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:paper_route/core/presentation/async_state_cards.dart';
import 'package:paper_route/features/areas/domain/delivery_area.dart';
import 'package:paper_route/features/areas/presentation/area_providers.dart';
import 'package:paper_route/features/auth/domain/access_policy.dart';
import 'package:paper_route/features/auth/domain/app_user.dart';
import 'package:paper_route/features/customers/domain/customer.dart';
import 'package:paper_route/features/customers/domain/customer_removal_request.dart';
import 'package:paper_route/features/customers/presentation/customer_providers.dart';
import 'package:paper_route/features/employees/domain/employee_member.dart';
import 'package:paper_route/features/employees/presentation/employee_providers.dart';
import 'package:paper_route/l10n/app_localizations.dart';

class CustomersPage extends ConsumerStatefulWidget {
  const CustomersPage({required this.user, this.initialSearch = '', super.key});

  final AppUser user;
  final String initialSearch;

  @override
  ConsumerState<CustomersPage> createState() => _CustomersPageState();
}

class _CustomersPageState extends ConsumerState<CustomersPage> {
  static const _accessPolicy = AccessPolicy();
  late final TextEditingController _searchController;
  final _scrollController = ScrollController();
  final _customers = <Customer>[];
  CustomerStatus _status = CustomerStatus.active;
  CustomerSearchField _searchField = CustomerSearchField.name;
  String _areaId = '';
  String _activeSearch = '';
  CustomerPageCursor? _cursor;
  bool _hasMore = false;
  bool _isLoading = false;
  String? _error;
  int _requestVersion = 0;

  @override
  void initState() {
    super.initState();
    _activeSearch = widget.initialSearch.trim();
    _searchController = TextEditingController(text: _activeSearch);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load(reset: true));
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load({bool reset = false}) async {
    if (_isLoading && !reset) return;
    final requestVersion = ++_requestVersion;
    if (reset) {
      _cursor = null;
      _hasMore = false;
    }
    setState(() {
      _isLoading = true;
      _error = null;
      if (reset) _customers.clear();
    });

    try {
      final businessId = widget.user.businessId!;
      final page = await ref
          .read(customerRepositoryProvider)
          .fetchCustomers(
            CustomerListRequest(
              businessId: businessId,
              requesterId: widget.user.uid,
              isHead: widget.user.isHead,
              status: _status,
              areaId: _areaId,
              searchField: _activeSearch.isEmpty ? null : _searchField,
              searchTerm: _activeSearch,
              cursor: reset ? null : _cursor,
            ),
          );
      if (!mounted || requestVersion != _requestVersion) return;
      setState(() {
        _customers.addAll(page.customers);
        _cursor = page.nextCursor;
        _hasMore = page.hasMore;
        _isLoading = false;
      });
    } on Object catch (error) {
      if (!mounted || requestVersion != _requestVersion) return;
      setState(() {
        _error = error.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _applySearch() async {
    FocusScope.of(context).unfocus();
    setState(() => _activeSearch = _searchController.text.trim());
    await _load(reset: true);
  }

  Future<void> _clearSearch() async {
    _searchController.clear();
    setState(() => _activeSearch = '');
    await _load(reset: true);
  }

  Future<void> _open(String location) async {
    final changed = await context.push<bool>(location);
    if (changed == true && mounted) await _load(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    final businessId = widget.user.businessId!;
    final areas = ref.watch(deliveryAreasProvider(businessId));
    final members =
        widget.user.isHead
            ? ref.watch(employeeMembersProvider(businessId))
            : const AsyncData<List<EmployeeMember>>([]);
    final areaItems = areas.asData?.value ?? const <DeliveryArea>[];
    final memberItems = members.asData?.value ?? const <EmployeeMember>[];
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.go('/')),
        title: Text(widget.user.isHead ? (l10n?.customersTitle ?? 'Customers') : 'My customers'),
        actions: [
          if (_accessPolicy.canCreateCustomer(widget.user))
            IconButton(
              key: const ValueKey('import-customers-nav-button'),
              icon: const Icon(Icons.upload_file_outlined),
              tooltip: 'Bulk Import Customers (CSV)',
              onPressed: () => _open('/customers/import'),
            ),
        ],
      ),
      floatingActionButton:
          _accessPolicy.canCreateCustomer(widget.user)
              ? FloatingActionButton.extended(
                onPressed: () => _open('/customers/new'),
                icon: const Icon(Icons.person_add_alt_1),
                label: Text(l10n?.customerNewTitle ?? 'New customer'),
              )
              : null,
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: () => _load(reset: true),
          child: ListView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 104),
            children: [
              Text(
                widget.user.isHead
                    ? 'Customer directory'
                    : 'Your assigned route',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                widget.user.isHead
                    ? 'Search and manage customer records without loading the entire business directory.'
                    : 'Only customers currently assigned to you are returned by Firestore.',
                style: const TextStyle(color: Color(0xFF486581), height: 1.4),
              ),
              const SizedBox(height: 18),
              _SearchAndFilterCard(
                searchController: _searchController,
                searchField: _searchField,
                status: _status,
                areaId: _areaId,
                areas: areaItems,
                isSearching: _isLoading,
                hasActiveSearch: _activeSearch.isNotEmpty,
                onSearchFieldChanged:
                    (value) => setState(() => _searchField = value),
                onStatusChanged: (value) {
                  setState(() => _status = value);
                  _load(reset: true);
                },
                onAreaChanged: (value) {
                  setState(() => _areaId = value);
                  _load(reset: true);
                },
                onSearch: _applySearch,
                onClear: _clearSearch,
              ),
              if (areas.hasError) ...[
                const SizedBox(height: 12),
                Text(
                  'Area filters are temporarily unavailable: ${areas.error}',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              if (members.hasError && widget.user.isHead) ...[
                const SizedBox(height: 12),
                Text(
                  'Employee names are temporarily unavailable: ${members.error}',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 18),
              if (_customers.isEmpty && _isLoading)
                const Padding(
                  padding: EdgeInsets.all(36),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_customers.isEmpty && _error != null)
                AsyncErrorCard(
                  message: _error!,
                  onRetry: () => _load(reset: true),
                )
              else if (_customers.isEmpty)
                EmptyStateCard(
                  icon:
                      _activeSearch.isEmpty
                          ? Icons.person_search_outlined
                          : Icons.search_off_outlined,
                  title:
                      _activeSearch.isEmpty
                          ? 'No ${_status.label.toLowerCase()} customers'
                          : 'No matching customers',
                  message:
                      _activeSearch.isEmpty
                          ? (_accessPolicy.canCreateCustomer(widget.user)
                              ? 'Create the first customer or change the status and area filters.'
                              : 'No assigned customer records match these filters.')
                          : 'Try another ${_searchField.label.toLowerCase()}, area, or status.',
                )
              else ...[
                Text(
                  '${_customers.length} customer${_customers.length == 1 ? '' : 's'} loaded',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: const Color(0xFF486581),
                  ),
                ),
                const SizedBox(height: 10),
                for (final customer in _customers) ...[
                  _CustomerCard(
                    customer: customer,
                    areaName: _nameForArea(areaItems, customer.areaId),
                    employeeName:
                        widget.user.isHead
                            ? _nameForEmployee(
                              memberItems,
                              customer.assignedEmployeeId,
                            )
                            : '',
                    onTap:
                        () => _open(
                          '/customers/${Uri.encodeComponent(customer.id)}',
                        ),
                  ),
                  const SizedBox(height: 10),
                ],
                if (_error != null)
                  AsyncErrorCard(message: _error!, onRetry: _load),
                if (_isLoading)
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_hasMore)
                  Center(
                    child: OutlinedButton.icon(
                      onPressed: _load,
                      icon: const Icon(Icons.expand_more),
                      label: Text(l10n?.loadMoreCustomers ?? 'Load more customers'),
                    ),
                  )
                else
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Center(
                      child: Text(
                        'End of results',
                        style: TextStyle(color: Color(0xFF829AB1)),
                      ),
                    ),
                  ),
              ],

              // Pending Removal Requests section (positioned after active customers)
              if (_status == CustomerStatus.active) ...[
                Builder(
                  builder: (context) {
                    final pendingAsync = ref.watch(
                      pendingRemovalRequestsProvider(
                        (
                          businessId: widget.user.businessId!,
                          requesterId: widget.user.uid,
                          isHead: widget.user.isHead,
                        ),
                      ),
                    );
                    final pendingList =
                        pendingAsync.asData?.value ??
                        const <CustomerRemovalRequest>[];
                    if (pendingList.isEmpty) return const SizedBox.shrink();

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 24),
                        const Divider(),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(
                              Icons.warning_amber_rounded,
                              color: Color(0xFFD32F2F),
                              size: 22,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Pending Removal Requests (${pendingList.length})',
                              style: const TextStyle(
                                color: Color(0xFFD32F2F),
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Customers with requested cancellations. Head review is required before archiving.',
                          style: TextStyle(
                            color: Color(0xFF627D98),
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 12),
                        for (final req in pendingList) ...[
                          _PendingRemovalRequestCard(
                            request: req,
                            isHead: widget.user.isHead,
                            onApprove: () => _reviewRemoval(req, approved: true),
                            onReject: () => _reviewRemoval(req, approved: false),
                            onTapCustomer:
                                () => _open(
                                  '/customers/${Uri.encodeComponent(req.customerId)}',
                                ),
                          ),
                          const SizedBox(height: 10),
                        ],
                      ],
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
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
                  ? 'Approving will archive "${req.customerName}" (${req.customerCode}). All historical bills, ledger lines, and payments will be safely preserved.'
                  : 'Rejecting will keep "${req.customerName}" active on the delivery route.',
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
        _load(reset: true);
      }
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Action failed: $error'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  String _nameForArea(List<DeliveryArea> areas, String areaId) =>
      areas
          .where((area) => area.id == areaId)
          .map((area) => area.name)
          .firstOrNull ??
      'Unknown area';

  String _nameForEmployee(List<EmployeeMember> members, String employeeId) {
    if (employeeId.isEmpty) return 'Unassigned';
    return members
            .where((member) => member.uid == employeeId)
            .map(
              (member) =>
                  member.displayName.isEmpty
                      ? member.email
                      : member.displayName,
            )
            .firstOrNull ??
        'Unknown employee';
  }
}

class _PendingRemovalRequestCard extends StatelessWidget {
  const _PendingRemovalRequestCard({
    required this.request,
    required this.isHead,
    required this.onApprove,
    required this.onReject,
    required this.onTapCustomer,
  });

  final CustomerRemovalRequest request;
  final bool isHead;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onTapCustomer;

  @override
  Widget build(BuildContext context) {
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
                    'REMOVAL REQUESTED',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: onTapCustomer,
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: const Text('View Customer'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              request.customerName,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 17,
                color: Color(0xFF102A43),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Code: ${request.customerCode} • Requested by: ${request.requestedByName}',
              style: const TextStyle(color: Color(0xFF486581), fontSize: 13),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFFCDD2)),
              ),
              child: Text(
                'Reason: ${request.reason}',
                style: const TextStyle(
                  color: Color(0xFF334E68),
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (isHead) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: onReject,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF486581),
                    ),
                    child: const Text('Reject Request'),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    onPressed: onApprove,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFD32F2F),
                    ),
                    icon: const Icon(Icons.archive_outlined, size: 18),
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
}

class _SearchAndFilterCard extends StatelessWidget {
  const _SearchAndFilterCard({
    required this.searchController,
    required this.searchField,
    required this.status,
    required this.areaId,
    required this.areas,
    required this.isSearching,
    required this.hasActiveSearch,
    required this.onSearchFieldChanged,
    required this.onStatusChanged,
    required this.onAreaChanged,
    required this.onSearch,
    required this.onClear,
  });

  final TextEditingController searchController;
  final CustomerSearchField searchField;
  final CustomerStatus status;
  final String areaId;
  final List<DeliveryArea> areas;
  final bool isSearching;
  final bool hasActiveSearch;
  final ValueChanged<CustomerSearchField> onSearchFieldChanged;
  final ValueChanged<CustomerStatus> onStatusChanged;
  final ValueChanged<String> onAreaChanged;
  final VoidCallback onSearch;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<CustomerSearchField>(
                    value: searchField,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Search by'),
                    items: [
                      for (final field in CustomerSearchField.values)
                        DropdownMenuItem(
                          value: field,
                          child: Text(field.label),
                        ),
                    ],
                    onChanged: (value) {
                      if (value != null) onSearchFieldChanged(value);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: searchController,
                    textInputAction: TextInputAction.search,
                    keyboardType:
                        searchField == CustomerSearchField.phone
                            ? TextInputType.phone
                            : TextInputType.text,
                    decoration: InputDecoration(
                      labelText: 'Search ${searchField.label.toLowerCase()}',
                      prefixIcon: const Icon(Icons.search),
                    ),
                    onSubmitted: (_) => onSearch(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<CustomerStatus>(
                    value: status,
                    decoration: const InputDecoration(labelText: 'Status'),
                    items: [
                      for (final item in CustomerStatus.values)
                        DropdownMenuItem(value: item, child: Text(item.label)),
                    ],
                    onChanged: (value) {
                      if (value != null) onStatusChanged(value);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: areaId,
                    decoration: const InputDecoration(labelText: 'Area'),
                    items: [
                      DropdownMenuItem(
                        value: '',
                        child: Text(l10n?.allAreas ?? 'All areas'),
                      ),
                      for (final area in areas)
                        DropdownMenuItem(
                          value: area.id,
                          child: Text(area.name),
                        ),
                    ],
                    onChanged: (value) => onAreaChanged(value ?? ''),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (hasActiveSearch)
                  TextButton(
                    onPressed: isSearching ? null : onClear,
                    child: Text(l10n?.clearSearch ?? 'Clear search'),
                  ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: isSearching ? null : onSearch,
                  icon: const Icon(Icons.search),
                  label: Text(l10n?.commonSearch ?? 'Search'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CustomerCard extends StatelessWidget {
  const _CustomerCard({
    required this.customer,
    required this.areaName,
    required this.employeeName,
    required this.onTap,
  });

  final Customer customer;
  final String areaName;
  final String employeeName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                child: Icon(
                  customer.isArchived
                      ? Icons.person_off_outlined
                      : Icons.person_outline,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            customer.name,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                        if (customer.isArchived)
                          const Chip(label: Text('Archived')),
                      ],
                    ),
                    const SizedBox(height: 3),
                    SelectableText(
                      customer.customerCode,
                      style: const TextStyle(color: Color(0xFF486581)),
                    ),
                    const SizedBox(height: 8),
                    Text('${customer.phone} • $areaName'),
                    if (customer.addressSummary.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        customer.addressSummary,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF486581),
                          height: 1.35,
                        ),
                      ),
                    ],
                    if (employeeName.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        'Assigned: $employeeName',
                        style: const TextStyle(color: Color(0xFF486581)),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
