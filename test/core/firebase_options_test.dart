import 'package:flutter_test/flutter_test.dart';
import 'package:paper_route/firebase_options.dart';

void main() {
  test('Android and Web point to PaperRouteDev', () {
    expect(DefaultFirebaseOptions.android.projectId, 'paperroutedev');
    expect(DefaultFirebaseOptions.web.projectId, 'paperroutedev');
    expect(
      DefaultFirebaseOptions.android.appId,
      '1:720004989036:android:e7140626772487fd4c9849',
    );
    expect(
      DefaultFirebaseOptions.web.appId,
      '1:720004989036:web:89c7f8865549ef3c4c9849',
    );
  });
}
