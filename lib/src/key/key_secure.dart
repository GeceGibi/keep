part of 'key.dart';

/// A specialized [KeepKey] that automatically encrypts and decrypts data
/// before it reaches the storage layer.
///
/// [KeepKeySecure] uses the [KeepEncrypter] provided to the [Keep] instance
/// to secure the data. Additionally, the key's [name] is hashed using the
/// DJB2 algorithm to obfuscate its identity on the physical disk/storage.
class KeepKeySecure<T> extends KeepKey<T> {
  /// Creates a [KeepKeySecure].
  ///
  /// - [fromStorage]: Maps the decrypted JSON object back to type [T].
  /// - [toStorage]: Maps type [T] to a JSON-encodable object.
  KeepKeySecure({
    required super.name,
    required super.keep,
    required this.fromStorage,
    required this.toStorage,
    super.removable,
    super.useExternalStorage,
  });

  /// Creates a sub-key by appending [subKeyName] to the current [name].
  @override
  KeepKeySecure<T> call(Object? subKeyName) {
    return KeepKeySecure<T>(
      name: '${super.name}.$subKeyName',
      keep: keep,
      removable: removable,
      useExternalStorage: useExternalStorage,
      fromStorage: fromStorage,
      toStorage: toStorage,
    );
  }

  /// Converts raw storage data to typed object [T].
  final T? Function(Object? value) fromStorage;

  /// Converts typed object [T] to raw storage data.
  final Object? Function(T value) toStorage;

  /// Generates a non-reversible hash for a given [key] name using DJB2.
  ///
  /// This is used to prevent the real key name from appearing in the storage
  /// (e.g., as a filename or a key in a map), providing an extra layer of privacy.
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

  /// Returns the [name] hashed with DJB2 for storage obfuscation.
  String get hashedName => generateHash(super.name);

  @override
  String get name => hashedName;

  @override
  T? readSync() {
    try {
      final encrypted = switch (useExternalStorage) {
        true => keep.externalStorage.readSync<String>(this),
        false => keep.internalStorage.readSync<String>(this),
      };

      if (encrypted == null) {
        return null;
      }

      final decrypted = keep.encrypter.decryptSync(encrypted);
      return fromStorage(jsonDecode(decrypted));
    } catch (error, stackTrace) {
      final exception = toException(
        error.toString(),
        error: error,
        stackTrace: stackTrace,
      );

      keep.onError?.call(exception);
      unawaited(remove());
      return null;
    }
  }

  /// Reads the encrypted string from storage, decrypts it, and maps it to [T].
  @override
  Future<T?> read() async {
    await keep.ensureInitialized;

    try {
      final encrypted = switch (useExternalStorage) {
        true => await keep.externalStorage.read<String>(this),
        false => await keep.internalStorage.read<String>(this),
      };

      if (encrypted == null) {
        return null;
      }

      final decrypted = await keep.encrypter.decrypt(encrypted);
      return fromStorage(await compute(jsonDecode, decrypted));
    } catch (error, stackTrace) {
      final exception = toException(
        error.toString(),
        error: error,
        stackTrace: stackTrace,
      );

      keep.onError?.call(exception);

      unawaited(remove());
      return null;
    }
  }

  /// Maps [value] to JSON, encrypts the result, and writes it to storage.
  @override
  Future<void> write(T? value) async {
    await keep.ensureInitialized;

    if (value == null) {
      await remove();
      return;
    }

    final storageValue = toStorage(value);

    final encrypted = await keep.encrypter.encrypt(
      await compute(jsonEncode, storageValue),
    );

    keep.onChangeController.add(this);

    if (useExternalStorage) {
      await keep.externalStorage.write(this, encrypted);
    } else {
      await keep.internalStorage.write(this, encrypted);
    }
  }
}
