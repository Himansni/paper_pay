import 'package:paper_route/core/errors/app_exception.dart';
import 'package:paper_route/features/collections/domain/collection_models.dart';

abstract final class UpiPaymentUriBuilder {
  static Uri build({
    required UpiSettings settings,
    required int amountPaise,
    required String paymentReference,
    String note = '',
  }) {
    _validateSettings(settings);
    if (amountPaise <= 0 || amountPaise > maximumCollectionAmountPaise) {
      throw const AppException('Enter a valid positive UPI amount.');
    }
    final reference = paymentReference.trim();
    if (reference.length < 3 || reference.length > 35) {
      throw const AppException(
        'UPI payment reference must be between 3 and 35 characters.',
      );
    }
    return Uri(
      scheme: 'upi',
      host: 'pay',
      queryParameters: {
        'pa': settings.upiId,
        'pn': settings.payeeName,
        'am': _formatPaise(amountPaise),
        'cu': 'INR',
        'tr': reference,
        if (note.trim().isNotEmpty) 'tn': note.trim(),
      },
    );
  }

  static Uri buildStatic({required UpiSettings settings}) {
    _validateSettings(settings);
    return Uri(
      scheme: 'upi',
      host: 'pay',
      queryParameters: {
        'pa': settings.upiId,
        'pn': settings.payeeName,
        'cu': 'INR',
      },
    );
  }

  static String deterministicReference({
    required UpiSettings settings,
    required String customerId,
    required String idempotencyKey,
  }) {
    final source = '${settings.referencePrefix}-$customerId-$idempotencyKey';
    final normalized = source
        .toUpperCase()
        .replaceAll(RegExp('[^A-Z0-9_-]'), '')
        .replaceAll(RegExp('[-_]{2,}'), '-');
    if (normalized.length < 3) {
      throw const AppException('Could not create a safe UPI reference.');
    }
    return normalized.substring(
      0,
      normalized.length > 35 ? 35 : normalized.length,
    );
  }

  static void _validateSettings(UpiSettings settings) {
    if (!settings.enabled || !settings.isConfigured) {
      throw const AppException(
        'UPI collection is not enabled for this business.',
      );
    }
    UpiSettingsInput(
      upiId: settings.upiId,
      payeeName: settings.payeeName,
      referencePrefix: settings.referencePrefix,
      enabled: settings.enabled,
    ).validate();
  }

  static String _formatPaise(int paise) =>
      '${paise ~/ 100}.${(paise % 100).toString().padLeft(2, '0')}';
}
