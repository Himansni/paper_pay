import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:paper_route/core/presentation/async_state_cards.dart';
import 'package:paper_route/features/auth/domain/app_user.dart';
import 'package:paper_route/features/newspapers/domain/newspaper.dart';
import 'package:paper_route/features/newspapers/presentation/newspaper_providers.dart';

class NewspaperFormRoutePage extends ConsumerWidget {
  const NewspaperFormRoutePage({
    required this.user,
    this.newspaperId,
    super.key,
  });

  final AppUser user;
  final String? newspaperId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = newspaperId;
    if (id == null) return NewspaperFormPage(user: user);
    final key = (businessId: user.businessId!, newspaperId: id);
    return ref
        .watch(newspaperProvider(key))
        .when(
          loading:
              () => const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              ),
          error:
              (error, _) => Scaffold(
                appBar: AppBar(title: const Text('Edit newspaper')),
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
                        appBar: AppBar(title: const Text('Edit newspaper')),
                        body: const Padding(
                          padding: EdgeInsets.all(20),
                          child: EmptyStateCard(
                            icon: Icons.newspaper_outlined,
                            title: 'Newspaper not found',
                            message: 'This catalog record is unavailable.',
                          ),
                        ),
                      )
                      : NewspaperFormPage(user: user, newspaper: newspaper),
        );
  }
}

class NewspaperFormPage extends ConsumerStatefulWidget {
  const NewspaperFormPage({required this.user, this.newspaper, super.key});

  final AppUser user;
  final Newspaper? newspaper;

  @override
  ConsumerState<NewspaperFormPage> createState() => _NewspaperFormPageState();
}

class _NewspaperFormPageState extends ConsumerState<NewspaperFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _edition;
  late final TextEditingController _language;
  late final TextEditingController _defaultPrice;
  bool _isBusy = false;

  bool get _isEditing => widget.newspaper != null;

  @override
  void initState() {
    super.initState();
    final newspaper = widget.newspaper;
    _name = TextEditingController(text: newspaper?.name ?? '');
    _edition = TextEditingController(text: newspaper?.edition ?? '');
    _language = TextEditingController(text: newspaper?.language ?? '');
    _defaultPrice = TextEditingController(
      text:
          newspaper == null
              ? ''
              : NewspaperMoney.formatPaiseForInput(newspaper.defaultPricePaise),
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _edition.dispose();
    _language.dispose();
    _defaultPrice.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.user.isHead) {
      return Scaffold(
        appBar: AppBar(title: const Text('Newspaper')),
        body: const Padding(
          padding: EdgeInsets.all(20),
          child: EmptyStateCard(
            icon: Icons.lock_outline,
            title: 'Head access required',
            message: 'Only the Head can change the newspaper catalog.',
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: _back),
        title: Text(_isEditing ? 'Edit newspaper' : 'New newspaper'),
      ),
      body: SafeArea(
        top: false,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
            children: [
              Text(
                _isEditing ? widget.newspaper!.name : 'Catalog publication',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _isEditing
                    ? 'The stable newspaper code and baseline price cannot be rewritten.'
                    : 'Add any publication; example titles are never hardcoded.',
                style: const TextStyle(color: Color(0xFF627D98), height: 1.4),
              ),
              const SizedBox(height: 20),
              TextFormField(
                key: const ValueKey('newspaper-name-field'),
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Newspaper name'),
                validator: _required,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _edition,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Edition (optional)',
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _language,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Language (optional)',
                ),
              ),
              const SizedBox(height: 14),
              if (!_isEditing)
                TextFormField(
                  key: const ValueKey('newspaper-default-price-field'),
                  controller: _defaultPrice,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Initial default price (₹)',
                    helperText:
                        'This historical fallback is immutable. Later prices use audited date rules.',
                  ),
                  validator: _required,
                )
              else
                InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Initial default price',
                  ),
                  child: Text(
                    '₹${NewspaperMoney.formatPaiseForInput(widget.newspaper!.defaultPricePaise)} (immutable)',
                  ),
                ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _isBusy ? null : _submit,
                icon:
                    _isBusy
                        ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Icon(Icons.save_outlined),
                label: Text(_isEditing ? 'Save profile' : 'Create newspaper'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isBusy = true);
    try {
      final repository = ref.read(newspaperRepositoryProvider);
      if (_isEditing) {
        final input = NewspaperProfileInput(
          name: _name.text,
          edition: _edition.text,
          language: _language.text,
        );
        input.validate();
        await repository.updateNewspaperProfile(
          actor: widget.user,
          newspaperId: widget.newspaper!.id,
          input: input,
        );
      } else {
        final input = NewspaperInput(
          name: _name.text,
          edition: _edition.text,
          language: _language.text,
          defaultPricePaise: NewspaperMoney.parseRupeesToPaise(
            _defaultPrice.text,
          ),
        );
        input.validate();
        await repository.createNewspaper(actor: widget.user, input: input);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEditing ? 'Newspaper profile updated.' : 'Newspaper created.',
          ),
        ),
      );
      _back(result: true);
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

  String? _required(String? value) =>
      (value?.trim().isEmpty ?? true) ? 'This field is required.' : null;

  void _back({bool result = false}) {
    if (context.canPop()) {
      context.pop(result);
    } else {
      context.go('/newspapers');
    }
  }
}
