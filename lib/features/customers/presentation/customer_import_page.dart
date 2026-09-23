import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:paper_route/core/presentation/async_state_cards.dart';
import 'package:paper_route/features/areas/domain/delivery_area.dart';
import 'package:paper_route/features/areas/presentation/area_providers.dart';
import 'package:paper_route/features/auth/domain/access_policy.dart';
import 'package:paper_route/features/auth/domain/app_user.dart';
import 'package:paper_route/features/customers/data/customer_import_service.dart';
import 'package:paper_route/features/customers/domain/customer_import_models.dart';
import 'package:paper_route/features/newspapers/presentation/newspaper_providers.dart';

class CustomerImportPage extends ConsumerStatefulWidget {
  const CustomerImportPage({required this.user, super.key});

  final AppUser user;

  @override
  ConsumerState<CustomerImportPage> createState() => _CustomerImportPageState();
}

class _CustomerImportPageState extends ConsumerState<CustomerImportPage> {
  static const _accessPolicy = AccessPolicy();
  final _textController = TextEditingController();
  final _importService = CustomerImportService();

  CustomerImportValidationResult? _validationResult;
  bool _isValidating = false;
  bool _isImporting = false;
  CustomerImportProgress? _progress;
  bool _skipDuplicates = true;
  String? _errorMessage;

  static const _sampleCsv = '''Name,Phone,Area,House No,Address,Landmark,Newspaper,Opening Balance
Ramesh Kumar,9876543210,Main Market,12,Main Market Road,Near Clock Tower,Dainik Jagran,150
Suresh Gupta,9876543211,Civil Lines,B-4,Civil Lines Sector 2,Opposite SBI Bank,The Times of India,0
Amit Sharma,9876543212,Gandhi Nagar,45/2,Gandhi Nagar Lane 3,Near Temple,Amar Ujala,200
Pooja Verma,9876543213,Main Market,C-101,Royal Apartments Main Market,Near Gate 1,Hindustan Dainik,0
Vikas Singh,9876543214,Civil Lines,108,Civil Lines Phase 1,Near Post Office,The Hindu,50''';

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _loadSample() {
    setState(() {
      _textController.text = _sampleCsv;
      _validationResult = null;
      _progress = null;
      _errorMessage = null;
    });
  }

  Future<void> _validate(List<DeliveryArea> areas) async {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      setState(() => _errorMessage = 'Please paste CSV content or load sample data.');
      return;
    }

    setState(() {
      _isValidating = true;
      _errorMessage = null;
      _validationResult = null;
    });

    try {
      final table = CustomerImportService.parseCsv(text);
      if (table.length <= 1) {
        throw Exception('CSV must contain a header row and at least one data row.');
      }

      final newspapersAsync = ref.read(
        activeNewspapersListProvider((
          businessId: widget.user.businessId!,
          requesterId: widget.user.uid,
        ),),
      );
      final newspapers = newspapersAsync.asData?.value ?? [];

      final result = await _importService.validateRows(
        csvTable: table,
        availableAreas: areas,
        availableNewspapers: newspapers,
        businessId: widget.user.businessId!,
        isHead: widget.user.isHead,
      );

      if (!mounted) return;
      setState(() {
        _validationResult = result;
        _isValidating = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isValidating = false;
      });
    }
  }

  Future<void> _startImport(List<DeliveryArea> areas) async {
    final result = _validationResult;
    if (result == null) return;

    final rowsToImport = _skipDuplicates
        ? result.rows.where((r) => r.isValid).toList()
        : result.rows.where((r) => r.errors.isEmpty).toList();

    if (rowsToImport.isEmpty) {
      setState(() => _errorMessage = 'No valid rows to import.');
      return;
    }

    setState(() {
      _isImporting = true;
      _errorMessage = null;
    });

    final newspapersAsync = ref.read(
      activeNewspapersListProvider((
        businessId: widget.user.businessId!,
        requesterId: widget.user.uid,
      ),),
    );
    final newspapers = newspapersAsync.asData?.value ?? [];

    try {
      final stream = _importService.executeChunkedImport(
        actor: widget.user,
        rowsToImport: rowsToImport,
        availableAreas: areas,
        availableNewspapers: newspapers,
        chunkSize: 50,
      );

      await for (final progress in stream) {
        if (!mounted) return;
        setState(() => _progress = progress);
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_accessPolicy.canCreateCustomer(widget.user)) {
      return Scaffold(
        appBar: AppBar(title: const Text('Bulk Customer Import')),
        body: const Padding(
          padding: EdgeInsets.all(20),
          child: EmptyStateCard(
            icon: Icons.lock_outline,
            title: 'Permission required',
            message: 'You are not permitted to import customers.',
          ),
        ),
      );
    }

    final businessId = widget.user.businessId!;
    final areasAsync = ref.watch(deliveryAreasProvider(businessId));
    final areas = (areasAsync.asData?.value ?? const <DeliveryArea>[])
        .where((a) => a.isActive)
        .toList();

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(
          onPressed: () => context.canPop() ? context.pop() : context.go('/customers'),
        ),
        title: const Text('Bulk Import Customers'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Import Customers via CSV',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Easily onboard hundreds of customers at once. Paste CSV data with headers: Name, Phone, Area, House No, Address, Landmark, Newspaper, Opening Balance.',
              style: TextStyle(color: Color(0xFF486581), height: 1.4),
            ),
            const SizedBox(height: 16),
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEEEE),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE53935)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Color(0xFFE53935)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Color(0xFFB71C1C)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            // Progress Section during/after import
            if (_progress != null) ...[
              Card(
                color: _progress!.isComplete
                    ? const Color(0xFFE8F5E9)
                    : const Color(0xFFE3F2FD),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _progress!.isComplete
                                ? Icons.check_circle_rounded
                                : Icons.sync_rounded,
                            color: _progress!.isComplete
                                ? const Color(0xFF2E7D32)
                                : const Color(0xFF1565C0),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            _progress!.isComplete
                                ? 'Import Completed!'
                                : 'Importing Customers...',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              color: _progress!.isComplete
                                  ? const Color(0xFF1B5E20)
                                  : const Color(0xFF0D47A1),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      LinearProgressIndicator(
                        value: _progress!.fraction,
                        backgroundColor: Colors.white,
                        color: _progress!.isComplete
                            ? const Color(0xFF2E7D32)
                            : const Color(0xFF1565C0),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Processed ${_progress!.processed} of ${_progress!.total} customers (${_progress!.successful} successful, ${_progress!.failed} failed).',
                        style: const TextStyle(fontSize: 14),
                      ),
                      if (_progress!.isComplete) ...[
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: () => context.go('/customers'),
                          icon: const Icon(Icons.people_outline),
                          label: const Text('View All Customers'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            // CSV Text Input Card
            if (_progress == null || !_progress!.isComplete) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'CSV Content',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                          TextButton.icon(
                            key: const ValueKey('load-sample-csv-button'),
                            onPressed: _isImporting ? null : _loadSample,
                            icon: const Icon(Icons.data_object, size: 18),
                            label: const Text('Load Sample Data'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        key: const ValueKey('csv-content-field'),
                        controller: _textController,
                        maxLines: 8,
                        enabled: !_isImporting,
                        decoration: InputDecoration(
                          hintText: 'Paste CSV rows here...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.all(12),
                        ),
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          key: const ValueKey('parse-validate-csv-button'),
                          onPressed: _isValidating || _isImporting || areas.isEmpty
                              ? null
                              : () => _validate(areas),
                          icon: _isValidating
                              ? const SizedBox.square(
                                  dimension: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.fact_check_outlined),
                          label: const Text('Parse & Validate CSV'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            // Validation Results & Summary Card
            if (_validationResult != null && (_progress == null || !_progress!.isComplete)) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Validation Summary',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _StatBox(
                            label: 'Total Rows',
                            value: '${_validationResult!.totalRows}',
                            color: const Color(0xFF243B53),
                          ),
                          const SizedBox(width: 8),
                          _StatBox(
                            label: 'Valid',
                            value: '${_validationResult!.validRows}',
                            color: const Color(0xFF2E7D32),
                          ),
                          const SizedBox(width: 8),
                          _StatBox(
                            label: 'Duplicates',
                            value: '${_validationResult!.duplicateRows}',
                            color: const Color(0xFFF57C00),
                          ),
                          const SizedBox(width: 8),
                          _StatBox(
                            label: 'Errors',
                            value: '${_validationResult!.invalidRows}',
                            color: const Color(0xFFD32F2F),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Skip Duplicate Rows'),
                        subtitle: const Text(
                          'Ignore rows whose phone numbers already exist in file or database.',
                        ),
                        value: _skipDuplicates,
                        onChanged: _isImporting
                            ? null
                            : (val) => setState(() => _skipDuplicates = val),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          key: const ValueKey('start-import-button'),
                          onPressed: _isImporting || !_validationResult!.canImport
                              ? null
                              : () => _startImport(areas),
                          icon: _isImporting
                              ? const SizedBox.square(
                                  dimension: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.cloud_upload_outlined),
                          label: Text(
                            'Import ${_skipDuplicates ? _validationResult!.validRows : _validationResult!.totalRows} Customers',
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF0F60FF),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Detailed Row Preview
              const Text(
                'Data Preview',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
              const SizedBox(height: 8),
              for (final row in _validationResult!.rows)
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: row.isValid
                          ? const Color(0xFFE8F5E9)
                          : (row.isDuplicateInFile || row.isDuplicateInDb)
                              ? const Color(0xFFFFF3E0)
                              : const Color(0xFFFFEBEE),
                      child: Icon(
                        row.isValid
                            ? Icons.check
                            : (row.isDuplicateInFile || row.isDuplicateInDb)
                                ? Icons.copy_rounded
                                : Icons.close,
                        color: row.isValid
                            ? const Color(0xFF2E7D32)
                            : (row.isDuplicateInFile || row.isDuplicateInDb)
                                ? const Color(0xFFF57C00)
                                : const Color(0xFFD32F2F),
                        size: 18,
                      ),
                    ),
                    title: Text(
                      '${row.name} (${row.phone})',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${row.areaName} • ${row.address}${row.newspaperName.isNotEmpty ? ' • ${row.newspaperName}' : ''}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        if (row.errors.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          for (final err in row.errors)
                            Text(
                              '• $err',
                              style: const TextStyle(
                                color: Color(0xFFD32F2F),
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
