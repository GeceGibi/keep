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

    unawaited(keys._register(key));
    return key;
  }

  /// Converts raw storage data to typed object [T].
  final T? Function(Object? value) fromStorage;

  /// Converts typed object [T] to raw storage data.
  final Object? Function(T value) toStorage;

  T? _cachedValue;
  bool _hasCachedValue = false;

  @override
  T? readSync() {
    if (_hasCachedValue) {
      return _cachedValue;
    }

    try {
      final encrypted = switch (useExternal) {
        true => externalStorage.readSync<String>(this),
        false => _keep.internalStorage.readSync<String>(this),
      };

      if (encrypted == null) {
        _hasCachedValue = true;
        return _cachedValue = null;
      }

      final decrypted = _keep.encrypter.decryptSync(encrypted);
      final decoded = jsonDecode(decrypted);

      _hasCachedValue = true;
      return _cachedValue = fromStorage(decoded);
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

    if (_hasCachedValue) {
      return _cachedValue;
    }

    try {
      final encrypted = switch (useExternal) {
        true => await externalStorage.read<String>(this),
        false => await _keep.internalStorage.read<String>(this),
      };

      if (encrypted == null) {
        _hasCachedValue = true;
        return _cachedValue = null;
      }

      final decrypted = await _keep.encrypter.decrypt(encrypted);
      final decoded = await compute(jsonDecode, decrypted);

      _hasCachedValue = true;
      return _cachedValue = fromStorage(decoded);
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
      await remove();
      _cachedValue = null;
      _hasCachedValue = true;
    } else {
      try {
        final payload = toStorage(value);

        final encrypted = await _keep.encrypter.encrypt(
          await compute(jsonEncode, payload),
        );

        if (useExternal) {
          await externalStorage.write(this, encrypted);
        } else {
          await _keep.internalStorage.write(this, encrypted);
        }

        _cachedValue = value;
        _hasCachedValue = true;
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

    _keep.onChangeController.add(this);
  }
}
