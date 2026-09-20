import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paper_route/app/paper_route_app.dart';
import 'package:paper_route/core/config/firebase_bootstrap.dart';
import 'package:paper_route/features/auth/data/firebase_auth_repository.dart';
import 'package:paper_route/features/auth/presentation/auth_providers.dart';

Future<void> main() async {
  // Flutter plugins (including Firebase) need the engine binding before any
  // asynchronous platform initialization can run.
  WidgetsFlutterBinding.ensureInitialized();

  // BEGINNER NOTE:
  // Firebase is initialized before the widget tree so no screen can ask for
  // Auth or Firestore instances that are connected to the wrong environment.
  final startup = await FirebaseBootstrap.initialize();
  if (startup.isReady) {
    runApp(
      ProviderScope(
        // Riverpod receives the concrete Firebase repository here. Keeping the
        // rest of the app dependent on AuthRepository makes it testable without
        // connecting tests to a live Firebase project.
        overrides: [
          authRepositoryProvider.overrideWithValue(
            FirebaseAuthRepository.fromDefaultApp(),
          ),
        ],
        child: PaperRouteApp(startup: startup),
      ),
    );
  } else {
    // Fail closed: render setup guidance without constructing a repository
    // backed by Firebase services that did not initialize successfully.
    runApp(ProviderScope(child: PaperRouteApp(startup: startup)));
  }
}
