part of 'utils.dart';

/// Exception thrown when a keep operation fails.
class KeepException<T> implements Exception {
  /// Creates a [KeepException].
  const KeepException(this.message, {this.key, this.error, this.stackTrace});

  /// The error message.
  final String message;

  /// The associated [KeepKey], if any.
  final KeepKey<T>? key;

  /// The underlying error object.
  final Object? error;

  /// The stack trace where the error occurred.
  final StackTrace? stackTrace;

  @override
  String toString() {
    final buffer = StringBuffer()
      ..write('KeepException: $message')
      ..write(', key: ${key?.name}')
      ..write(', error: $error')
      ..write(', stackTrace: $stackTrace');

    return buffer.toString();
  }
}
