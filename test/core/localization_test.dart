import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paper_route/l10n/app_localizations.dart';

void main() {
  group('Localization Verification', () {
    test('English translations load expected newspaper vocabulary', () async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(l10n.appName, equals('PaperRoute'));
      expect(l10n.customersTitle, equals('Customers'));
      expect(l10n.subscriptionsTitle, equals('Newspaper Subscriptions'));
      expect(l10n.pauseAllSubscriptions, equals('Pause All Subscriptions'));
      expect(l10n.morningRouteTitle, equals('Morning Route'));
      expect(l10n.depotPickupTally, equals('Depot Pickup Circulation'));
      expect(l10n.outstandingTitle, equals('Current Outstanding'));
      expect(l10n.commonActive, equals('Active'));
      expect(l10n.commonArchived, equals('Archived'));
      expect(
        l10n.pauseNotice('10 Oct', '15 Oct', 6, '16 Oct'),
        contains('10 Oct to 15 Oct (6 days)'),
      );
    });

    test('Hindi translations load authentic distribution vocabulary', () async {
      final l10n = await AppLocalizations.delegate.load(const Locale('hi'));
      expect(l10n.appName, contains('पेपररूट'));
      expect(l10n.customersTitle, contains('ग्राहक'));
      expect(l10n.subscriptionsTitle, contains('अख़बार'));
      expect(l10n.pauseAllSubscriptions, contains('सभी अख़बार बंद करें'));
      expect(l10n.morningRouteTitle, contains('वितरण लाइन'));
      expect(l10n.depotPickupTally, contains('डिपो'));
      expect(l10n.outstandingTitle, contains('बकाया'));
      expect(l10n.markDelivered, contains('वितरण पूर्ण'));
      expect(
        l10n.pauseNotice('10 Oct', '15 Oct', 6, '16 Oct'),
        contains('6 दिन'),
      );
    });
  });
}
