import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:keep/src/keep.dart';
import 'package:keep/src/storage/storage.dart';
import 'package:keep/src/utils/utils.dart';

part 'plain.dart';
part 'secure.dart';
part 'sub_key_manager.dart';

/// Abstract base class for all typed keys in [Keep].
///
/// A [KeepKey] acts as a handle to a specific entry in storage. It provides
/// both synchronous and asynchronous methods for reading and writing data,
/// as well as a [Stream] interface to listen for value changes.
///
/// Implementations like [KeepKeyPlain] and [KeepKeySecure] define how the
/// data is handled (e.g., plain JSON or encrypted).
abstract class KeepKey<T> {
  /// [name] is the unique identifier for this key.
  /// [removable] indicates if the key should be cleared by [Keep.clearRemovable].
  /// [useExternal] indicates if the value should be stored in its own file.
  /// [storage] is an optional custom storage adapter for this specific key.
  KeepKey({
    required this.name,
    this.removable = false,
    bool? useExternal,
    this.storage,
  }) : useExternal = useExternal ?? (storage != null);

  /// Whether this key should use external (file-based or custom) storage.
  /// Defaults to true if a custom [storage] is provided.
  final bool useExternal;

  /// The custom storage adapter for this key. Fallbacks to [Keep.externalStorage].
  final KeepStorage? storage;

  /// The parent key, if this is a sub-key.
  KeepKey<T>? _parent;

  /// The active external storage for this key.
  @internal
  KeepStorage get externalStorage => storage ?? _keep.externalStorage;

  /// The [Keep] instance that manages this key's lifecycle and storage.
  late Keep _keep;

  @internal
  /// Internal method to bind this key to a [Keep] instance.
  // ignore: use_setters_to_change_properties
  void bind(Keep keep) => _keep = keep;

  /// The unique identifier or path of this key within the [Keep] storage.
  final String name;

  /// The name used for physical storage on disk or in the internal map.
  ///
  /// This is the hashed version of [name].
  String get storeName {
    final hashedName = KeepCodec.generateHash(name);

    if (_parent == null) {
      return hashedName;
    }

    return '${_parent!.storeName}\$$hashedName';
  }

  /// Whether this key is marked as 'removable'.
  ///
  /// Removable keys are typically used for temporary data (like caches) that
  /// can be cleared without affecting the application's core state.
  final bool removable;

  /// Manages sub-key registration and persistence.
  late final SubKeyManager<T> keys = SubKeyManager<T>(this);

  /// Creates a sub-key by appending [subKeyName] to the current [name].
  KeepKey<T> call(String subKeyName);

  /// Reads the value of this key synchronously from the storage.
  ///
  /// **Performance Warning:** Internal storage reads are fast (memory-lookup),
  /// but external storage reads involve blocking I/O. Use with caution.
  T? readSync();

  /// Reads the value of this key asynchronously from the storage.
  ///
  /// This is the preferred way to read data, as it ensures the [Keep] instance
  /// is fully initialized before the read operation begins.
  Future<T?> read();

  /// Reads the value and returns [defaultValue] if the key does not exist or an error occurs.
  Future<T> readSafe(T defaultValue) async {
    return (await read()) ?? defaultValue;
  }

  /// Synchronously reads the value and returns [defaultValue] if not found.
  ///
  /// See [readSync] for performance warnings and initialization requirements.
  T readSafeSync(T defaultValue) {
    return readSync() ?? defaultValue;
  }

  /// Writes [value] to the storage associated with this key.
  ///
  /// If [value] is `null`, the key is effectively removed from the storage.
  /// Every write operation notifies listeners through the [Stream] interface.
  @mustCallSuper
  Future<void> write(T value);

  /// Returns `true` if this key exists in the storage.
  Future<bool> get exists async {
    await _keep.ensureInitialized;

    try {
      if (useExternal) {
        return _keep.externalStorage.exists(this);
      }

      return _keep.internalStorage.exists(this);
    } on KeepException<dynamic> {
      rethrow;
    } catch (e, s) {
      final exception = toException(
        e.toString(),
        error: e,
        stackTrace: s,
      );

      _keep.onError?.call(exception);
      throw exception;
    }
  }

  /// Synchronously checks if this key currently exists in storage.
  ///
  /// **Warning:** This method may throw if called before [Keep.init].
  bool get existsSync {
    try {
      if (useExternal) {
        return _keep.externalStorage.existsSync(this);
      }

      return _keep.internalStorage.existsSync(this);
    } on KeepException<dynamic> {
      rethrow;
    } catch (e, s) {
      final exception = toException(
        e.toString(),
        error: e,
        stackTrace: s,
      );

      _keep.onError?.call(exception);
      throw exception;
    }
  }

  /// Wraps an error into a [KeepException] specific to this key.
  KeepException<T> toException(
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    return KeepException(
      message,
      key: this,
      error: error,
      stackTrace: stackTrace,
    );
  }

  /// Atomically updates the value by reading the current value and writing
  /// the result of [updateFn].
  ///
  /// This method ensures the update logic handles existing data appropriately.
  Future<void> update(T Function(T? currentValue) updateFn) async {
    try {
      final currentValue = await read();
      final newValue = updateFn(currentValue);
      await write(newValue);
    } on KeepException<T> {
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

  /// Removes this key and its associated value from both memory and disk.
  Future<void> remove() async {
    await _keep.ensureInitialized;

    try {
      if (useExternal) {
        await _keep.externalStorage.remove(this);
      } else {
        await _keep.internalStorage.remove(this);
      }

      if (_parent != null) {
        await _parent!.keys._unregister(this);
      }
    } on KeepException<dynamic> {
      rethrow;
    } catch (e, s) {
      final exception = toException(
        e.toString(),
        error: e,
        stackTrace: s,
      );

      _keep.onError?.call(exception);
      throw exception;
    }
  }

  /// A stream that emits this key whenever its value changes.
  Stream<KeepKey<T>> get stream {
    return _keep.onChange
        .where((key) => key.storeName == storeName)
        .cast<KeepKey<T>>();
  }

  @override
  String toString() {
    return 'KeepKey<$T>(name: $name, external: $useExternal, removable: $removable)';
  }
}
