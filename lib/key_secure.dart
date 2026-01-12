part of 'vault.dart';

/// A specialized [VaultKey] that automatically encrypts and decrypts data
/// using the vault's [VaultEncrypter].
///
/// The key name is hashed with DJB2 for path obfuscation.
class VaultKeySecure<T> extends VaultKey<T> {
  /// Creates a [VaultKeySecure].
  VaultKeySecure({
    required super.name,
    required super.vault,
    required this.fromStorage,
    required this.toStorage,
    super.removable,
    super.useExternalStorage,
  });

  /// Converts raw storage data to typed object [T].
  final T? Function(Object? value) fromStorage;

  /// Converts typed object [T] to raw storage data.
  final Object? Function(T value) toStorage;

  /// Generates the hashed name for a given [key].
  static String generateHash(String key) {
    final bytes = utf8.encode(key);
    var hash = 5381; // DJB2 starting value

    for (final byte in bytes) {
      // (hash * 33) + byte
      hash = ((hash << 5) + hash) + byte;
    }

    // Avoid negative by converting to unsigned 64-bit and radix-36
    return hash.toUnsigned(64).toRadixString(36);
  }

  /// Returns key name hashed with DJB2 for path obscuring.
  String get hashedName => generateHash(super.name);

  @override
  String get name => hashedName;

  @override
  T? readSync() {
    try {
      final encryptedData = switch (useExternalStorage) {
        true => vault.external.readSync<String>(this),
        false => vault.internal.readSync<String>(this),
      };

      if (encryptedData == null) {
        return null;
      }

      final decrypted = vault.encrypter.decryptSync(encryptedData);
      return fromStorage(jsonDecode(decrypted));
    } catch (error, stackTrace) {
      final exception = toException(
        error.toString(),
        error: error,
        stackTrace: stackTrace,
      );

      vault.onError?.call(exception);
      unawaited(remove());
      return null;
    }
  }

  /// Reads, decrypts, and deserializes the value from storage.
  @override
  Future<T?> read() async {
    await vault._ensureInitialized;

    try {
      final encryptedData = switch (useExternalStorage) {
        true => await vault.external.read<String>(this),
        false => await vault.internal.read<String>(this),
      };

      if (encryptedData == null) {
        return null;
      }

      final decrypted = await vault.encrypter.decrypt(encryptedData);
      return fromStorage(await compute(jsonDecode, decrypted));
    } catch (error, stackTrace) {
      final exception = toException(
        error.toString(),
        error: error,
        stackTrace: stackTrace,
      );

      vault.onError?.call(exception);

      unawaited(remove());
      return null;
    }
  }

  /// Serializes, encrypts, and writes the value to storage.
  @override
  Future<void> write(T? value) async {
    await vault._ensureInitialized;

    if (value == null) {
      await remove();
      return;
    }
    final storageValue = toStorage(value);

    final encrypted = await vault.encrypter.encrypt(
      await compute(jsonEncode, storageValue),
    );

    vault._controller.add(this);

    if (useExternalStorage) {
      await vault.external.write(this, encrypted);
    } else {
      vault.internal.write(this, encrypted);
    }
  }
}
