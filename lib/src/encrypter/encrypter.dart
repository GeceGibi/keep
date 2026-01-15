import 'dart:async';
import 'dart:convert';

part 'encrypter_simple.dart';

/// Interface for encrypting and decrypting keep data.
///
/// Implement this class to provide custom encryption (e.g., AES-GCM via
/// `flutter_secure_storage` or platform keychain).
abstract class KeepEncrypter {
  /// Default constructor for [KeepEncrypter].
  const KeepEncrypter();

  /// Initializes the encrypter.
  Future<void> init();

  /// Encrypts the given [data] and returns a base64 string.
  FutureOr<String> encrypt(String data);

  /// Synchronously encrypts the given [data].
  ///
  /// Used by [KeepKey.readSync] and [KeepKey.writeSync] (if applicable).
  /// If your encryption is purely async, throw [UnimplementedError].
  String encryptSync(String data);

  /// Decrypts the given [data] and returns the original string content.
  FutureOr<String> decrypt(String data);

  /// Synchronously decrypts the given [data].
  ///
  /// Used by [KeepKey.readSync].
  /// If your encryption is purely async, throw [UnimplementedError].
  String decryptSync(String data);
}
