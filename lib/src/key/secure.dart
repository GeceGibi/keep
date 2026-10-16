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
  /// [removable] indicates if the key should be cleared by
  /// [Keep.clearRemovable].
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

  static const int _isolateThreshold = 10 * 1024;

  /// Creates a sub-key by appending [subKeyName] to the current [name].
  @override
  KeepKeySecure<T> call(String subKeyName) {
    final key =
        KeepKeySecure<T>(
            name: subKeyName,
            removable: removable,
            useExternal: useExternal,
            storage: storage,
            fromStorage: fromStorage,
            toStorage: toStorage,
          )
          ..bind(_keep)
          .._parent = this;

    keys._register(key);
    return key;
  }

  /// Converts raw storage data to typed object [T].
  final T? Function(Object? value) fromStorage;

  /// Converts typed object [T] to raw storage data.
  final Object? Function(T value) toStorage;

  @override
  T? readSync() {
    if (_keep.valueCache.containsKey(storeName)) {
      return _keep.valueCache[storeName] as T?;
    }

    if (!_keep.isInitialized) {
      return null;
    }

    try {
      final encrypted = switch (useExternal) {
        true => externalStorage.readSync<String>(this),
        false => _keep.internalStorage.readSync<String>(this),
      };

      if (encrypted == null) {
        return _keep.valueCache[storeName] = null;
      }

      final decrypted = _keep.encrypter.decryptSync(encrypted);
      final decoded = jsonDecode(decrypted);

      final value = fromStorage(decoded);
      _keep.valueCache[storeName] = value;
      return value;
    } on KeepException<dynamic> {
      return null;
    } catch (error, stackTrace) {
      final exception = toException(
        error.toString(),
        error: error,
        stackTrace: stackTrace,
      );

      _keep.onError?.call(exception);
      return null;
    }
  }

  /// Reads the encrypted string from storage, decrypts it, and maps it to [T].
  @override
  Future<T?> read() async {
    await _keep.ensureInitialized;

    if (_keep.valueCache.containsKey(storeName)) {
      return _keep.valueCache[storeName] as T?;
    }

    try {
      final encrypted = switch (useExternal) {
        true => await externalStorage.read<String>(this),
        false => await _keep.internalStorage.read<String>(this),
      };

      if (encrypted == null) {
        return _keep.valueCache[storeName] = null;
      }

      final decrypted = await _keep.encrypter.decrypt(encrypted);
      final decoded = decrypted.length > _isolateThreshold
          ? await compute(jsonDecode, decrypted)
          : jsonDecode(decrypted);

      final value = fromStorage(decoded);
      _keep.valueCache[storeName] = value;
      return value;
    } on KeepException<dynamic> {
      return null;
    } catch (error, stackTrace) {
      final exception = toException(
        error.toString(),
        error: error,
        stackTrace: stackTrace,
      );

      _keep.onError?.call(exception);
      return null;
    }
  }

  /// Maps [value] to JSON, encrypts the result, and writes it to storage.
  @override
  Future<void> write(T value) async {
    await _keep.ensureInitialized;

    if (value == null) {
      await _removeInternal();
    } else {
      try {
        final payload = toStorage(value);
        final shouldOffload =
            (payload is String && payload.length > _isolateThreshold) ||
            (payload is List && payload.length > 500) ||
            (payload is Map && payload.length > 500);

        final encodedJson = shouldOffload
            ? await compute(jsonEncode, payload)
            : jsonEncode(payload);

        final encrypted = await _keep.encrypter.encrypt(encodedJson);

        if (useExternal) {
          await externalStorage.write(this, encrypted);
        } else {
          await _keep.internalStorage.write(this, encrypted);
        }

        _keep.valueCache[storeName] = value;
      } on KeepException<dynamic> {
        rethrow;
      } catch (error, stackTrace) {
        final exception = toException(
          error.toString(),
          error: error,
          stackTrace: stackTrace,
        );

        _keep.onError?.call(exception);
        throw exception;
      }
    }

    if (!_keep.onChangeController.isClosed) {
      _keep.onChangeController.add(this);
    }
  }
}
