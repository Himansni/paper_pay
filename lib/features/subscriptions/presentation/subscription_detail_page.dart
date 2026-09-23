import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:paper_route/core/domain/local_date.dart';
import 'package:paper_route/core/presentation/async_state_cards.dart';
import 'package:paper_route/features/auth/domain/access_policy.dart';
import 'package:paper_route/features/auth/domain/app_user.dart';
import 'package:paper_route/features/customers/domain/customer.dart';
import 'package:paper_route/features/customers/presentation/customer_providers.dart';
import 'package:paper_route/features/subscriptions/domain/customer_subscription.dart';
import 'package:paper_route/features/subscriptions/presentation/subscription_providers.dart';
import 'package:paper_route/l10n/app_localizations.dart';

class CustomerSubscriptionsSection extends ConsumerWidget {
  const CustomerSubscriptionsSection({
    required this.user,
    required this.customer,
    super.key,
  });

  final AppUser user;
  final Customer customer;

  static const _policy = AccessPolicy();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final key = (businessId: user.businessId!, customerId: customer.id);
    final subscriptions = ref.watch(customerSubscriptionsProvider(key));
    final canManage = _policy.canManageSubscription(
      member: user,
      customerBusinessId: customer.businessId,
      assignedEmployeeId: customer.assignedEmployeeId,
      customerAreaId: customer.areaId,
      isCustomerArchived: customer.isArchived,
    );
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
                    'Newspaper subscriptions',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (canManage)
                  TextButton.icon(
                    key: const ValueKey('add-subscription-action'),
                    onPressed:
                        () => context.push<bool>(
                          '/customers/${Uri.encodeComponent(customer.id)}/subscriptions/new',
                        ),
                    icon: const Icon(Icons.add),
                    label: const Text('Add'),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Multiple publications, dated terms, delivery days, and pauses are preserved independently.',
              style: TextStyle(color: Color(0xFF486581), height: 1.4),
            ),
            const SizedBox(height: 14),
            subscriptions.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error:
                  (error, _) => AsyncErrorCard(
                    message: 'Could not load subscriptions. $error',
                    onRetry:
                        () =>
                            ref.invalidate(customerSubscriptionsProvider(key)),
                  ),
              data: (items) {
                if (items.isEmpty) {
                  return EmptyStateCard(
                    icon: Icons.playlist_add_outlined,
                    title: 'No newspaper subscriptions',
                    message:
                        canManage
                            ? 'Add an active catalog newspaper to begin a dated delivery schedule.'
                            : 'No subscriptions are configured for this customer.',
                  );
                }
                final active = items.where((s) => s.isActive).toList();
                final paused = items.where((s) => s.isPaused).toList();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final subscription in items)
                      ListTile(
                        key: ValueKey('subscription-${subscription.id}'),
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          subscription.isEnded
                              ? Icons.stop_circle_outlined
                              : subscription.isPaused
                              ? Icons.pause_circle_outline
                              : Icons.newspaper_outlined,
                        ),
                        title: Text(
                          subscription.newspaperName,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          '${subscription.status.label} • Qty ${subscription.quantity}\n'
                          '${DeliveryWeekday.describe(subscription.deliveryWeekdays)}',
                        ),
                        isThreeLine: true,
                        trailing: const Icon(Icons.chevron_right),
                        onTap:
                            () => context.push<bool>(
                              '/customers/${Uri.encodeComponent(customer.id)}/subscriptions/${Uri.encodeComponent(subscription.id)}',
                            ),
                      ),
                    if (canManage && (active.length > 1 || paused.isNotEmpty)) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (active.isNotEmpty)
                            OutlinedButton.icon(
                              key: const ValueKey('pause-all-subscriptions-button'),
                              onPressed: () => _pauseAll(context, ref, active, key),
                              icon: const Icon(Icons.pause_circle_outline),
                              label: Text('${l10n?.pauseAllSubscriptions ?? "Pause all"} (${active.length})'),
                            ),
                          if (paused.isNotEmpty)
                            FilledButton.icon(
                              key: const ValueKey('resume-all-subscriptions-button'),
                              onPressed: () => _resumeAll(context, ref, paused, key),
                              icon: const Icon(Icons.play_circle_outline),
                              label: Text('${l10n?.resumeAllSubscriptions ?? "Resume all"} (${paused.length})'),
                            ),
                        ],
                      ),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pauseAll(
    BuildContext context,
    WidgetRef ref,
    List<CustomerSubscription> active,
    ({String businessId, String customerId}) key,
  ) async {
    final draft = await showDialog<_PauseAllDraft>(
      context: context,
      builder: (context) => _PauseAllDialog(subscriptions: active),
    );
    if (draft == null || !context.mounted) return;
    try {
      await ref.read(subscriptionRepositoryProvider).pauseAllCustomerSubscriptions(
        actor: user,
        customerId: customer.id,
        startDate: draft.startDate,
        endDate: draft.endDate,
        reason: draft.reason,
        subscriptionIds: draft.subscriptionIds,
      );
      ref.invalidate(customerSubscriptionsProvider(key));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All selected subscriptions have been paused.')),
      );
    } catch (err) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not pause subscriptions. $err')),
      );
    }
  }

  Future<void> _resumeAll(
    BuildContext context,
    WidgetRef ref,
    List<CustomerSubscription> paused,
    ({String businessId, String customerId}) key,
  ) async {
    final date = await showDialog<LocalDate>(
      context: context,
      builder: (context) => const _DateDialog(
        title: 'Resume all deliveries',
        label: 'First resumed delivery date',
      ),
    );
    if (date == null || !context.mounted) return;
    try {
      await ref.read(subscriptionRepositoryProvider).resumeAllCustomerSubscriptions(
        actor: user,
        customerId: customer.id,
        resumeDate: date,
        subscriptionIds: paused.map((s) => s.id).toList(),
      );
      ref.invalidate(customerSubscriptionsProvider(key));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All paused subscriptions resumed.')),
      );
    } catch (err) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not resume subscriptions. $err')),
      );
    }
  }
}

class SubscriptionDetailRoutePage extends ConsumerWidget {
  const SubscriptionDetailRoutePage({
    required this.user,
    required this.customerId,
    required this.subscriptionId,
    super.key,
  });

  final AppUser user;
  final String customerId;
  final String subscriptionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customerKey = (businessId: user.businessId!, customerId: customerId);
    final subscriptionKey = (
      businessId: user.businessId!,
      customerId: customerId,
      subscriptionId: subscriptionId,
    );
    final customer = ref.watch(customerProvider(customerKey));
    final subscription = ref.watch(
      customerSubscriptionProvider(subscriptionKey),
    );
    if (customer.isLoading || subscription.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (customer.hasError || subscription.hasError) {
      return Scaffold(
        appBar: AppBar(title: const Text('Subscription')),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: AsyncErrorCard(
            message:
                'Could not load subscription. ${customer.error ?? subscription.error}',
            onRetry: () {
              ref.invalidate(customerProvider(customerKey));
              ref.invalidate(customerSubscriptionProvider(subscriptionKey));
            },
          ),
        ),
      );
    }
    final customerValue = customer.value;
    final subscriptionValue = subscription.value;
    if (customerValue == null || subscriptionValue == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Subscription')),
        body: const Padding(
          padding: EdgeInsets.all(20),
          child: EmptyStateCard(
            icon: Icons.event_busy_outlined,
            title: 'Subscription not found',
            message: 'The requested record is no longer available.',
          ),
        ),
      );
    }
    return SubscriptionDetailPage(
      user: user,
      customer: customerValue,
      subscription: subscriptionValue,
    );
  }
}

class SubscriptionDetailPage extends ConsumerStatefulWidget {
  const SubscriptionDetailPage({
    required this.user,
    required this.customer,
    required this.subscription,
    super.key,
  });

  final AppUser user;
  final Customer customer;
  final CustomerSubscription subscription;

  @override
  ConsumerState<SubscriptionDetailPage> createState() =>
      _SubscriptionDetailPageState();
}

class _SubscriptionDetailPageState
    extends ConsumerState<SubscriptionDetailPage> {
  static const _policy = AccessPolicy();
  bool _isBusy = false;

  @override
  Widget build(BuildContext context) {
    final subscription = widget.subscription;
    final key = (
      businessId: widget.user.businessId!,
      customerId: widget.customer.id,
      subscriptionId: subscription.id,
    );
    final versions = ref.watch(subscriptionVersionsProvider(key));
    final pauses = ref.watch(subscriptionPausesProvider(key));
    final audits =
        widget.user.isHead
            ? ref.watch(subscriptionAuditProvider(key))
            : const AsyncData<List<SubscriptionAuditEntry>>([]);
    final canManage = _policy.canManageSubscription(
      member: widget.user,
      customerBusinessId: widget.customer.businessId,
      assignedEmployeeId: widget.customer.assignedEmployeeId,
      customerAreaId: widget.customer.areaId,
      isCustomerArchived: widget.customer.isArchived,
    );
    final canEnd = _policy.canEndSubscription(
      member: widget.user,
      customerBusinessId: widget.customer.businessId,
      assignedEmployeeId: widget.customer.assignedEmployeeId,
      customerAreaId: widget.customer.areaId,
      isCustomerArchived: widget.customer.isArchived,
    );

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: _back),
        title: const Text('Subscription details'),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CircleAvatar(child: Icon(Icons.newspaper_outlined)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        subscription.newspaperName,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subscription.id,
                        style: const TextStyle(color: Color(0xFF486581)),
                      ),
                    ],
                  ),
                ),
                Chip(label: Text(subscription.status.label)),
              ],
            ),
            const SizedBox(height: 18),
            _InfoCard(
              title: 'Current terms',
              rows: [
                _InfoRow('Quantity', '${subscription.quantity}'),
                _InfoRow(
                  'Delivery days',
                  DeliveryWeekday.describe(subscription.deliveryWeekdays),
                ),
                _InfoRow('Started', subscription.startDate.toString()),
                _InfoRow(
                  'Current terms from',
                  subscription.currentEffectiveFrom.toString(),
                ),
                _InfoRow(
                  'Ends',
                  subscription.endDate?.toString() ?? 'No planned end',
                ),
                _InfoRow(
                  'Customer price',
                  subscription.customPricePaise == null
                      ? 'Uses catalog date-specific pricing'
                      : '${_money(subscription.customPricePaise!)} • Head authorized',
                ),
              ],
            ),
            if (canManage || (canEnd && !subscription.isEnded)) ...[
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (canManage)
                    OutlinedButton.icon(
                      onPressed:
                          _isBusy || subscription.isPaused
                              ? null
                              : () => context.push<bool>(
                                '/customers/${Uri.encodeComponent(widget.customer.id)}/subscriptions/${Uri.encodeComponent(subscription.id)}/change',
                              ),
                      icon: Icon(
                        subscription.isEnded
                            ? Icons.replay_outlined
                            : Icons.tune_outlined,
                      ),
                      label: Text(
                        subscription.isEnded ? 'Restart' : 'Change terms',
                      ),
                    ),
                  if (canManage && subscription.isActive)
                    OutlinedButton.icon(
                      onPressed: _isBusy ? null : () => _addPause(pauses),
                      icon: const Icon(Icons.pause_outlined),
                      label: const Text('Add pause'),
                    ),
                  if (canManage && subscription.isPaused)
                    FilledButton.icon(
                      onPressed:
                          _isBusy || subscription.currentPauseId.isEmpty
                              ? null
                              : _resume,
                      icon: const Icon(Icons.play_arrow_outlined),
                      label: const Text('Resume'),
                    ),
                  if (canEnd && !subscription.isEnded)
                    OutlinedButton.icon(
                      onPressed: _isBusy ? null : _end,
                      icon: const Icon(Icons.stop_circle_outlined),
                      label: const Text('End subscription'),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 14),
            _AsyncHistoryCard<SubscriptionPause>(
              title: 'Pause history',
              value: pauses,
              emptyMessage: 'No delivery pauses recorded.',
              rowBuilder:
                  (pause) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      pause.isOpen
                          ? Icons.pause_circle_filled_outlined
                          : Icons.event_available_outlined,
                    ),
                    title: Text(
                      '${pause.startDate} → ${pause.endDate?.toString() ?? 'Open'}',
                    ),
                    subtitle: Text(pause.reason),
                  ),
            ),
            const SizedBox(height: 14),
            _AsyncHistoryCard<SubscriptionVersion>(
              title: 'Terms history',
              value: versions,
              emptyMessage: 'No terms versions are available.',
              rowBuilder:
                  (version) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.history_outlined),
                    title: Text(
                      '${version.effectiveFrom} → ${version.effectiveTo?.toString() ?? 'Current'}',
                    ),
                    subtitle: Text(
                      'Qty ${version.quantity} • ${DeliveryWeekday.describe(version.deliveryWeekdays)}',
                    ),
                  ),
            ),
            if (widget.user.isHead) ...[
              const SizedBox(height: 14),
              _AsyncHistoryCard<SubscriptionAuditEntry>(
                title: 'Audit history',
                value: audits,
                emptyMessage: 'No audit entries are available.',
                rowBuilder:
                    (entry) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.verified_user_outlined),
                      title: Text(_actionLabel(entry.action)),
                      subtitle: Text(
                        '${entry.actorId} • ${_timestamp(entry.createdAt)}',
                      ),
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _addPause(AsyncValue<List<SubscriptionPause>> pauseState) async {
    if (pauseState.isLoading || pauseState.hasError) {
      _showError('Wait for pause history to finish loading, then retry.');
      return;
    }
    final draft = await showDialog<_PauseDraft>(
      context: context,
      builder: (context) => const _PauseDialog(),
    );
    if (draft == null || !mounted) return;
    await _run(() async {
      await ref
          .read(subscriptionRepositoryProvider)
          .addPause(
            actor: widget.user,
            customerId: widget.customer.id,
            subscriptionId: widget.subscription.id,
            startDate: draft.startDate,
            endDate: draft.endDate,
            reason: draft.reason,
          );
      _showSuccess(
        draft.endDate == null
            ? 'Subscription paused until it is explicitly resumed.'
            : 'Dated delivery pause added.',
      );
    });
  }

  Future<void> _resume() async {
    final date = await showDialog<LocalDate>(
      context: context,
      builder:
          (context) => const _DateDialog(
            title: 'Resume delivery',
            label: 'First resumed delivery date',
          ),
    );
    if (date == null || !mounted) return;
    await _run(() async {
      await ref
          .read(subscriptionRepositoryProvider)
          .resumeSubscription(
            actor: widget.user,
            customerId: widget.customer.id,
            subscriptionId: widget.subscription.id,
            pauseId: widget.subscription.currentPauseId,
            resumeDate: date,
          );
      _showSuccess('Subscription resumed; the pause period was closed.');
    });
  }

  Future<void> _end() async {
    final date = await showDialog<LocalDate>(
      context: context,
      builder:
          (context) => const _DateDialog(
            title: 'End subscription',
            label: 'Final delivery date',
            description:
                'Historical deliveries, confirmed monthly bills, and collection receipts will be permanently preserved. '
                'Delivered copies up to the final date will be billed normally.',
          ),
    );
    if (date == null || !mounted) return;
    await _run(() async {
      await ref
          .read(subscriptionRepositoryProvider)
          .endSubscription(
            actor: widget.user,
            customerId: widget.customer.id,
            subscriptionId: widget.subscription.id,
            endDate: date,
          );
      _showSuccess('Subscription ended without deleting its history.');
    });
  }

  Future<void> _run(Future<void> Function() operation) async {
    setState(() => _isBusy = true);
    try {
      await operation();
    } on Object catch (error) {
      _showError(error.toString());
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  void _back() {
    if (context.canPop()) {
      context.pop(true);
    } else {
      context.go('/customers/${Uri.encodeComponent(widget.customer.id)}');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  static String _money(int paise) =>
      NumberFormat.currency(locale: 'en_IN', symbol: '₹').format(paise / 100);

  static String _timestamp(DateTime? value) =>
      value == null
          ? 'Pending server time'
          : DateFormat.yMMMd().add_Hm().format(value);

  static String _actionLabel(String action) => switch (action) {
    'subscriptionCreated' => 'Subscription created',
    'subscriptionTermsChanged' => 'Terms changed',
    'subscriptionRestarted' => 'Subscription restarted',
    'subscriptionPauseAdded' => 'Pause added',
    'subscriptionResumed' => 'Subscription resumed',
    'subscriptionEnded' => 'Subscription ended',
    _ => action,
  };
}

class _InfoRow {
  const _InfoRow(this.label, this.value);

  final String label;
  final String value;
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.rows});

  final String title;
  final List<_InfoRow> rows;

  @override
  Widget build(BuildContext context) => Card(
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
          const SizedBox(height: 12),
          for (final row in rows) ...[
            Text(row.label, style: const TextStyle(color: Color(0xFF486581))),
            const SizedBox(height: 2),
            SelectableText(row.value),
            const SizedBox(height: 10),
          ],
        ],
      ),
    ),
  );
}

class _AsyncHistoryCard<T> extends StatelessWidget {
  const _AsyncHistoryCard({
    required this.title,
    required this.value,
    required this.emptyMessage,
    required this.rowBuilder,
  });

  final String title;
  final AsyncValue<List<T>> value;
  final String emptyMessage;
  final Widget Function(T item) rowBuilder;

  @override
  Widget build(BuildContext context) => Card(
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
          const SizedBox(height: 10),
          value.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Text('Could not load history: $error'),
            data:
                (items) =>
                    items.isEmpty
                        ? Text(
                          emptyMessage,
                          style: const TextStyle(color: Color(0xFF486581)),
                        )
                        : Column(
                          children: [
                            for (final item in items) rowBuilder(item),
                          ],
                        ),
          ),
        ],
      ),
    ),
  );
}

class _PauseDraft {
  const _PauseDraft({
    required this.startDate,
    required this.endDate,
    required this.reason,
  });

  final LocalDate startDate;
  final LocalDate? endDate;
  final String reason;
}

class _PauseDialog extends StatefulWidget {
  const _PauseDialog();

  @override
  State<_PauseDialog> createState() => _PauseDialogState();
}

class _PauseDialogState extends State<_PauseDialog> {
  final _formKey = GlobalKey<FormState>();
  final _start = TextEditingController();
  final _end = TextEditingController();
  final _reason = TextEditingController();

  @override
  void dispose() {
    _start.dispose();
    _end.dispose();
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Add delivery pause'),
    content: SizedBox(
      width: 440,
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _start,
              decoration: const InputDecoration(
                labelText: 'Pause starts',
                hintText: 'YYYY-MM-DD',
              ),
              validator: _requiredDate,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _end,
              decoration: const InputDecoration(
                labelText: 'Pause ends (optional)',
                hintText: 'YYYY-MM-DD',
                helperText: 'Leave empty for an open pause requiring resume.',
              ),
              validator: _optionalDate,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _reason,
              maxLength: 200,
              decoration: const InputDecoration(labelText: 'Reason'),
              validator:
                  (value) =>
                      (value?.trim().length ?? 0) < 2
                          ? 'Enter a short reason.'
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
        onPressed: () {
          if (!_formKey.currentState!.validate()) return;
          Navigator.pop(
            context,
            _PauseDraft(
              startDate: LocalDate.parse(_start.text.trim()),
              endDate:
                  _end.text.trim().isEmpty
                      ? null
                      : LocalDate.parse(_end.text.trim()),
              reason: _reason.text.trim(),
            ),
          );
        },
        child: const Text('Add pause'),
      ),
    ],
  );
}

class _DateDialog extends StatefulWidget {
  const _DateDialog({
    required this.title,
    required this.label,
    this.description,
  });

  final String title;
  final String label;
  final String? description;

  @override
  State<_DateDialog> createState() => _DateDialogState();
}

class _DateDialogState extends State<_DateDialog> {
  final _formKey = GlobalKey<FormState>();
  final _date = TextEditingController();

  @override
  void dispose() {
    _date.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.description != null) ...[
            Text(
              widget.description!,
              style: const TextStyle(color: Color(0xFF486581), height: 1.4),
            ),
            const SizedBox(height: 12),
          ],
          TextFormField(
            controller: _date,
            decoration: InputDecoration(
              labelText: widget.label,
              hintText: 'YYYY-MM-DD',
            ),
            validator: _requiredDate,
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
        onPressed: () {
          if (!_formKey.currentState!.validate()) return;
          Navigator.pop(context, LocalDate.parse(_date.text.trim()));
        },
        child: const Text('Confirm'),
      ),
    ],
  );
}

String? _requiredDate(String? value) {
  try {
    LocalDate.parse(value?.trim() ?? '');
    return null;
  } on FormatException {
    return 'Use a real YYYY-MM-DD calendar date.';
  }
}

String? _optionalDate(String? value) =>
    (value?.trim().isEmpty ?? true) ? null : _requiredDate(value);

class _PauseAllDraft {
  const _PauseAllDraft({
    required this.startDate,
    required this.endDate,
    required this.reason,
    required this.subscriptionIds,
  });

  final LocalDate startDate;
  final LocalDate? endDate;
  final String reason;
  final List<String> subscriptionIds;
}

class _PauseAllDialog extends StatefulWidget {
  const _PauseAllDialog({required this.subscriptions});

  final List<CustomerSubscription> subscriptions;

  @override
  State<_PauseAllDialog> createState() => _PauseAllDialogState();
}

class _PauseAllDialogState extends State<_PauseAllDialog> {
  final _formKey = GlobalKey<FormState>();
  final _start = TextEditingController();
  final _end = TextEditingController();
  final _reason = TextEditingController(text: 'Vacation / Out of town');
  late final Set<String> _selectedIds;

  @override
  void initState() {
    super.initState();
    _selectedIds = widget.subscriptions.map((s) => s.id).toSet();
  }

  @override
  void dispose() {
    _start.dispose();
    _end.dispose();
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    LocalDate? startDate;
    LocalDate? endDate;
    try {
      if (_start.text.trim().isNotEmpty) startDate = LocalDate.parse(_start.text.trim());
      if (_end.text.trim().isNotEmpty) endDate = LocalDate.parse(_end.text.trim());
    } catch (_) {}

    final hasPreview = startDate != null && endDate != null && !endDate.isBefore(startDate);
    final days = hasPreview ? endDate.toDateTime().difference(startDate.toDateTime()).inDays + 1 : 0;
    final resumeDate = hasPreview ? endDate.addDays(1).toString() : '';

    return AlertDialog(
      title: Text(l10n?.pauseAllSubscriptions ?? 'Pause all subscriptions'),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Select the pause period. Delivered days are billed normally; paused days are excluded from monthly charges.',
                  style: TextStyle(color: Color(0xFF486581), height: 1.4),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _start,
                  decoration: const InputDecoration(
                    labelText: 'Pause starts (inclusive)',
                    hintText: 'YYYY-MM-DD',
                  ),
                  validator: _requiredDate,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _end,
                  decoration: const InputDecoration(
                    labelText: 'Pause ends (inclusive, optional)',
                    hintText: 'YYYY-MM-DD',
                    helperText: 'Leave empty for an open pause requiring manual resume.',
                  ),
                  validator: _optionalDate,
                  onChanged: (_) => setState(() {}),
                ),
                if (hasPreview) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF8E8),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFFD599)),
                    ),
                    child: Text(
                      l10n?.pauseNotice(
                            startDate.toString(),
                            endDate.toString(),
                            days,
                            resumeDate,
                          ) ??
                          '⛔ No delivery: $startDate to $endDate ($days days)\n'
                              '▶️ Delivery resumes on: $resumeDate',
                      style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF8A4B00), height: 1.4),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                TextFormField(
                  controller: _reason,
                  decoration: const InputDecoration(labelText: 'Reason for pause'),
                  validator: (v) => (v?.trim().length ?? 0) < 2 ? 'Enter a short reason.' : null,
                ),
                const SizedBox(height: 14),
                const Text('Subscriptions to pause', style: TextStyle(fontWeight: FontWeight.w700)),
                for (final sub in widget.subscriptions)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _selectedIds.contains(sub.id),
                    title: Text(sub.newspaperName),
                    subtitle: Text('Qty ${sub.quantity} • ${sub.status.label}'),
                    onChanged: (checked) {
                      setState(() {
                        if (checked == true) {
                          _selectedIds.add(sub.id);
                        } else if (_selectedIds.length > 1) {
                          _selectedIds.remove(sub.id);
                        }
                      });
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n?.commonCancel ?? 'Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            if (_selectedIds.isEmpty) return;
            Navigator.pop(
              context,
              _PauseAllDraft(
                startDate: LocalDate.parse(_start.text.trim()),
                endDate: _end.text.trim().isEmpty ? null : LocalDate.parse(_end.text.trim()),
                reason: _reason.text.trim(),
                subscriptionIds: _selectedIds.toList(),
              ),
            );
          },
          child: Text('Pause ${_selectedIds.length} subscriptions'),
        ),
      ],
    );
  }
}
