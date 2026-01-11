part of 'vault.dart';

class VaultException implements Exception {
  VaultException(this.message, {this.key, this.error, this.stackTrace});
  final String message;
  final VaultKey? key;
  final Object? error;
  final StackTrace? stackTrace;

  @override
  String toString() => 'VaultException: $message';
}
