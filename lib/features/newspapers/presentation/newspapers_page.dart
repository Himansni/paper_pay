import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:paper_route/core/presentation/async_state_cards.dart';
import 'package:paper_route/features/auth/domain/app_user.dart';
import 'package:paper_route/features/newspapers/domain/newspaper.dart';
import 'package:paper_route/features/newspapers/presentation/newspaper_providers.dart';

class NewspapersPage extends ConsumerStatefulWidget {
  const NewspapersPage({required this.user, super.key});

  final AppUser user;

  @override
  ConsumerState<NewspapersPage> createState() => _NewspapersPageState();
}

class _NewspapersPageState extends ConsumerState<NewspapersPage> {
  final _searchController = TextEditingController();
  final List<Newspaper> _newspapers = [];
  NewspaperStatus _status = NewspaperStatus.active;
  NewspaperSearchField _searchField = NewspaperSearchField.name;
  NewspaperPageCursor? _cursor;
  String _activeSearch = '';
  bool _hasMore = true;
  bool _isLoading = false;
  String? _error;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load(reset: true));
  }

  @override
  void didUpdateWidget(covariant NewspapersPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user.businessId != widget.user.businessId) {
      _load(reset: true);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load({bool reset = false}) async {
    if (!reset && (_isLoading || !_hasMore)) return;
    final generation = reset ? ++_loadGeneration : _loadGeneration;
    final user = widget.user;
    final status = user.isHead ? _status : NewspaperStatus.active;
    final searchField = _activeSearch.isEmpty ? null : _searchField;
    final searchTerm = _activeSearch;
    final cursor = reset ? null : _cursor;
    if (reset) {
      setState(() {
        _newspapers.clear();
        _cursor = null;
        _hasMore = true;
        _error = null;
      });
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final page = await ref
          .read(newspaperRepositoryProvider)
          .fetchNewspapers(
            NewspaperListRequest(
              businessId: user.businessId!,
              requesterId: user.uid,
              status: status,
              searchField: searchField,
              searchTerm: searchTerm,
              cursor: cursor,
            ),
          );
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _newspapers.addAll(page.newspapers);
        _cursor = page.nextCursor;
        _hasMore = page.hasMore;
      });
    } on Object catch (error) {
      if (mounted && generation == _loadGeneration) {
        setState(() => _error = error.toString());
      }
    } finally {
      if (mounted && generation == _loadGeneration) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _search() {
    setState(() => _activeSearch = _searchController.text.trim());
    _load(reset: true);
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() => _activeSearch = '');
    _load(reset: true);
  }

  Future<void> _open(String location) async {
    final changed = await context.push<bool>(location);
    if (changed == true && mounted) await _load(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    final hasSearch = _activeSearch.isNotEmpty;
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.go('/')),
        title: const Text('Newspaper catalog'),
      ),
      floatingActionButton:
          widget.user.isHead
              ? FloatingActionButton.extended(
                onPressed: () => _open('/newspapers/new'),
                icon: const Icon(Icons.add),
                label: const Text('New newspaper'),
              )
              : null,
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: () => _load(reset: true),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              20,
              12,
              20,
              widget.user.isHead ? 100 : 36,
            ),
            children: [
              Text(
                'Publications and editions',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                widget.user.isHead
                    ? 'Manage the tenant catalog and open a publication to configure audited date-specific prices.'
                    : 'Browse active publications and their effective prices. Catalog and pricing changes are Head-only.',
                style: const TextStyle(color: Color(0xFF627D98), height: 1.4),
              ),
              const SizedBox(height: 18),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 2,
                            child:
                                DropdownButtonFormField<NewspaperSearchField>(
                                  value: _searchField,
                                  decoration: const InputDecoration(
                                    labelText: 'Search by',
                                  ),
                                  items: [
                                    for (final field
                                        in NewspaperSearchField.values)
                                      DropdownMenuItem(
                                        value: field,
                                        child: Text(field.label),
                                      ),
                                  ],
                                  onChanged: (value) {
                                    if (value != null) {
                                      setState(() => _searchField = value);
                                    }
                                  },
                                ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 3,
                            child: TextField(
                              controller: _searchController,
                              textInputAction: TextInputAction.search,
                              decoration: InputDecoration(
                                labelText:
                                    'Search ${_searchField.label.toLowerCase()}',
                                prefixIcon: const Icon(Icons.search),
                              ),
                              onSubmitted: (_) => _search(),
                            ),
                          ),
                        ],
                      ),
                      if (widget.user.isHead) ...[
                        const SizedBox(height: 12),
                        DropdownButtonFormField<NewspaperStatus>(
                          value: _status,
                          decoration: const InputDecoration(
                            labelText: 'Catalog status',
                          ),
                          items: [
                            for (final status in NewspaperStatus.values)
                              DropdownMenuItem(
                                value: status,
                                child: Text(status.label),
                              ),
                          ],
                          onChanged: (value) {
                            if (value == null || value == _status) return;
                            setState(() => _status = value);
                            _load(reset: true);
                          },
                        ),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (hasSearch)
                            TextButton(
                              onPressed: _clearSearch,
                              child: const Text('Clear'),
                            ),
                          const SizedBox(width: 8),
                          FilledButton.icon(
                            onPressed: _search,
                            icon: const Icon(Icons.search),
                            label: const Text('Search'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              if (_newspapers.isEmpty && _isLoading)
                const Padding(
                  padding: EdgeInsets.all(36),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_newspapers.isEmpty && _error != null)
                AsyncErrorCard(
                  message: 'Could not load the newspaper catalog. $_error',
                  onRetry: () => _load(reset: true),
                )
              else if (_newspapers.isEmpty)
                EmptyStateCard(
                  icon:
                      hasSearch
                          ? Icons.search_off_outlined
                          : Icons.newspaper_outlined,
                  title:
                      hasSearch
                          ? 'No matching newspapers'
                          : 'No ${_status.label.toLowerCase()} newspapers',
                  message:
                      hasSearch
                          ? 'Try another name or exact newspaper code.'
                          : widget.user.isHead
                          ? 'Create the first custom publication for this business.'
                          : 'The Head has not added any active publications yet.',
                )
              else ...[
                Text(
                  '${_newspapers.length} newspaper${_newspapers.length == 1 ? '' : 's'} loaded',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: const Color(0xFF627D98),
                  ),
                ),
                const SizedBox(height: 10),
                for (final newspaper in _newspapers) ...[
                  _NewspaperCard(
                    newspaper: newspaper,
                    onTap:
                        () => _open(
                          '/newspapers/${Uri.encodeComponent(newspaper.id)}',
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
                      label: const Text('Load more newspapers'),
                    ),
                  )
                else
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Center(
                      child: Text(
                        'End of catalog',
                        style: TextStyle(color: Color(0xFF829AB1)),
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _NewspaperCard extends StatelessWidget {
  const _NewspaperCard({required this.newspaper, required this.onTap});

  final Newspaper newspaper;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final price = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
    ).format(newspaper.defaultPricePaise / 100);
    return Card(
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        leading: Icon(
          newspaper.isArchived
              ? Icons.inventory_2_outlined
              : Icons.newspaper_outlined,
        ),
        title: Text(
          newspaper.name,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          [
            newspaper.newspaperCode,
            if (newspaper.edition.isNotEmpty) newspaper.edition,
            if (newspaper.language.isNotEmpty) newspaper.language,
            'Baseline $price',
          ].join(' • '),
        ),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}
