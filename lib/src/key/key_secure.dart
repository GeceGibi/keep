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
  /// [name] is the unique identifier for this key.
  /// [fromStorage] maps the decrypted JSON object back to type [T].
  /// [toStorage] maps type [T] to a JSON-encodable object.
  /// [removable] indicates if the key should be cleared by [Keep.clearRemovable].
  /// [useExternal] indicates if the value should be stored in its own file.
  /// [storage] is an optional custom storage adapter for this specific key.
  KeepKeySecure({
    required super.name,
    required this.fromStorage,
    required this.toStorage,
    super.removable,
    super.useExternal,
    super.storage,
  });

  /// Creates a sub-key by appending [subKeyName] to the current [name].
  @override
  KeepKeySecure<T> call(Object? subKeyName) {
    final key = KeepKeySecure<T>(
      name: '${super.name}.$subKeyName',
      removable: removable,
      useExternal: useExternal,
      storage: storage,
      fromStorage: fromStorage,
      toStorage: toStorage,
    )..bind(keep);
    return key;
  }

  /// Converts raw storage data to typed object [T].
  final T? Function(Object? value) fromStorage;

  /// Converts typed object [T] to raw storage data.
  final Object? Function(T value) toStorage;

  @override
  T? readSync() {
    try {
      final encrypted = switch (useExternal) {
        true => externalStorage.readSync<String>(this),
        false => keep.internalStorage.readSync<String>(this),
      };

      if (encrypted == null) {
        return null;
      }

      final decrypted = keep.encrypter.decryptSync(encrypted);
      final decoded = jsonDecode(decrypted);

      // Migration Guard: Handle legacy { 'k': name, 'v': value } format
      if (decoded is Map && decoded.containsKey('v')) {
        return fromStorage(decoded['v']);
      }

      return fromStorage(decoded);
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
      final encrypted = switch (useExternal) {
        true => await externalStorage.read<String>(this),
        false => await keep.internalStorage.read<String>(this),
      };

      if (encrypted == null) {
        return null;
      }

      final decrypted = await keep.encrypter.decrypt(encrypted);
      final decoded = await compute(jsonDecode, decrypted);

      // Migration Guard: Handle legacy { 'k': name, 'v': value } format
      if (decoded is Map && decoded.containsKey('v')) {
        return fromStorage(decoded['v']);
      }

      return fromStorage(decoded);
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

    final payload = toStorage(value);

    final encrypted = await keep.encrypter.encrypt(
      await compute(jsonEncode, payload),
    );

    keep.onChangeController.add(this);

    if (useExternal) {
      await externalStorage.write(this, encrypted);
    } else {
      await keep.internalStorage.write(this, encrypted);
    }
  }
}
