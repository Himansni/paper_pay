import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:paper_route/core/domain/local_date.dart';
import 'package:paper_route/core/presentation/async_state_cards.dart';
import 'package:paper_route/features/auth/domain/app_user.dart';
import 'package:paper_route/features/newspapers/domain/newspaper.dart';
import 'package:paper_route/features/newspapers/presentation/newspaper_providers.dart';

class NewspaperPricingPage extends ConsumerStatefulWidget {
  const NewspaperPricingPage({
    required this.user,
    required this.newspaperId,
    super.key,
  });

  final AppUser user;
  final String newspaperId;

  @override
  ConsumerState<NewspaperPricingPage> createState() =>
      _NewspaperPricingPageState();
}

class _NewspaperPricingPageState extends ConsumerState<NewspaperPricingPage> {
  final List<NewspaperPriceRule> _rules = [];
  PriceRulePageCursor? _cursor;
  bool _hasMore = true;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load(reset: true));
  }

  Future<void> _load({bool reset = false}) async {
    if (_isLoading || (!reset && !_hasMore)) return;
    if (reset) {
      setState(() {
        _rules.clear();
        _cursor = null;
        _hasMore = true;
      });
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final page = await ref
          .read(newspaperRepositoryProvider)
          .fetchPriceRules(
            PriceRuleListRequest(
              businessId: widget.user.businessId!,
              newspaperId: widget.newspaperId,
              cursor: _cursor,
            ),
          );
      if (!mounted) return;
      setState(() {
        _rules.addAll(page.rules);
        _cursor = page.nextCursor;
        _hasMore = page.hasMore;
      });
    } on Object catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final key = (
      businessId: widget.user.businessId!,
      newspaperId: widget.newspaperId,
    );
    final newspaper = ref.watch(newspaperProvider(key));
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(
          onPressed:
              () =>
                  context.canPop()
                      ? context.pop(true)
                      : context.go('/newspapers/${widget.newspaperId}'),
        ),
        title: const Text('Price history'),
      ),
      floatingActionButton:
          widget.user.isHead && newspaper.value?.isArchived == false
              ? FloatingActionButton.extended(
                onPressed: _isLoading ? null : () => _edit(),
                icon: const Icon(Icons.add),
                label: const Text('Price rule'),
              )
              : null,
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
          children: [
            Text(
              newspaper.value?.name ?? 'Newspaper pricing',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            const Text(
              'Exact dates override periods, which override the immutable initial default. Corrections supersede records without deleting history.',
              style: TextStyle(color: Color(0xFF627D98), height: 1.4),
            ),
            const SizedBox(height: 18),
            if (_rules.isEmpty && _isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_rules.isEmpty && _error != null)
              AsyncErrorCard(
                message: 'Could not load price history. $_error',
                onRetry: () => _load(reset: true),
              )
            else if (_rules.isEmpty)
              const EmptyStateCard(
                icon: Icons.price_change_outlined,
                title: 'No date-specific prices',
                message:
                    'The immutable initial default price applies to every date until an authorized rule is added.',
              )
            else ...[
              for (final rule in _rules) ...[
                Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.fromLTRB(18, 8, 8, 8),
                    leading: Icon(
                      rule.kind == PriceRuleKind.exactDate
                          ? Icons.event_outlined
                          : Icons.date_range_outlined,
                    ),
                    title: Text(
                      '${_money(rule.pricePaise)} • ${rule.kind.label}',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Text(
                      '${rule.startDate}${rule.endDate == null ? '' : ' → ${rule.endDate}'}\n'
                      '${rule.status.label} • revision ${rule.revision} • ${rule.reason}',
                    ),
                    isThreeLine: true,
                    trailing:
                        widget.user.isHead && rule.isActive
                            ? TextButton(
                              onPressed: () => _edit(rule),
                              child: const Text('Correct'),
                            )
                            : null,
                  ),
                ),
                const SizedBox(height: 10),
              ],
              if (_error != null)
                AsyncErrorCard(message: _error!, onRetry: _load),
              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else if (_hasMore)
                Center(
                  child: OutlinedButton(
                    onPressed: _load,
                    child: const Text('Load more price history'),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _edit([NewspaperPriceRule? correcting]) async {
    final input = await showDialog<PriceRuleInput>(
      context: context,
      builder: (context) => _PriceRuleDialog(correcting: correcting),
    );
    if (input == null || !mounted) return;
    setState(() => _isLoading = true);
    try {
      final repository = ref.read(newspaperRepositoryProvider);
      if (correcting == null) {
        await repository.createPriceRule(
          actor: widget.user,
          newspaperId: widget.newspaperId,
          input: input,
        );
      } else {
        await repository.correctPriceRule(
          actor: widget.user,
          newspaperId: widget.newspaperId,
          replacedRuleId: correcting.id,
          replacement: input,
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            correcting == null
                ? 'Date-specific price added.'
                : 'Price corrected; the previous record remains in history.',
          ),
        ),
      );
      setState(() => _isLoading = false);
      await _load(reset: true);
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = error.toString();
        });
      }
    }
  }

  static String _money(int paise) =>
      NumberFormat.currency(locale: 'en_IN', symbol: '₹').format(paise / 100);
}

class _PriceRuleDialog extends StatefulWidget {
  const _PriceRuleDialog({this.correcting});

  final NewspaperPriceRule? correcting;

  @override
  State<_PriceRuleDialog> createState() => _PriceRuleDialogState();
}

class _PriceRuleDialogState extends State<_PriceRuleDialog> {
  final _formKey = GlobalKey<FormState>();
  late PriceRuleKind _kind;
  late final TextEditingController _start;
  late final TextEditingController _end;
  late final TextEditingController _price;
  final _reason = TextEditingController();

  @override
  void initState() {
    super.initState();
    final rule = widget.correcting;
    _kind = rule?.kind ?? PriceRuleKind.exactDate;
    _start = TextEditingController(text: rule?.startDate.toString() ?? '');
    _end = TextEditingController(text: rule?.endDate?.toString() ?? '');
    _price = TextEditingController(
      text:
          rule == null
              ? ''
              : NewspaperMoney.formatPaiseForInput(rule.pricePaise),
    );
  }

  @override
  void dispose() {
    _start.dispose();
    _end.dispose();
    _price.dispose();
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.correcting == null ? 'Add price rule' : 'Correct price rule',
    ),
    content: SizedBox(
      width: 480,
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            children: [
              DropdownButtonFormField<PriceRuleKind>(
                value: _kind,
                decoration: const InputDecoration(labelText: 'Rule type'),
                items: [
                  for (final kind in PriceRuleKind.values)
                    DropdownMenuItem(value: kind, child: Text(kind.label)),
                ],
                onChanged:
                    (value) => setState(() {
                      _kind = value ?? _kind;
                      if (_kind == PriceRuleKind.exactDate) _end.clear();
                    }),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _start,
                decoration: InputDecoration(
                  labelText:
                      _kind == PriceRuleKind.exactDate
                          ? 'Service date'
                          : 'Period starts',
                  hintText: 'YYYY-MM-DD',
                ),
                validator: _date,
              ),
              if (_kind == PriceRuleKind.period) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _end,
                  decoration: const InputDecoration(
                    labelText: 'Period ends (inclusive)',
                    hintText: 'YYYY-MM-DD',
                  ),
                  validator: _date,
                ),
              ],
              const SizedBox(height: 12),
              TextFormField(
                controller: _price,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: 'Unit price (₹)'),
                validator:
                    (value) =>
                        (value?.trim().isEmpty ?? true)
                            ? 'Enter a price.'
                            : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _reason,
                maxLength: 300,
                decoration: InputDecoration(
                  labelText:
                      widget.correcting == null
                          ? 'Pricing reason'
                          : 'Correction reason',
                  helperText:
                      widget.correcting == null
                          ? 'Example: Tuesday edition price'
                          : 'Required; the previous record is retained.',
                ),
                validator:
                    (value) =>
                        (value?.trim().length ?? 0) < 3
                            ? 'Enter a clear reason.'
                            : null,
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
          final input = PriceRuleInput(
            kind: _kind,
            startDate: LocalDate.parse(_start.text.trim()),
            endDate:
                _kind == PriceRuleKind.period
                    ? LocalDate.parse(_end.text.trim())
                    : null,
            pricePaise: NewspaperMoney.parseRupeesToPaise(_price.text),
            reason: _reason.text,
          );
          try {
            input.validate();
            Navigator.pop(context, input);
          } on Object catch (error) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(error.toString())));
          }
        },
        child: Text(widget.correcting == null ? 'Add rule' : 'Save correction'),
      ),
    ],
  );
}

String? _date(String? value) {
  try {
    LocalDate.parse(value?.trim() ?? '');
    return null;
  } on FormatException {
    return 'Use a real YYYY-MM-DD calendar date.';
  }
}
