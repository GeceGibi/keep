part of 'vault.dart';

/// Represents a typed key within the [Vault].
class VaultKey<T> {
  /// Creates a [VaultKey].
  ///
  /// [name] Unique identifier for the key.
  /// [vault] The vault instance this key belongs to.
  /// [removable] If true, this key can be cleared during mass operations.
  /// [useExternalStorage] If true, values are stored in individual files.
  VaultKey({
    required this.name,
    required this.vault,
    this.removable = false,
    this.useExternalStorage = false,
  });

  /// The vault instance this key belongs to.
  final Vault vault;

  /// The unique name/path of this key.
  final String name;

  /// Whether this key is removable during mass operations.
  final bool removable;

  /// Whether this key uses its own file for storage.
  final bool useExternalStorage;

  /// Creates a sub-key by appending [subKeyName] to current [name].
  VaultKey<T> call(Object? subKeyName) {
    return VaultKey<T>(
      name: '$name.$subKeyName',
      removable: removable,
      vault: vault,
      useExternalStorage: useExternalStorage,
    );
  }

  /// Returns true if this key currently exists in storage.
  FutureOr<bool> get exists async {
    await vault._ensureInitialized;

    try {
      if (useExternalStorage) {
        return vault.external.exists(this);
      }

      return vault.internal.exists(this);
    } catch (e, s) {
      final exception = toException(
        e.toString(),
        error: e,
        stackTrace: s,
      );

      vault.onError?.call(exception);

      throw exception;
    }
  }

  /// Synchronously checks if this key currently exists in storage.
  bool get existsSync {
    try {
      if (useExternalStorage) {
        return vault.external.existsSync(this);
      }

      return vault.internal.existsSync(this);
    } catch (e, s) {
      final exception = toException(
        e.toString(),
        error: e,
        stackTrace: s,
      );

      vault.onError?.call(exception);

      throw exception;
    }
  }

  /// Removes this key from storage.
  Future<void> remove() async {
    await vault._ensureInitialized;

    try {
      if (useExternalStorage) {
        await vault.external.remove(this);
      } else {
        vault.internal.remove(this);
      }
    } catch (e, s) {
      final exception = toException(
        e.toString(),
        error: e,
        stackTrace: s,
      );

      vault.onError?.call(exception);

      throw exception;
    }
  }

  /// Reads the value and returns [defaultValue] if not found.
  Future<T> readSafe(T defaultValue) async {
    return (await read()) ?? defaultValue;
  }

  /// Synchronously reads the value and returns [defaultValue] if not found.
  ///
  /// See [readSync] for warnings.
  T readSafeSync(T defaultValue) {
    return readSync() ?? defaultValue;
  }

  /// Synchronously reads the value from storage.
  ///
  /// **WARNING:** This method assumes the vault is already initialized.
  /// Calling this before [init] completes may throw an error or cause unexpected behavior.
  /// For external storage, this performs a blocking I/O operation.
  T? readSync() {
    try {
      return switch (useExternalStorage) {
        true => vault.external.readSync(this),
        false => vault.internal.readSync(this),
      };
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

  /// Reads the value from storage.
  Future<T?> read() async {
    await vault._ensureInitialized;

    try {
      return switch (useExternalStorage) {
        true => await vault.external.read(this),
        false => vault.internal.read(this),
      };
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

  /// Writes the [value] to storage.
  ///
  /// If [value] is null, the key is removed.
  Future<void> write(T? value) async {
    await vault._ensureInitialized;
    vault._controller.add(this);

    if (value == null) {
      await remove();
      return;
    }

    try {
      if (useExternalStorage) {
        await vault.external.write(this, value);
      } else {
        vault.internal.write(this, value);
      }
    } catch (error, stackTrace) {
      final exception = toException(
        error.toString(),
        error: error,
        stackTrace: stackTrace,
      );

      vault.onError?.call(exception);

      throw exception;
    }
  }

  /// Atomically updates the stored value using [updateFn].
  Future<void> update(T Function(T? currentValue) updateFn) async {
    try {
      final currentValue = await read();
      final newValue = updateFn(currentValue);
      await write(newValue);
    } on VaultException<T> catch (e) {
      vault.onError?.call(e);
      rethrow;
    } catch (error, stackTrace) {
      final exception = toException(
        error.toString(),
        error: error,
        stackTrace: stackTrace,
      );

      vault.onError?.call(exception);

      throw exception;
    }
  }

  /// Returns a stream of value changes for this specific key.
  Stream<VaultKey<T>> get stream {
    return vault.onChange.where((key) => key.name == name).cast<VaultKey<T>>();
  }

  /// Creates a [VaultException] for this key with the given [message].
  VaultException<T> toException(
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    return VaultException(
      message,
      key: this,
      error: error,
      stackTrace: stackTrace,
    );
  }
}
