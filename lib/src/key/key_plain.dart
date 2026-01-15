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
  /// [useExternalStorage] indicates if the value should be stored in its own file.
  /// [storage] is an optional custom storage adapter for this specific key.
  KeepKeyPlain({
    required super.name,
    this.fromStorage,
    this.toStorage,
    super.removable = false,
    super.useExternalStorage,
    super.storage,
  });

  /// Optional converter from storage to typed object [T].
  final T? Function(Object? value)? fromStorage;

  /// Optional converter from typed object [T] to storage.
  final Object? Function(T value)? toStorage;

  @override
  KeepKeyPlain<T> call(Object? subKeyName) {
    final key = KeepKeyPlain<T>(
      name: '$name.$subKeyName',
      removable: removable,
      useExternalStorage: useExternalStorage,
      storage: storage,
      fromStorage: fromStorage,
      toStorage: toStorage,
    )..bind(keep);
    return key;
  }

  @override
  T? readSync() {
    try {
      final raw = switch (useExternalStorage) {
        true => externalStorage.readSync<dynamic>(this),
        false => keep.internalStorage.readSync<dynamic>(this),
      };

      if (raw == null) return null;

      return fromStorage != null ? fromStorage!(raw) : raw as T?;
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

  @override
  Future<T?> read() async {
    await keep.ensureInitialized;

    try {
      final raw = await (useExternalStorage
          ? externalStorage.read<dynamic>(this)
          : keep.internalStorage.read<dynamic>(this));

      if (raw == null) return null;

      return fromStorage != null ? fromStorage!(raw) : raw as T?;
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

  @override
  Future<void> write(T? value) async {
    await keep.ensureInitialized;
    keep.onChangeController.add(this);

    if (value == null) {
      await remove();
      return;
    }

    try {
      final storageValue = toStorage != null ? toStorage!(value) : value;

      if (useExternalStorage) {
        await externalStorage.write(this, storageValue);
      } else {
        await keep.internalStorage.write(this, storageValue);
      }
    } catch (error, stackTrace) {
      final exception = toException(
        error.toString(),
        error: error,
        stackTrace: stackTrace,
      );

      keep.onError?.call(exception);

      throw exception;
    }
  }
}
