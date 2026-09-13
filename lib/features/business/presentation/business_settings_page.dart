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
              style: TextStyle(color: Color(0xFF627D98), height: 1.4),
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
          ],
        ),
      ),
    );
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
