import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:paper_route/core/domain/local_date.dart';
import 'package:paper_route/core/presentation/async_state_cards.dart';
import 'package:paper_route/features/auth/domain/app_user.dart';
import 'package:paper_route/features/business/presentation/business_providers.dart';
import 'package:paper_route/features/newspapers/domain/newspaper.dart';
import 'package:paper_route/features/newspapers/presentation/newspaper_providers.dart';

class DailyPricingPage extends ConsumerStatefulWidget {
  const DailyPricingPage({required this.user, super.key});

  final AppUser user;

  @override
  ConsumerState<DailyPricingPage> createState() => _DailyPricingPageState();
}

class _DailyPricingPageState extends ConsumerState<DailyPricingPage> {
  final _formKey = GlobalKey<FormState>();
  final _date = TextEditingController();
  final _price = TextEditingController();
  final _reason = TextEditingController();
  List<Newspaper> _newspapers = const [];
  String _newspaperId = '';
  bool _loading = true;
  bool _saving = false;
  String? _error;
  ResolvedNewspaperPrice? _current;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _date.text = DateFormat('yyyy-MM-dd').format(now);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _date.dispose();
    _price.dispose();
    _reason.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await ref
          .read(newspaperRepositoryProvider)
          .fetchNewspapers(
            NewspaperListRequest(
              businessId: widget.user.businessId!,
              requesterId: widget.user.uid,
              pageSize: 50,
            ),
          );
      if (!mounted) return;
      setState(() {
        _newspapers = page.newspapers;
        if (_newspaperId.isEmpty && _newspapers.isNotEmpty) {
          _newspaperId = _newspapers.first.id;
        }
      });
      await _resolve();
    } on Object catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resolve() async {
    if (_newspaperId.isEmpty) return;
    try {
      final date = LocalDate.parse(_date.text.trim());
      final current = await ref
          .read(newspaperRepositoryProvider)
          .resolvePriceOn(
            businessId: widget.user.businessId!,
            newspaperId: _newspaperId,
            date: date,
          );
      if (mounted) {
        setState(() {
          _current = current;
          _price.text = NewspaperMoney.formatPaiseForInput(current.pricePaise);
        });
      }
    } on Object catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final date = LocalDate.parse(_date.text.trim());
      final input = PriceRuleInput(
        kind: PriceRuleKind.exactDate,
        startDate: date,
        endDate: null,
        pricePaise: NewspaperMoney.parseRupeesToPaise(_price.text),
        reason: _reason.text,
      );
      input.validate();
      final repository = ref.read(newspaperRepositoryProvider);
      final current = await repository.resolvePriceOn(
        businessId: widget.user.businessId!,
        newspaperId: _newspaperId,
        date: date,
      );
      if (current.source == ResolvedPriceSource.exactDate &&
          current.ruleId != null) {
        await repository.correctPriceRule(
          actor: widget.user,
          newspaperId: _newspaperId,
          replacedRuleId: current.ruleId!,
          replacement: input,
        );
      } else {
        await repository.createPriceRule(
          actor: widget.user,
          newspaperId: _newspaperId,
          input: input,
        );
      }
      _reason.clear();
      await _resolve();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Daily price saved. Unfinalized previews will use it automatically.',
            ),
          ),
        );
      }
    } on Object catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final business = ref.watch(
      businessProfileProvider(widget.user.businessId!),
    );
    final region = business.asData?.value.primaryPricingRegion;
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.go('/')),
        title: const Text('Daily pricing'),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
          children: [
            Text(
              region?.isConfigured == true
                  ? "Today's Paper Prices — ${region!.districtCity}"
                  : "Today's Paper Prices",
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              region?.isConfigured == true
                  ? '${region!.state}${region.editionServiceRegion.isEmpty ? '' : ' · ${region.editionServiceRegion}'}'
                  : 'Set the Primary Pricing Region in Business Settings for persistent local context.',
              style: const TextStyle(color: Color(0xFF486581)),
            ),
            const SizedBox(height: 18),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else if (_newspapers.isEmpty)
              EmptyStateCard(
                icon: Icons.newspaper_outlined,
                title: 'No active newspapers',
                message:
                    'Add a custom newspaper or reactivate one before setting a daily price.',
              )
            else
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        DropdownButtonFormField<String>(
                          key: const ValueKey('daily-price-newspaper'),
                          value: _newspaperId,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Newspaper / edition',
                          ),
                          items: [
                            for (final paper in _newspapers)
                              DropdownMenuItem(
                                value: paper.id,
                                child: Text(paper.displayName),
                              ),
                          ],
                          onChanged: (value) {
                            setState(() => _newspaperId = value ?? '');
                            _resolve();
                          },
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          key: const ValueKey('daily-price-date'),
                          controller: _date,
                          decoration: InputDecoration(
                            labelText: 'Delivery date',
                            hintText: 'YYYY-MM-DD',
                            suffixIcon: IconButton(
                              tooltip: 'Choose date',
                              onPressed: _pickDate,
                              icon: const Icon(Icons.calendar_month_outlined),
                            ),
                          ),
                          validator:
                              (value) =>
                                  (value?.trim().isEmpty ?? true)
                                      ? 'Choose a date.'
                                      : null,
                          onFieldSubmitted: (_) => _resolve(),
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          key: const ValueKey('daily-price-amount'),
                          controller: _price,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Unit price (₹)',
                          ),
                          validator:
                              (value) =>
                                  (value?.trim().isEmpty ?? true)
                                      ? 'Enter the price.'
                                      : null,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          key: const ValueKey('daily-price-reason'),
                          controller: _reason,
                          maxLength: 300,
                          decoration: InputDecoration(
                            labelText:
                                _current?.source ==
                                        ResolvedPriceSource.exactDate
                                    ? 'Correction reason'
                                    : 'Pricing reason',
                            helperText:
                                'This price applies to every applicable subscription for the selected newspaper and date.',
                          ),
                          validator:
                              (value) =>
                                  (value?.trim().length ?? 0) < 3
                                      ? 'Enter a clear reason.'
                                      : null,
                        ),
                        if (_current != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Current precedence result: ${_sourceLabel(_current!.source)} · ${_money(_current!.pricePaise)}',
                            style: const TextStyle(color: Color(0xFF486581)),
                          ),
                        ],
                        const SizedBox(height: 16),
                        const Text(
                          'Customer-specific exceptions still take priority. Finalized bills and their line snapshots never change.',
                          style: TextStyle(
                            color: Color(0xFF486581),
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 18),
                        FilledButton.icon(
                          key: const ValueKey('save-daily-price'),
                          onPressed: _saving ? null : _save,
                          icon:
                              _saving
                                  ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                  : const Icon(Icons.save_outlined),
                          label: Text(
                            _current?.source == ResolvedPriceSource.exactDate
                                ? 'Save audited correction'
                                : 'Save daily price',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            if (_error != null) ...[
              const SizedBox(height: 14),
              AsyncErrorCard(message: _error!, onRetry: _load),
            ],
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => context.go('/newspapers/new'),
              icon: const Icon(Icons.add),
              label: const Text('Add Custom Newspaper'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    DateTime initial;
    try {
      final parsed = LocalDate.parse(_date.text.trim());
      initial = DateTime(parsed.year, parsed.month, parsed.day);
    } on Object {
      initial = DateTime.now();
    }
    final selected = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (selected == null) return;
    _date.text = DateFormat('yyyy-MM-dd').format(selected);
    await _resolve();
  }

  String _money(int paise) =>
      NumberFormat.currency(locale: 'en_IN', symbol: '₹').format(paise / 100);

  String _sourceLabel(ResolvedPriceSource source) => switch (source) {
    ResolvedPriceSource.exactDate => 'Exact-date price',
    ResolvedPriceSource.period => 'Effective-period price',
    ResolvedPriceSource.defaultPrice => 'Default price',
  };
}
