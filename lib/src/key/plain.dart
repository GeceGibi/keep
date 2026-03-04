part of 'key.dart';

/// A standard implementation of [KeepKey] that stores data as plain JSON.
///
/// [KeepKeyPlain] is the default key type used for most data that does not
/// require encryption. It handles both internal (in-memory) and external
/// (file-based) storage seamlessly.
class KeepKeyPlain<T> extends KeepKey<T> {
  /// Creates a [KeepKeyPlain].
  ///
  /// [name] is the unique identifier for this key.
  /// [removable] indicates if the key should be cleared by [Keep.clearRemovable].
  /// [useExternal] indicates if the value should be stored in its own file.
  /// [storage] is an optional custom storage adapter for this specific key.
  KeepKeyPlain({
    required super.name,
    this.fromStorage,
    this.toStorage,
    super.removable = false,
    super.useExternal,
    super.storage,
  });

  /// Optional converter from storage to typed object [T].
  final T? Function(Object? value)? fromStorage;

  /// Optional converter from typed object [T] to storage.
  final Object? Function(T value)? toStorage;

  T? _cachedValue;
  bool _hasCachedValue = false;

  @override
  KeepKeyPlain<T> call(String subKeyName) {
    final key =
        KeepKeyPlain<T>(
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

  @override
  T? readSync() {
    if (_hasCachedValue) {
      return _cachedValue;
    }

    try {
      final raw = switch (useExternal) {
        true => externalStorage.readSync<dynamic>(this),
        false => _keep.internalStorage.readSync<dynamic>(this),
      };

      if (raw == null) {
        _hasCachedValue = true;
        return _cachedValue = null;
      }

      _hasCachedValue = true;
      return _cachedValue = fromStorage != null ? fromStorage!(raw) : raw as T?;
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

  @override
  Future<T?> read() async {
    await _keep.ensureInitialized;

    if (_hasCachedValue) {
      return _cachedValue;
    }

    try {
      final raw = await (useExternal
          ? externalStorage.read<dynamic>(this)
          : _keep.internalStorage.read<dynamic>(this));

      if (raw == null) {
        _hasCachedValue = true;
        return _cachedValue = null;
      }

      _hasCachedValue = true;
      return _cachedValue = fromStorage != null ? fromStorage!(raw) : raw as T?;
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

  @override
  Future<void> write(T value) async {
    await _keep.ensureInitialized;

    if (value == null) {
      await remove();
      _cachedValue = null;
      _hasCachedValue = true;
    } else {
      try {
        final storageValue = toStorage != null ? toStorage!(value) : value;

        if (useExternal) {
          await externalStorage.write(this, storageValue);
        } else {
          await _keep.internalStorage.write(this, storageValue);
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
