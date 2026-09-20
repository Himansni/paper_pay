abstract final class AuthFields {
  static String? required(String? value, String label) {
    if (value == null || value.trim().isEmpty) {
      return '$label is required';
    }
    return null;
  }

  static String? email(String? value) {
    final requiredError = required(value, 'Email');
    if (requiredError != null) return requiredError;
    final emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    return emailPattern.hasMatch(value!.trim())
        ? null
        : 'Enter a valid email address';
  }

  static String? password(String? value) {
    final requiredError = required(value, 'Password');
    if (requiredError != null) return requiredError;
    return value!.length >= 8 ? null : 'Use at least 8 characters';
  }
}
