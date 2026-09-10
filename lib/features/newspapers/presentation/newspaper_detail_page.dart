import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:paper_route/core/domain/local_date.dart';
import 'package:paper_route/core/presentation/async_state_cards.dart';
import 'package:paper_route/features/auth/domain/app_user.dart';
import 'package:paper_route/features/newspapers/domain/newspaper.dart';
import 'package:paper_route/features/newspapers/presentation/newspaper_providers.dart';

class NewspaperDetailPage extends ConsumerWidget {
  const NewspaperDetailPage({
    required this.user,
    required this.newspaperId,
    super.key,
  });

  final AppUser user;
  final String newspaperId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = (businessId: user.businessId!, newspaperId: newspaperId);
    return ref
        .watch(newspaperProvider(key))
        .when(
          loading:
              () => const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              ),
          error:
              (error, _) => Scaffold(
                appBar: AppBar(title: const Text('Newspaper')),
                body: Padding(
                  padding: const EdgeInsets.all(20),
                  child: AsyncErrorCard(
                    message: 'Could not load newspaper. $error',
                    onRetry: () => ref.invalidate(newspaperProvider(key)),
                  ),
                ),
              ),
          data:
              (newspaper) =>
                  newspaper == null
                      ? Scaffold(
                        appBar: AppBar(title: const Text('Newspaper')),
                        body: const Padding(
                          padding: EdgeInsets.all(20),
                          child: EmptyStateCard(
                            icon: Icons.newspaper_outlined,
                            title: 'Newspaper not found',
                            message: 'This publication is unavailable.',
                          ),
                        ),
                      )
                      : _NewspaperDetailView(user: user, newspaper: newspaper),
        );
  }
}

class _NewspaperDetailView extends ConsumerStatefulWidget {
  const _NewspaperDetailView({required this.user, required this.newspaper});

  final AppUser user;
  final Newspaper newspaper;

  @override
  ConsumerState<_NewspaperDetailView> createState() =>
      _NewspaperDetailViewState();
}

class _NewspaperDetailViewState extends ConsumerState<_NewspaperDetailView> {
  final _previewDate = TextEditingController();
  ResolvedNewspaperPrice? _resolvedPrice;
  bool _isBusy = false;
  String? _previewError;

  @override
  void dispose() {
    _previewDate.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final newspaper = widget.newspaper;
    final key = (
      businessId: widget.user.businessId!,
      newspaperId: newspaper.id,
    );
    final history =
        widget.user.isHead
            ? ref.watch(newspaperAuditProvider(key))
            : const AsyncData<List<NewspaperAuditEntry>>([]);
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(
          onPressed:
              () =>
                  context.canPop()
                      ? context.pop(true)
                      : context.go('/newspapers'),
        ),
        title: const Text('Newspaper details'),
        actions: [
          if (widget.user.isHead)
            IconButton(
              onPressed:
                  _isBusy
                      ? null
                      : () => context.push<bool>(
                        '/newspapers/${Uri.encodeComponent(newspaper.id)}/edit',
                      ),
              tooltip: 'Edit newspaper profile',
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
              children: [
                const CircleAvatar(child: Icon(Icons.newspaper_outlined)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        newspaper.name,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        newspaper.newspaperCode,
                        style: const TextStyle(color: Color(0xFF627D98)),
                      ),
                    ],
                  ),
                ),
                Chip(label: Text(newspaper.status.label)),
              ],
            ),
            const SizedBox(height: 18),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Catalog profile',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _value('Edition', newspaper.edition, fallback: 'Not set'),
                    _value('Language', newspaper.language, fallback: 'Not set'),
                    _value(
                      'Immutable baseline price',
                      _money(newspaper.defaultPricePaise),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Date-specific pricing',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                        TextButton(
                          onPressed:
                              () => context.push<bool>(
                                '/newspapers/${Uri.encodeComponent(newspaper.id)}/prices',
                              ),
                          child: Text(
                            widget.user.isHead ? 'Manage' : 'History',
                          ),
                        ),
                      ],
                    ),
                    const Text(
                      'Preview the deterministic unit price for an explicit calendar date.',
                      style: TextStyle(color: Color(0xFF627D98)),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      key: const ValueKey('newspaper-price-preview-date'),
                      controller: _previewDate,
                      decoration: const InputDecoration(
                        labelText: 'Service date',
                        hintText: 'YYYY-MM-DD',
                      ),
                    ),
                    const SizedBox(height: 10),
                    FilledButton.icon(
                      onPressed: _isBusy ? null : _resolve,
                      icon: const Icon(Icons.calculate_outlined),
                      label: const Text('Resolve price'),
                    ),
                    if (_previewError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text(
                          _previewError!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    if (_resolvedPrice != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          '${_money(_resolvedPrice!.pricePaise)} • ${_source(_resolvedPrice!.source)}',
                          key: const ValueKey('resolved-newspaper-price'),
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (widget.user.isHead) ...[
              const SizedBox(height: 14),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Audit history',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 10),
                      history.when(
                        loading:
                            () => const Center(
                              child: CircularProgressIndicator(),
                            ),
                        error:
                            (error, _) =>
                                Text('Could not load history: $error'),
                        data:
                            (entries) =>
                                entries.isEmpty
                                    ? const Text('No audit entries found.')
                                    : Column(
                                      children: [
                                        for (final entry in entries)
                                          ListTile(
                                            contentPadding: EdgeInsets.zero,
                                            leading: const Icon(
                                              Icons.verified_user_outlined,
                                            ),
                                            title: Text(_action(entry.action)),
                                            subtitle: Text(
                                              '${entry.actorId} • ${_timestamp(entry.createdAt)}',
                                            ),
                                          ),
                                      ],
                                    ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: _isBusy ? null : _toggleArchived,
                icon: Icon(
                  newspaper.isArchived
                      ? Icons.restore_outlined
                      : Icons.archive_outlined,
                ),
                label: Text(
                  newspaper.isArchived
                      ? 'Reactivate newspaper'
                      : 'Archive newspaper',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _value(String label, String value, {String fallback = ''}) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF627D98))),
        const SizedBox(height: 2),
        SelectableText(value.isEmpty ? fallback : value),
      ],
    ),
  );

  Future<void> _resolve() async {
    setState(() {
      _isBusy = true;
      _previewError = null;
      _resolvedPrice = null;
    });
    try {
      final date = LocalDate.parse(_previewDate.text.trim());
      final price = await ref
          .read(newspaperRepositoryProvider)
          .resolvePriceOn(
            businessId: widget.user.businessId!,
            newspaperId: widget.newspaper.id,
            date: date,
          );
      if (mounted) setState(() => _resolvedPrice = price);
    } on Object catch (error) {
      if (mounted) setState(() => _previewError = error.toString());
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _toggleArchived() async {
    final archive = !widget.newspaper.isArchived;
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              archive ? 'Archive newspaper?' : 'Reactivate newspaper?',
            ),
            content: Text(
              archive
                  ? 'Existing subscriptions, price rules, and future billing references remain intact. New subscriptions will be blocked.'
                  : 'The publication will become available for new subscriptions again.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(archive ? 'Archive' : 'Reactivate'),
              ),
            ],
          ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _isBusy = true);
    try {
      await ref
          .read(newspaperRepositoryProvider)
          .setNewspaperArchived(
            actor: widget.user,
            newspaperId: widget.newspaper.id,
            archived: archive,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              archive ? 'Newspaper archived.' : 'Newspaper reactivated.',
            ),
          ),
        );
      }
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  static String _money(int paise) =>
      NumberFormat.currency(locale: 'en_IN', symbol: '₹').format(paise / 100);

  static String _source(ResolvedPriceSource source) => switch (source) {
    ResolvedPriceSource.defaultPrice => 'Initial default',
    ResolvedPriceSource.period => 'Effective period',
    ResolvedPriceSource.exactDate => 'Exact-date override',
  };

  static String _action(String action) => switch (action) {
    'newspaperCreated' => 'Newspaper created',
    'newspaperUpdated' => 'Profile updated',
    'newspaperArchived' => 'Newspaper archived',
    'newspaperReactivated' => 'Newspaper reactivated',
    'newspaperPriceRuleCreated' => 'Price rule created',
    'newspaperPriceRuleCorrected' => 'Price rule corrected',
    _ => action,
  };

  static String _timestamp(DateTime? value) =>
      value == null
          ? 'Pending server time'
          : DateFormat.yMMMd().add_Hm().format(value);
}
