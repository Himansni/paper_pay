import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:paper_route/core/presentation/async_state_cards.dart';
import 'package:paper_route/features/auth/domain/app_user.dart';
import 'package:paper_route/features/business/domain/business_profile.dart';
import 'package:paper_route/features/business/presentation/business_providers.dart';

class BusinessSettingsPage extends ConsumerWidget {
  const BusinessSettingsPage({required this.user, super.key});

  final AppUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final businessId = user.businessId!;
    final business = ref.watch(businessProfileProvider(businessId));

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.go('/')),
        title: const Text('Business settings'),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Text(
              'Distributor details',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            const Text(
              'These shared details identify the business. Roles and access remain controlled by membership records.',
              style: TextStyle(color: Color(0xFF486581), height: 1.4),
            ),
            const SizedBox(height: 20),
            business.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error:
                  (error, _) => AsyncErrorCard(
                    message: 'Could not load business settings. $error',
                    onRetry:
                        () =>
                            ref.invalidate(businessProfileProvider(businessId)),
                  ),
              data:
                  (profile) => _BusinessSettingsForm(
                    key: ValueKey(profile),
                    profile: profile,
                    onSave:
                        ({required name, required phone, required address}) =>
                            ref
                                .read(businessRepositoryProvider)
                                .updateBusiness(
                                  businessId: businessId,
                                  actorId: user.uid,
                                  name: name,
                                  phone: phone,
                                  address: address,
                                ),
                  ),
            ),
            const SizedBox(height: 16),
            business.when(
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
              data:
                  (profile) => _PrimaryPricingRegionCard(
                    region: profile.primaryPricingRegion,
                    onSave:
                        (region) => ref
                            .read(businessRepositoryProvider)
                            .updatePrimaryPricingRegion(
                              businessId: businessId,
                              actorId: user.uid,
                              region: region,
                            ),
                  ),
            ),
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                key: const ValueKey('open-upi-settings'),
                onTap: () => context.push('/business-settings/upi'),
                leading: const Icon(Icons.qr_code_2_outlined),
                title: const Text('UPI collection settings'),
                subtitle: const Text(
                  'Configure the UPI ID and payee name used to build payment requests.',
                ),
                trailing: const Icon(Icons.chevron_right),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                key: const ValueKey('open-account-settings'),
                onTap: () => context.push('/account-settings'),
                leading: const Icon(Icons.manage_accounts_outlined),
                title: const Text('Personal account settings'),
                subtitle: const Text(
                  'Manage account credentials, sign out, or request account deletion.',
                ),
                trailing: const Icon(Icons.chevron_right),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrimaryPricingRegionCard extends StatefulWidget {
  const _PrimaryPricingRegionCard({required this.region, required this.onSave});

  final PricingRegion region;
  final Future<void> Function(PricingRegion region) onSave;

  @override
  State<_PrimaryPricingRegionCard> createState() =>
      _PrimaryPricingRegionCardState();
}

class _PrimaryPricingRegionCardState extends State<_PrimaryPricingRegionCard> {
  var _editing = false;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.location_city_outlined),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Primary pricing region',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (widget.region.isConfigured && !_editing)
                TextButton(
                  onPressed: () => setState(() => _editing = true),
                  child: const Text('Edit region'),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            widget.region.isConfigured
                ? '${widget.region.displayName}, ${widget.region.state}'
                : 'Set this once so Daily Pricing always opens in the correct local context.',
            style: const TextStyle(color: Color(0xFF486581), height: 1.4),
          ),
          if (!widget.region.isConfigured || _editing) ...[
            const SizedBox(height: 16),
            _PricingRegionForm(
              key: ValueKey(widget.region),
              initial: widget.region,
              onCancel:
                  widget.region.isConfigured
                      ? () => setState(() => _editing = false)
                      : null,
              onSave: (region) async {
                final messenger = ScaffoldMessenger.of(context);
                await widget.onSave(region);
                if (mounted) {
                  setState(() => _editing = false);
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Pricing region saved.')),
                  );
                }
              },
            ),
          ],
        ],
      ),
    ),
  );
}

class _PricingRegionForm extends StatefulWidget {
  const _PricingRegionForm({
    required this.initial,
    required this.onSave,
    this.onCancel,
    super.key,
  });

  final PricingRegion initial;
  final Future<void> Function(PricingRegion region) onSave;
  final VoidCallback? onCancel;

  @override
  State<_PricingRegionForm> createState() => _PricingRegionFormState();
}

class _PricingRegionFormState extends State<_PricingRegionForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _state;
  late final TextEditingController _city;
  late final TextEditingController _edition;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    _state = TextEditingController(text: widget.initial.state);
    _city = TextEditingController(text: widget.initial.districtCity);
    _edition = TextEditingController(text: widget.initial.editionServiceRegion);
  }

  @override
  void dispose() {
    _state.dispose();
    _city.dispose();
    _edition.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Form(
    key: _formKey,
    child: Column(
      children: [
        TextFormField(
          key: const ValueKey('pricing-region-state'),
          controller: _state,
          decoration: const InputDecoration(labelText: 'State'),
          validator: _required,
        ),
        const SizedBox(height: 12),
        TextFormField(
          key: const ValueKey('pricing-region-city'),
          controller: _city,
          decoration: const InputDecoration(labelText: 'District / city'),
          validator: _required,
        ),
        const SizedBox(height: 12),
        TextFormField(
          key: const ValueKey('pricing-region-edition'),
          controller: _edition,
          decoration: const InputDecoration(
            labelText: 'Edition / service region (optional)',
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            if (widget.onCancel != null)
              TextButton(
                onPressed: widget.onCancel,
                child: const Text('Cancel'),
              ),
            const Spacer(),
            FilledButton.icon(
              key: const ValueKey('save-pricing-region'),
              onPressed: _saving ? null : _save,
              icon:
                  _saving
                      ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Icon(Icons.save_outlined),
              label: const Text('Save region'),
            ),
          ],
        ),
      ],
    ),
  );

  String? _required(String? value) =>
      (value?.trim().length ?? 0) < 2 ? 'Enter at least 2 characters.' : null;

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await widget.onSave(
        PricingRegion(
          state: _state.text,
          districtCity: _city.text,
          editionServiceRegion: _edition.text,
        ),
      );
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

typedef _SaveBusiness =
    Future<void> Function({
      required String name,
      required String phone,
      required String address,
    });

class _BusinessSettingsForm extends StatefulWidget {
  const _BusinessSettingsForm({
    required this.profile,
    required this.onSave,
    super.key,
  });

  final BusinessProfile profile;
  final _SaveBusiness onSave;

  @override
  State<_BusinessSettingsForm> createState() => _BusinessSettingsFormState();
}

class _BusinessSettingsFormState extends State<_BusinessSettingsForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _addressController;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.profile.name);
    _phoneController = TextEditingController(text: widget.profile.phone);
    _addressController = TextEditingController(text: widget.profile.address);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Business name'),
                textInputAction: TextInputAction.next,
                validator:
                    (value) =>
                        value == null || value.trim().isEmpty
                            ? 'Enter the business name.'
                            : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(labelText: 'Business phone'),
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(labelText: 'Address'),
                minLines: 2,
                maxLines: 4,
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon:
                    _saving
                        ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Icon(Icons.save_outlined),
                label: Text(_saving ? 'Saving…' : 'Save business settings'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await widget.onSave(
        name: _nameController.text,
        phone: _phoneController.text,
        address: _addressController.text,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Business settings updated.')),
        );
      }
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
