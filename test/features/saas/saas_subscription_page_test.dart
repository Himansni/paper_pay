import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paper_route/features/auth/domain/app_user.dart';
import 'package:paper_route/features/saas/domain/saas_models.dart';
import 'package:paper_route/features/saas/domain/saas_repository.dart';
import 'package:paper_route/features/saas/presentation/read_only_gate.dart';
import 'package:paper_route/features/saas/presentation/saas_providers.dart';
import 'package:paper_route/features/saas/presentation/saas_subscription_page.dart';

class _FakeSaasRepository implements SaasRepository {
  _FakeSaasRepository(this._subscription);

  SaasSubscription _subscription;
  final StreamController<SaasSubscription> _controller =
      StreamController<SaasSubscription>.broadcast();
  final List<String> requestedPlans = [];

  @override
  Stream<SaasSubscription> watchSubscription(String businessId) {
    return _controller.stream.transform(
      StreamTransformer.fromHandlers(
        handleData: (data, sink) => sink.add(data),
      ),
    )..listen(null, onDone: () {});
  }

  void emit(SaasSubscription sub) {
    _subscription = sub;
    _controller.add(sub);
  }

  @override
  Future<SaasSubscription> fetchSubscription(String businessId) async =>
      _subscription;

  @override
  Future<void> requestPlanRenewal({
    required String businessId,
    required String actorId,
    required String targetPlanId,
  }) async {
    requestedPlans.add(targetPlanId);
  }
}

void main() {
  const headUser = AppUser(
    uid: 'head-1',
    email: 'head@example.com',
    displayName: 'Head Distributor',
    isEmailVerified: true,
    businessId: 'biz-1',
    role: UserRole.head,
    status: AccountStatus.active,
  );

  const employeeUser = AppUser(
    uid: 'emp-1',
    email: 'emp@example.com',
    displayName: 'Delivery Boy',
    isEmailVerified: true,
    businessId: 'biz-1',
    role: UserRole.employee,
    status: AccountStatus.active,
  );

  Widget createHarness({
    required AppUser user,
    required _FakeSaasRepository repo,
    Widget? child,
  }) {
    return ProviderScope(
      overrides: [
        saasRepositoryProvider.overrideWithValue(repo),
        saasSubscriptionProvider.overrideWith(
          (ref, businessId) => Stream.value(repo._subscription),
        ),
      ],
      child: MaterialApp(
        home: child ?? SaasSubscriptionPage(user: user),
      ),
    );
  }

  group('SaasSubscriptionPage', () {
    testWidgets('employee is blocked with Head access required message', (
      tester,
    ) async {
      final repo = _FakeSaasRepository(
        SaasSubscription.initialTrial(
          businessId: 'biz-1',
          activationTime: DateTime.now(),
        ),
      );

      await tester.pumpWidget(createHarness(user: employeeUser, repo: repo));
      await tester.pumpAndSettle();

      expect(find.text('Head access required'), findsOneWidget);
      expect(find.byType(ListView), findsNothing);
    });

    testWidgets('Head sees trial status card, data protection card, and plan catalog', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1200, 2400);
      addTearDown(tester.view.reset);

      final repo = _FakeSaasRepository(
        SaasSubscription.initialTrial(
          businessId: 'biz-1',
          activationTime: DateTime.now().subtract(const Duration(days: 5)),
        ),
      );

      await tester.pumpWidget(createHarness(user: headUser, repo: repo));
      await tester.pumpAndSettle();

      expect(find.text('Free 30-Day Trial Active'), findsOneWidget);
      expect(find.textContaining('25 days remaining'), findsOneWidget);
      expect(find.text('Customer limit: 500'), findsOneWidget);
      expect(find.text('Grace period: 7 Days'), findsOneWidget);

      // Data protection reassurance card
      expect(find.text('Financial Records Permanently Preserved'), findsOneWidget);
      expect(find.byKey(const ValueKey('saas-export-data-btn')), findsOneWidget);

      // Plans catalog
      expect(find.text('Starter Plan'), findsOneWidget);
      expect(find.text('Growth Plan'), findsOneWidget);
      expect(find.text('Agency Pro Plan'), findsOneWidget);
      expect(find.text('MOST POPULAR'), findsOneWidget);
    });

    testWidgets('selecting a plan opens dialog and submits requestPlanRenewal', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1200, 2400);
      addTearDown(tester.view.reset);

      final repo = _FakeSaasRepository(
        SaasSubscription.initialTrial(
          businessId: 'biz-1',
          activationTime: DateTime.now(),
        ),
      );

      await tester.pumpWidget(createHarness(user: headUser, repo: repo));
      await tester.pumpAndSettle();

      final selectGrowth = find.text('Select Growth Plan');
      expect(selectGrowth, findsOneWidget);

      await tester.tap(selectGrowth);
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Select Growth Plan'), findsNWidgets(2));
      expect(find.textContaining('Max customers: 1000'), findsOneWidget);

      await tester.tap(find.text('Submit request'));
      await tester.pumpAndSettle();

      expect(repo.requestedPlans, contains('growth'));
    });
  });

  group('ReadOnlyNoticeBanner', () {
    testWidgets('displays grace period banner when subscription is in grace', (
      tester,
    ) async {
      // 32 days ago (trial expired 2 days ago, 5 days grace left)
      final sub = SaasSubscription.initialTrial(
        businessId: 'biz-1',
        activationTime: DateTime.now().subtract(const Duration(days: 32)),
      );
      final repo = _FakeSaasRepository(sub);

      await tester.pumpWidget(
        createHarness(
          user: headUser,
          repo: repo,
          child: const Scaffold(
            body: Column(
              children: [
                ReadOnlyNoticeBanner(businessId: 'biz-1'),
                Text('Main App Content'),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Grace period: 5 days remaining'), findsOneWidget);
      expect(find.text('Renew now'), findsOneWidget);
    });

    testWidgets('displays read-only banner when subscription has expired past grace', (
      tester,
    ) async {
      // 40 days ago (expired past grace)
      final sub = SaasSubscription.initialTrial(
        businessId: 'biz-1',
        activationTime: DateTime.now().subtract(const Duration(days: 40)),
      );
      final repo = _FakeSaasRepository(sub);

      await tester.pumpWidget(
        createHarness(
          user: headUser,
          repo: repo,
          child: const Scaffold(
            body: Column(
              children: [
                ReadOnlyNoticeBanner(businessId: 'biz-1'),
                Text('Main App Content'),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Subscription expired — Read-Only Mode. Records are safe.'),
        findsOneWidget,
      );
      expect(find.text('View plans'), findsOneWidget);
    });
  });
}
