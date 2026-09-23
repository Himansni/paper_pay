import 'package:flutter/material.dart';
import 'package:paper_route/features/newspapers/domain/newspaper.dart';
import 'package:paper_route/features/newspapers/domain/newspaper_master_catalog.dart';

class MasterCatalogPickerSheet extends StatefulWidget {
  const MasterCatalogPickerSheet({super.key});

  static Future<MasterNewspaperEntry?> show(BuildContext context) {
    return showModalBottomSheet<MasterNewspaperEntry>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const MasterCatalogPickerSheet(),
    );
  }

  @override
  State<MasterCatalogPickerSheet> createState() =>
      _MasterCatalogPickerSheetState();
}

class _MasterCatalogPickerSheetState extends State<MasterCatalogPickerSheet> {
  final _searchController = TextEditingController();
  final _catalog = const LocalNewspaperMasterCatalog();
  PublicationType? _typeFilter;
  String? _languageFilter;
  List<MasterNewspaperEntry> _results = [];
  bool _isLoading = false;

  final _languages = const [
    'All',
    'Hindi',
    'English',
    'Marathi',
    'Bengali',
    'Telugu',
    'Tamil',
    'Gujarati',
    'Malayalam',
    'Kannada',
    'Punjabi',
    'Odia',
  ];

  @override
  void initState() {
    super.initState();
    _filter();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _filter() async {
    setState(() => _isLoading = true);
    final results = await _catalog.search(
      query: _searchController.text,
      language: _languageFilter == 'All' ? null : _languageFilter,
      type: _typeFilter,
    );
    if (!mounted) return;
    setState(() {
      _results = results;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  const Icon(Icons.menu_book_rounded, color: Color(0xFF0F60FF)),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Indian Publication Catalogue',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: TextField(
                key: const ValueKey('catalog-search-field'),
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search newspaper or magazine (e.g. TOI, Jagran, IT)',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon:
                      _searchController.text.isNotEmpty
                          ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              _filter();
                            },
                          )
                          : null,
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (_) => _filter(),
              ),
            ),
            // Type filters (All / Newspapers / Magazines)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  FilterChip(
                    label: const Text('All'),
                    selected: _typeFilter == null,
                    onSelected: (_) {
                      setState(() => _typeFilter = null);
                      _filter();
                    },
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: const Text('Newspapers'),
                    selected: _typeFilter == PublicationType.newspaper,
                    onSelected: (_) {
                      setState(() => _typeFilter = PublicationType.newspaper);
                      _filter();
                    },
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: const Text('Magazines'),
                    selected: _typeFilter == PublicationType.magazine,
                    onSelected: (_) {
                      setState(() => _typeFilter = PublicationType.magazine);
                      _filter();
                    },
                  ),
                ],
              ),
            ),
            // Language horizontal scroll
            SizedBox(
              height: 44,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                scrollDirection: Axis.horizontal,
                itemCount: _languages.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (context, index) {
                  final lang = _languages[index];
                  final isSelected =
                      (_languageFilter == null && lang == 'All') ||
                      _languageFilter == lang;
                  return ChoiceChip(
                    label: Text(lang, style: const TextStyle(fontSize: 12)),
                    selected: isSelected,
                    onSelected: (_) {
                      setState(() => _languageFilter = lang == 'All' ? null : lang);
                      _filter();
                    },
                  );
                },
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child:
                  _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _results.isEmpty
                      ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.search_off_rounded,
                              size: 48,
                              color: Color(0xFF9FB3C8),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'No matching publications found.',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'You can add any custom publication manually.',
                              style: TextStyle(color: Color(0xFF627D98)),
                            ),
                          ],
                        ),
                      )
                      : ListView.separated(
                        controller: scrollController,
                        itemCount: _results.length,
                        separatorBuilder:
                            (_, __) => const Divider(height: 1, indent: 16),
                        itemBuilder: (context, index) {
                          final item = _results[index];
                          final isMagazine = item.type == PublicationType.magazine;
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor:
                                  isMagazine
                                      ? const Color(0xFF8B5CF6).withValues(alpha: 0.15)
                                      : const Color(0xFF0F60FF).withValues(alpha: 0.15),
                              child: Icon(
                                isMagazine
                                    ? Icons.auto_stories_outlined
                                    : Icons.newspaper_outlined,
                                color:
                                    isMagazine
                                        ? const Color(0xFF7C3AED)
                                        : const Color(0xFF0F60FF),
                                size: 20,
                              ),
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    item.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        isMagazine
                                            ? const Color(0xFFEDE9FE)
                                            : const Color(0xFFE0F2FE),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    isMagazine
                                        ? item.frequency.label
                                        : item.language,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color:
                                          isMagazine
                                              ? const Color(0xFF6D28D9)
                                              : const Color(0xFF0369A1),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (item.hindiName.isNotEmpty)
                                  Text(
                                    item.hindiName,
                                    style: const TextStyle(
                                      color: Color(0xFF486581),
                                      fontSize: 13,
                                    ),
                                  ),
                                const SizedBox(height: 2),
                                Text(
                                  '${item.edition} Edition • ${item.language} • ₹${NewspaperMoney.formatPaiseForInput(item.defaultPricePaise)} default',
                                  style: const TextStyle(
                                    color: Color(0xFF627D98),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            trailing: const Icon(
                              Icons.add_circle_outline,
                              color: Color(0xFF0F60FF),
                            ),
                            onTap: () => Navigator.pop(context, item),
                          );
                        },
                      ),
            ),
          ],
        );
      },
    );
  }
}
