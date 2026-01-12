part of 'vault.dart';

/// Interface for encrypting and decrypting vault data.
///
/// Implement this class to provide custom encryption (e.g., AES-GCM via
/// `flutter_secure_storage` or platform keychain).
abstract class VaultEncrypter {
  /// Default constructor for [VaultEncrypter].
  const VaultEncrypter();

  /// Initializes the encrypter.
  Future<void> init();

  /// Encrypts the given [data] and returns a base64 string.
  FutureOr<String> encrypt(String data);

  /// Decrypts the given [data] and returns the original string content.
  FutureOr<String> decrypt(String data);
}
