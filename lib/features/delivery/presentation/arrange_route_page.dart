import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paper_route/core/presentation/async_state_cards.dart';
import 'package:paper_route/features/auth/domain/access_policy.dart';
import 'package:paper_route/features/auth/domain/app_user.dart';
import 'package:paper_route/features/customers/domain/customer.dart';
import 'package:paper_route/features/customers/presentation/customer_providers.dart';
import 'package:paper_route/features/delivery/presentation/delivery_providers.dart';
import 'package:paper_route/l10n/app_localizations.dart';

class ArrangeRoutePage extends ConsumerStatefulWidget {
  const ArrangeRoutePage({
    required this.user,
    required this.areaId,
    required this.areaName,
    super.key,
  });

  final AppUser user;
  final String areaId;
  final String areaName;

  @override
  ConsumerState<ArrangeRoutePage> createState() => _ArrangeRoutePageState();
}

class _ArrangeRoutePageState extends ConsumerState<ArrangeRoutePage> {
  static const _accessPolicy = AccessPolicy();
  List<Customer>? _orderedCustomers;
  bool _isDirty = false;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final businessId = widget.user.businessId!;
    final canArrange = _accessPolicy.canArrangeRoutes(
      member: widget.user,
      areaId: widget.areaId,
    );

    if (!canArrange) {
      return Scaffold(
        appBar: AppBar(
          title: Text(l10n?.arrangeDeliveryRoute ?? 'Arrange Delivery Route'),
        ),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: EmptyStateCard(
            icon: Icons.lock_outline,
            title: l10n?.commonNotice ?? 'Permission Denied',
            message:
                'You do not have permission to rearrange route stops for this area.',
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n?.arrangeDeliveryRoute ?? 'Arrange Delivery Route',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            Text(
              widget.areaName,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: FilledButton(
              onPressed:
                  (_isDirty && !_isSaving) ? () => _saveOrder(context) : null,
              child: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(l10n?.commonSave ?? 'Save'),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: _orderedCustomers != null
            ? _buildReorderableList(context)
            : FutureBuilder<List<Customer>>(
                future: _loadInitialCustomers(businessId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Padding(
                      padding: const EdgeInsets.all(20),
                      child: AsyncErrorCard(
                        message: 'Could not load customers. ${snapshot.error}',
                        onRetry: () => setState(() {
                          _orderedCustomers = null;
                        }),
                      ),
                    );
                  }

                  _orderedCustomers = snapshot.data ?? [];
                  return _buildReorderableList(context);
                },
              ),
      ),
    );
  }

  Future<List<Customer>> _loadInitialCustomers(String businessId) async {
    final customerRepo = ref.read(customerRepositoryProvider);
    final deliveryRepo = ref.read(deliveryRepositoryProvider);

    final customerPage = await customerRepo.fetchCustomers(
      CustomerListRequest(
        businessId: businessId,
        requesterId: widget.user.uid,
        isHead: widget.user.isHead,
        status: CustomerStatus.active,
        areaId: widget.areaId,
        pageSize: 250,
      ),
    );

    final activeCustomers = customerPage.customers;
    final routeOrder = await deliveryRepo.getRouteOrder(
      businessId: businessId,
      areaId: widget.areaId,
    );

    if (routeOrder == null || routeOrder.customerIds.isEmpty) {
      return activeCustomers;
    }

    // Map existing positions according to persisted route order
    final Map<String, Customer> customerMap = {
      for (final c in activeCustomers) c.id: c,
    };

    final List<Customer> ordered = [];
    for (final id in routeOrder.customerIds) {
      final customer = customerMap.remove(id);
      if (customer != null) {
        ordered.add(customer);
      }
    }

    // Append any active customers not present in the route order
    ordered.addAll(customerMap.values);
    return ordered;
  }

  Widget _buildReorderableList(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final customers = _orderedCustomers!;

    if (customers.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: EmptyStateCard(
          icon: Icons.person_search_outlined,
          title: l10n?.commonNoData ?? 'No customers found',
          message: 'No active customers in this area to arrange.',
        ),
      );
    }

    return Column(
      children: [
        if (_errorMessage != null)
          Container(
            color: Theme.of(context).colorScheme.errorContainer,
            padding: const EdgeInsets.all(12),
            width: double.infinity,
            child: Text(
              _errorMessage!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onErrorContainer,
                fontSize: 13,
              ),
            ),
          ),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          child: Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 16,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Long-press or drag the handle on the right to reorder delivery stops.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ReorderableListView.builder(
            buildDefaultDragHandles: false,
            padding: const EdgeInsets.only(bottom: 32),
            itemCount: customers.length,
            onReorder: (oldIndex, newIndex) {
              setState(() {
                if (newIndex > oldIndex) {
                  newIndex -= 1;
                }
                final item = customers.removeAt(oldIndex);
                customers.insert(newIndex, item);
                _isDirty = true;
                _errorMessage = null;
              });
            },
            itemBuilder: (context, index) {
              final customer = customers[index];
              final addressSubtitle = [
                if (customer.houseNumber.isNotEmpty) customer.houseNumber,
                if (customer.buildingInfo.isNotEmpty) customer.buildingInfo,
                if (customer.address.isNotEmpty) customer.address,
                if (customer.landmark.isNotEmpty) customer.landmark,
              ].join(', ');

              return Container(
                key: ValueKey(customer.id),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
                    ),
                  ),
                ),
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: CircleAvatar(
                    radius: 14,
                    backgroundColor: Theme.of(context)
                        .colorScheme
                        .primaryContainer
                        .withValues(alpha: 0.7),
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color:
                            Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  title: Text(
                    customer.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  subtitle: addressSubtitle.isNotEmpty
                      ? Text(
                          addressSubtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                        )
                      : null,
                  trailing: ReorderableDragStartListener(
                    index: index,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      child: Icon(
                        Icons.drag_handle,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant
                            .withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _saveOrder(BuildContext context) async {
    if (_orderedCustomers == null || _orderedCustomers!.isEmpty) return;

    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    final successMessage = l10n?.routeOrderSaved ?? 'Route order saved successfully.';

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final customerIds = _orderedCustomers!.map((c) => c.id).toList();
      await ref.read(deliveryRepositoryProvider).saveRouteOrder(
            businessId: widget.user.businessId!,
            areaId: widget.areaId,
            customerIds: customerIds,
            actorUid: widget.user.uid,
          );

      ref.invalidate(morningRouteStopsProvider(widget.user));

      if (mounted) {
        setState(() {
          _isDirty = false;
          _isSaving = false;
        });

        messenger.showSnackBar(
          SnackBar(
            content: Text(successMessage),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _errorMessage = 'Could not save route order: $e';
        });
      }
    }
  }
}
