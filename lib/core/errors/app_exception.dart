// BEGINNER NOTE:
// [AppException] serves as the unified error boundary between data layers and the UI.
// Repositories catch low-level infrastructure errors (such as FirebaseException with codes
// like 'permission-denied', 'failed-precondition', or 'unavailable') and map them to friendly,
// user-safe [AppException] instances.
// This prevents raw database or vendor exceptions from leaking into presentation widgets,
// allowing UI error cards and snackbars to render clear, actionable messages.
/// A user-safe application error. Data repositories translate vendor-specific
/// exceptions into this type before they reach the presentation layer.
class AppException implements Exception {
  const AppException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => message;
}
