import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paper_route/app/paper_route_app.dart';
import 'package:paper_route/core/config/firebase_bootstrap.dart';
import 'package:paper_route/features/agency_registration/data/firebase_agency_registration_repository.dart';
import 'package:paper_route/features/agency_registration/presentation/agency_registration_providers.dart';
import 'package:paper_route/features/auth/data/firebase_auth_repository.dart';
import 'package:paper_route/features/auth/presentation/auth_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final startup = await FirebaseBootstrap.initialize();
  if (startup.isReady) {
    runApp(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(
            FirebaseAuthRepository.fromDefaultApp(),
          ),
          agencyRegistrationRepositoryProvider.overrideWithValue(
            FirebaseAgencyRegistrationRepository.fromDefaultApp(),
          ),
        ],
        child: PaperRouteApp(startup: startup),
      ),
    );
  } else {
    runApp(ProviderScope(child: PaperRouteApp(startup: startup)));
  }
}
