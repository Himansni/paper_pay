/// A user-safe application error. Data repositories translate vendor-specific
/// exceptions into this type before they reach the presentation layer.
class AppException implements Exception {
  const AppException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => message;
}
