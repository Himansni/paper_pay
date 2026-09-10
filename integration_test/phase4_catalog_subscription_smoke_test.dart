import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:paper_route/core/config/firebase_bootstrap.dart';
import 'package:paper_route/core/domain/local_date.dart';
import 'package:paper_route/core/errors/app_exception.dart';
import 'package:paper_route/features/auth/domain/access_policy.dart';
import 'package:paper_route/features/auth/domain/app_user.dart';
import 'package:paper_route/features/newspapers/data/firebase_newspaper_repository.dart';
import 'package:paper_route/features/newspapers/domain/newspaper.dart';
import 'package:paper_route/features/subscriptions/data/firebase_subscription_repository.dart';
import 'package:paper_route/features/subscriptions/domain/customer_subscription.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'real repositories complete catalog, pricing, and subscription history against emulators',
    (_) async {
      final startup = await FirebaseBootstrap.initialize();
      expect(startup.isReady, isTrue);
      final auth = FirebaseAuth.instance;
      final firestore = FirebaseFirestore.instance;
      final newspaperRepository = FirebaseNewspaperRepository(firestore);
      final subscriptionRepository = FirebaseSubscriptionRepository(firestore);

      await auth.signOut();
      final headCredential = await auth.signInWithEmailAndPassword(
        email: 'phase4-head@example.test',
        password: 'Phase4-Smoke-2026!',
      );
      final headUid = headCredential.user!.uid;
      expect(headCredential.user!.emailVerified, isTrue);
      final head = AppUser(
        uid: headUid,
        email: headCredential.user!.email!,
        displayName: 'Phase 4 Head',
        isEmailVerified: true,
        businessId: 'business-phase4',
        role: UserRole.head,
        status: AccountStatus.active,
      );

      final firstPaperId = await newspaperRepository.createNewspaper(
        actor: head,
        input: const NewspaperInput(
          name: 'Phase 4 Daily Alpha',
          edition: 'City',
          language: 'English',
          defaultPricePaise: 650,
        ),
      );
      final secondPaperId = await newspaperRepository.createNewspaper(
        actor: head,
        input: const NewspaperInput(
          name: 'Phase Four Herald',
          edition: 'Morning',
          language: 'Hindi',
          defaultPricePaise: 500,
        ),
      );
      final employeePaperId = await newspaperRepository.createNewspaper(
        actor: head,
        input: const NewspaperInput(
          name: 'Employee Route Gazette',
          edition: '',
          language: 'English',
          defaultPricePaise: 400,
        ),
      );
      Future<NewspaperPage> searchActiveNewspapers(String term) =>
          newspaperRepository.fetchNewspapers(
            NewspaperListRequest(
              businessId: 'business-phase4',
              requesterId: headUid,
              searchField: NewspaperSearchField.name,
              searchTerm: term,
            ),
          );

      for (final term in const [
        'Phase 4 Daily Alpha',
        'phase 4 daily alpha',
        'phase 4 dai',
        '  phase 4 daily alpha  ',
      ]) {
        expect(
          (await searchActiveNewspapers(
            term,
          )).newspapers.map((paper) => paper.id),
          contains(firstPaperId),
          reason: term,
        );
      }
      await newspaperRepository.updateNewspaperProfile(
        actor: head,
        newspaperId: firstPaperId,
        input: const NewspaperProfileInput(
          name: 'Phase 4 Daily Alpha Edited',
          edition: 'Metro',
          language: 'English',
        ),
      );
      final editedPaper = await newspaperRepository
          .watchNewspaper(
            businessId: 'business-phase4',
            newspaperId: firstPaperId,
          )
          .firstWhere((paper) => paper?.name == 'Phase 4 Daily Alpha Edited')
          .timeout(const Duration(seconds: 5));
      expect(editedPaper?.searchName, 'phase 4 daily alpha edited');
      expect(
        (await searchActiveNewspapers(
          'phase 4 daily alpha edited',
        )).newspapers.map((paper) => paper.id),
        contains(firstPaperId),
      );

      final firstPage = await newspaperRepository.fetchNewspapers(
        NewspaperListRequest(
          businessId: 'business-phase4',
          requesterId: headUid,
          pageSize: 1,
        ),
      );
      expect(firstPage.newspapers, hasLength(1));
      expect(firstPage.hasMore, isTrue);
      final secondPage = await newspaperRepository.fetchNewspapers(
        NewspaperListRequest(
          businessId: 'business-phase4',
          requesterId: headUid,
          cursor: firstPage.nextCursor,
          pageSize: 1,
        ),
      );
      expect(secondPage.newspapers, hasLength(1));
      expect(
        secondPage.newspapers.single.id,
        isNot(firstPage.newspapers.single.id),
      );
      final codeSearch = await newspaperRepository.fetchNewspapers(
        NewspaperListRequest(
          businessId: 'business-phase4',
          requesterId: headUid,
          searchField: NewspaperSearchField.newspaperCode,
          searchTerm: firstPaperId,
        ),
      );
      expect(codeSearch.newspapers.single.id, firstPaperId);

      await newspaperRepository.createPriceRule(
        actor: head,
        newspaperId: firstPaperId,
        input: const PriceRuleInput(
          kind: PriceRuleKind.period,
          startDate: LocalDate(2026, 10, 1),
          endDate: LocalDate(2026, 10, 31),
          pricePaise: 700,
          reason: 'October publisher price',
        ),
      );
      final exactRuleId = await newspaperRepository.createPriceRule(
        actor: head,
        newspaperId: firstPaperId,
        input: const PriceRuleInput(
          kind: PriceRuleKind.exactDate,
          startDate: LocalDate(2026, 10, 12),
          endDate: null,
          pricePaise: 900,
          reason: 'Sunday special edition',
        ),
      );
      final periodPrice = await newspaperRepository.resolvePriceOn(
        businessId: 'business-phase4',
        newspaperId: firstPaperId,
        date: const LocalDate(2026, 10, 10),
      );
      expect(periodPrice.pricePaise, 700);
      expect(periodPrice.source, ResolvedPriceSource.period);
      final defaultPrice = await newspaperRepository.resolvePriceOn(
        businessId: 'business-phase4',
        newspaperId: firstPaperId,
        date: const LocalDate(2026, 9, 30),
      );
      expect(defaultPrice.pricePaise, 650);
      expect(defaultPrice.source, ResolvedPriceSource.defaultPrice);
      final exactPrice = await newspaperRepository.resolvePriceOn(
        businessId: 'business-phase4',
        newspaperId: firstPaperId,
        date: const LocalDate(2026, 10, 12),
      );
      expect(exactPrice.pricePaise, 900);
      expect(exactPrice.source, ResolvedPriceSource.exactDate);
      await newspaperRepository.correctPriceRule(
        actor: head,
        newspaperId: firstPaperId,
        replacedRuleId: exactRuleId,
        replacement: const PriceRuleInput(
          kind: PriceRuleKind.exactDate,
          startDate: LocalDate(2026, 10, 12),
          endDate: null,
          pricePaise: 950,
          reason: 'Corrected Sunday publisher notice',
        ),
      );
      expect(
        (await newspaperRepository.resolvePriceOn(
          businessId: 'business-phase4',
          newspaperId: firstPaperId,
          date: const LocalDate(2026, 10, 12),
        )).pricePaise,
        950,
      );
      final priceHistory = await newspaperRepository.fetchPriceRules(
        PriceRuleListRequest(
          businessId: 'business-phase4',
          newspaperId: firstPaperId,
        ),
      );
      expect(priceHistory.rules, hasLength(3));
      expect(
        priceHistory.rules
            .where((rule) => rule.id == exactRuleId)
            .single
            .status,
        PriceRuleStatus.superseded,
      );

      final firstSubscriptionId = await subscriptionRepository
          .createSubscription(
            actor: head,
            customerId: 'C-HEAD',
            input: SubscriptionInput(
              newspaperId: firstPaperId,
              startDate: const LocalDate(2026, 10, 1),
              endDate: null,
              quantity: 1,
              deliveryWeekdays: DeliveryWeekday.all,
              customPricePaise: 600,
              customPriceReason: 'Head-approved synthetic rate',
            ),
          );
      await subscriptionRepository.createSubscription(
        actor: head,
        customerId: 'C-HEAD',
        input: SubscriptionInput(
          newspaperId: secondPaperId,
          startDate: const LocalDate(2026, 10, 1),
          endDate: null,
          quantity: 1,
          deliveryWeekdays: DeliveryWeekday.all,
          customPricePaise: null,
          customPriceReason: '',
        ),
      );
      expect(
        await subscriptionRepository
            .watchCustomerSubscriptions(
              businessId: 'business-phase4',
              customerId: 'C-HEAD',
            )
            .firstWhere((subscriptions) => subscriptions.length == 2)
            .timeout(const Duration(seconds: 5)),
        hasLength(2),
      );

      await subscriptionRepository.replaceTerms(
        actor: head,
        customerId: 'C-HEAD',
        subscriptionId: firstSubscriptionId,
        effectiveFrom: const LocalDate(2026, 10, 15),
        replacement: SubscriptionInput(
          newspaperId: firstPaperId,
          startDate: const LocalDate(2026, 10, 1),
          endDate: null,
          quantity: 2,
          deliveryWeekdays: const {1, 2, 3, 4, 5, 6},
          customPricePaise: 600,
          customPriceReason: 'Head-approved synthetic rate',
        ),
      );
      await subscriptionRepository.addPause(
        actor: head,
        customerId: 'C-HEAD',
        subscriptionId: firstSubscriptionId,
        startDate: const LocalDate(2026, 10, 20),
        endDate: const LocalDate(2026, 10, 22),
        reason: 'Synthetic scheduled pause',
      );
      await subscriptionRepository.addPause(
        actor: head,
        customerId: 'C-HEAD',
        subscriptionId: firstSubscriptionId,
        startDate: const LocalDate(2026, 10, 25),
        endDate: null,
        reason: 'Synthetic open pause',
      );
      final paused = await subscriptionRepository
          .watchSubscription(
            businessId: 'business-phase4',
            customerId: 'C-HEAD',
            subscriptionId: firstSubscriptionId,
          )
          .firstWhere(
            (subscription) => subscription?.status == SubscriptionStatus.paused,
          )
          .timeout(const Duration(seconds: 5));
      expect(paused?.status, SubscriptionStatus.paused);
      await subscriptionRepository.resumeSubscription(
        actor: head,
        customerId: 'C-HEAD',
        subscriptionId: firstSubscriptionId,
        pauseId: paused!.currentPauseId,
        resumeDate: const LocalDate(2026, 10, 28),
      );
      await subscriptionRepository.endSubscription(
        actor: head,
        customerId: 'C-HEAD',
        subscriptionId: firstSubscriptionId,
        endDate: const LocalDate(2026, 10, 31),
      );
      final ended = await subscriptionRepository
          .watchSubscription(
            businessId: 'business-phase4',
            customerId: 'C-HEAD',
            subscriptionId: firstSubscriptionId,
          )
          .firstWhere(
            (subscription) => subscription?.status == SubscriptionStatus.ended,
          )
          .timeout(const Duration(seconds: 5));
      expect(ended?.status, SubscriptionStatus.ended);
      expect(ended?.endDate, const LocalDate(2026, 10, 31));
      final versionsBeforeRestart = await subscriptionRepository
          .watchVersions(
            businessId: 'business-phase4',
            customerId: 'C-HEAD',
            subscriptionId: firstSubscriptionId,
          )
          .firstWhere((versions) => versions.length == 2)
          .timeout(const Duration(seconds: 5));
      final auditsBeforeRestart = await subscriptionRepository
          .watchHistory(
            businessId: 'business-phase4',
            customerId: 'C-HEAD',
            subscriptionId: firstSubscriptionId,
          )
          .firstWhere((audits) => audits.length == 6)
          .timeout(const Duration(seconds: 5));
      final closedVersionIds =
          versionsBeforeRestart.map((version) => version.id).toSet();
      final closedEffectiveTo = <String, LocalDate?>{
        for (final version in versionsBeforeRestart)
          version.id: version.effectiveTo,
      };

      await expectLater(
        subscriptionRepository.replaceTerms(
          actor: head,
          customerId: 'C-HEAD',
          subscriptionId: firstSubscriptionId,
          effectiveFrom: const LocalDate(2026, 11, 1),
          replacement: SubscriptionInput(
            newspaperId: firstPaperId,
            startDate: const LocalDate(2026, 11, 1),
            endDate: const LocalDate(2026, 10, 31),
            quantity: 1,
            deliveryWeekdays: DeliveryWeekday.all,
            customPricePaise: 600,
            customPriceReason: 'Head-approved synthetic rate',
          ),
        ),
        throwsA(isA<AppException>()),
      );
      expect(
        await subscriptionRepository
            .watchVersions(
              businessId: 'business-phase4',
              customerId: 'C-HEAD',
              subscriptionId: firstSubscriptionId,
            )
            .first,
        hasLength(versionsBeforeRestart.length),
      );
      expect(
        await subscriptionRepository
            .watchHistory(
              businessId: 'business-phase4',
              customerId: 'C-HEAD',
              subscriptionId: firstSubscriptionId,
            )
            .first,
        hasLength(auditsBeforeRestart.length),
      );
      await subscriptionRepository.replaceTerms(
        actor: head,
        customerId: 'C-HEAD',
        subscriptionId: firstSubscriptionId,
        effectiveFrom: const LocalDate(2026, 11, 1),
        replacement: SubscriptionInput(
          newspaperId: firstPaperId,
          startDate: const LocalDate(2026, 11, 1),
          endDate: const LocalDate(2026, 11, 30),
          quantity: 1,
          deliveryWeekdays: DeliveryWeekday.all,
          customPricePaise: 600,
          customPriceReason: 'Head-approved synthetic rate',
        ),
      );
      final restarted = await subscriptionRepository
          .watchSubscription(
            businessId: 'business-phase4',
            customerId: 'C-HEAD',
            subscriptionId: firstSubscriptionId,
          )
          .firstWhere(
            (subscription) =>
                subscription?.status == SubscriptionStatus.active &&
                subscription?.startDate == const LocalDate(2026, 11, 1),
          )
          .timeout(const Duration(seconds: 5));
      expect(restarted?.quantity, 1);
      expect(restarted?.endDate, const LocalDate(2026, 11, 30));
      expect(ended?.endDate, const LocalDate(2026, 10, 31));
      final versionsAfterRestart = await subscriptionRepository
          .watchVersions(
            businessId: 'business-phase4',
            customerId: 'C-HEAD',
            subscriptionId: firstSubscriptionId,
          )
          .firstWhere(
            (versions) => versions.length == versionsBeforeRestart.length + 1,
          )
          .timeout(const Duration(seconds: 5));
      final auditsAfterRestart = await subscriptionRepository
          .watchHistory(
            businessId: 'business-phase4',
            customerId: 'C-HEAD',
            subscriptionId: firstSubscriptionId,
          )
          .firstWhere(
            (audits) => audits.length == auditsBeforeRestart.length + 1,
          )
          .timeout(const Duration(seconds: 5));
      expect(
        versionsAfterRestart.map((version) => version.id).toSet(),
        hasLength(versionsAfterRestart.length),
      );
      expect(
        auditsAfterRestart.map((audit) => audit.id).toSet(),
        hasLength(auditsAfterRestart.length),
      );
      expect(
        auditsAfterRestart.where(
          (audit) => audit.action == 'subscriptionRestarted',
        ),
        hasLength(1),
      );
      for (final version in versionsAfterRestart.where(
        (version) => closedVersionIds.contains(version.id),
      )) {
        expect(version.effectiveTo, closedEffectiveTo[version.id]);
      }
      await subscriptionRepository.endSubscription(
        actor: head,
        customerId: 'C-HEAD',
        subscriptionId: firstSubscriptionId,
        endDate: const LocalDate(2026, 11, 30),
      );
      final finalEnded = await subscriptionRepository
          .watchSubscription(
            businessId: 'business-phase4',
            customerId: 'C-HEAD',
            subscriptionId: firstSubscriptionId,
          )
          .firstWhere(
            (subscription) =>
                subscription?.status == SubscriptionStatus.ended &&
                subscription?.endDate == const LocalDate(2026, 11, 30),
          )
          .timeout(const Duration(seconds: 5));
      expect(finalEnded, isNotNull);
      expect(
        await subscriptionRepository
            .watchVersions(
              businessId: 'business-phase4',
              customerId: 'C-HEAD',
              subscriptionId: firstSubscriptionId,
            )
            .firstWhere((versions) => versions.length == 3)
            .timeout(const Duration(seconds: 5)),
        hasLength(3),
      );
      expect(
        await subscriptionRepository
            .watchPauses(
              businessId: 'business-phase4',
              customerId: 'C-HEAD',
              subscriptionId: firstSubscriptionId,
            )
            .firstWhere((pauses) => pauses.length == 2)
            .timeout(const Duration(seconds: 5)),
        hasLength(2),
      );
      expect(
        await subscriptionRepository
            .watchHistory(
              businessId: 'business-phase4',
              customerId: 'C-HEAD',
              subscriptionId: firstSubscriptionId,
            )
            .firstWhere((audits) => audits.length == 8)
            .timeout(const Duration(seconds: 5)),
        hasLength(8),
      );

      await newspaperRepository.setNewspaperArchived(
        actor: head,
        newspaperId: firstPaperId,
        archived: true,
      );
      expect(
        (await searchActiveNewspapers('phase 4 daily alpha')).newspapers,
        isEmpty,
      );
      expect(
        await subscriptionRepository
            .watchSubscription(
              businessId: 'business-phase4',
              customerId: 'C-HEAD',
              subscriptionId: firstSubscriptionId,
            )
            .first
            .timeout(const Duration(seconds: 5)),
        isNotNull,
      );
      await expectLater(
        subscriptionRepository.createSubscription(
          actor: head,
          customerId: 'C-EMPLOYEE',
          input: SubscriptionInput(
            newspaperId: firstPaperId,
            startDate: const LocalDate(2026, 11, 1),
            endDate: null,
            quantity: 1,
            deliveryWeekdays: DeliveryWeekday.all,
            customPricePaise: null,
            customPriceReason: '',
          ),
        ),
        throwsA(isA<AppException>()),
      );
      await newspaperRepository.setNewspaperArchived(
        actor: head,
        newspaperId: firstPaperId,
        archived: false,
      );
      final reactivated = await newspaperRepository
          .watchNewspaper(
            businessId: 'business-phase4',
            newspaperId: firstPaperId,
          )
          .firstWhere((paper) => paper?.status == NewspaperStatus.active)
          .timeout(const Duration(seconds: 5));
      expect(reactivated?.status, NewspaperStatus.active);
      expect(
        (await searchActiveNewspapers(
          'phase 4 daily alpha',
        )).newspapers.map((paper) => paper.id),
        contains(firstPaperId),
      );

      await auth.signOut();
      final employeeCredential = await auth.signInWithEmailAndPassword(
        email: 'phase4-employee@example.test',
        password: 'Phase4-Employee-2026!',
      );
      final employeeUid = employeeCredential.user!.uid;
      final employee = AppUser(
        uid: employeeUid,
        email: employeeCredential.user!.email!,
        displayName: 'Phase 4 Employee',
        isEmailVerified: true,
        businessId: 'business-phase4',
        role: UserRole.employee,
        status: AccountStatus.active,
        permissions: const {PermissionKey.manageAssignedSubscriptions},
        areaIds: const {'central'},
      );
      final employeeSubscriptionId = await subscriptionRepository
          .createSubscription(
            actor: employee,
            customerId: 'C-EMPLOYEE',
            input: SubscriptionInput(
              newspaperId: employeePaperId,
              startDate: const LocalDate(2026, 11, 1),
              endDate: null,
              quantity: 1,
              deliveryWeekdays: DeliveryWeekday.all,
              customPricePaise: null,
              customPriceReason: '',
            ),
          );
      expect(employeeSubscriptionId, employeePaperId);
      await subscriptionRepository.replaceTerms(
        actor: employee,
        customerId: 'C-EMPLOYEE',
        subscriptionId: employeeSubscriptionId,
        effectiveFrom: const LocalDate(2026, 11, 15),
        replacement: SubscriptionInput(
          newspaperId: employeePaperId,
          startDate: const LocalDate(2026, 11, 1),
          endDate: null,
          quantity: 2,
          deliveryWeekdays: const {1, 2, 3, 4, 5, 6},
          customPricePaise: null,
          customPriceReason: '',
        ),
      );
      await expectLater(
        subscriptionRepository.replaceTerms(
          actor: employee,
          customerId: 'C-EMPLOYEE',
          subscriptionId: employeeSubscriptionId,
          effectiveFrom: const LocalDate(2026, 11, 20),
          replacement: SubscriptionInput(
            newspaperId: employeePaperId,
            startDate: const LocalDate(2026, 11, 1),
            endDate: null,
            quantity: 2,
            deliveryWeekdays: const {1, 2, 3, 4, 5, 6},
            customPricePaise: 100,
            customPriceReason: 'Unauthorized synthetic rate',
          ),
        ),
        throwsA(isA<AppException>()),
      );
      await expectLater(
        subscriptionRepository.createSubscription(
          actor: employee,
          customerId: 'C-HEAD',
          input: SubscriptionInput(
            newspaperId: employeePaperId,
            startDate: const LocalDate(2026, 11, 1),
            endDate: null,
            quantity: 1,
            deliveryWeekdays: DeliveryWeekday.all,
            customPricePaise: null,
            customPriceReason: '',
          ),
        ),
        throwsA(isA<AppException>()),
      );

      await auth.signOut();
      await Firebase.app().delete();
    },
  );
}
