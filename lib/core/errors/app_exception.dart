/// Base class for user-facing application exceptions.
///
/// Repository implementations map raw database, network, or validation failures
/// into [AppException] subtypes so the UI never displays raw backend errors.
class AppException implements Exception {
  final String message;
  final Object? cause;

  const AppException(this.message, {this.cause});

  @override
  String toString() => message;
}

/// Thrown when a domain or form validation rule is violated.
class ValidationException extends AppException {
  const ValidationException(super.message, {super.cause});
}

/// Thrown when the current user is not permitted to perform an action.
class UnauthorizedException extends AppException {
  const UnauthorizedException(super.message, {super.cause});
}

/// Thrown when a requested entity does not exist.
class NotFoundException extends AppException {
  const NotFoundException(super.message, {super.cause});
}

/// Maps any arbitrary error into a friendly [AppException].
AppException mapToAppException(Object error) {
  if (error is AppException) return error;
  if (error is StateError) {
    return ValidationException(error.message, cause: error);
  }
  return AppException(
    'Something went wrong. Please try again.',
    cause: error,
  );
}
