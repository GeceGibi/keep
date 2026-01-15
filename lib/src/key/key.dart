import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:keep/src/keep.dart';
import 'package:keep/src/utils/utils.dart';

part 'key_manager.dart';
part 'key_plain.dart';
part 'key_secure.dart';

/// Abstract base class for all typed keys in [Keep].
///
/// A [KeepKey] acts as a handle to a specific entry in storage. It provides
/// both synchronous and asynchronous methods for reading and writing data,
/// as well as a [Stream] interface to listen for value changes.
///
/// Implementations like [KeepKeyPlain] and [KeepKeySecure] define how the
/// data is handled (e.g., plain JSON or encrypted).
abstract class KeepKey<T> extends Stream<KeepKey<T>> {
  /// Creates a [KeepKey].
  ///
  /// - [name]: A unique identifier for the key. Often used as a filename or map key.
  /// - [keep]: The [Keep] instance managing this key.
  /// - [removable]: If `true`, the entry can be deleted during mass cleanup operations.
  /// - [useExternalStorage]: If `true`, the value is stored in a separate file instead of the main database.
  KeepKey({
    required this.name,
    required this.keep,
    this.removable = false,
    this.useExternalStorage = false,
  });

  /// The [Keep] instance that manages this key's lifecycle and storage.
  final Keep keep;

  /// The unique identifier or path of this key within the [Keep] storage.
  final String name;

  /// Whether this key is marked as 'removable'.
  ///
  /// Removable keys are typically used for temporary data (like caches) that
  /// can be cleared without affecting the application's core state.
  final bool removable;

  /// Whether this key's value is stored in its own dedicated file.
  ///
  /// Use `external` storage for large blobs of data (like images or large JSON)
  /// to keep the main registry file small and fast.
  final bool useExternalStorage;

  /// Creates a sub-key by appending [subKeyName] to the current [name].
  KeepKey<T> call(Object? subKeyName);

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
  Future<void> write(T value);

  /// Returns `true` if this key exists in the storage.
  Future<bool> get exists async {
    await keep.ensureInitialized;

    try {
      if (useExternalStorage) {
        return keep.externalStorage.exists(this);
      }

      return keep.internalStorage.exists(this);
    } catch (e, s) {
      final exception = toException(
        e.toString(),
        error: e,
        stackTrace: s,
      );

      keep.onError?.call(exception);

      throw exception;
    }
  }

  /// Synchronously checks if this key currently exists in storage.
  ///
  /// **Warning:** This method may throw if called before [Keep.init].
  bool get existsSync {
    try {
      if (useExternalStorage) {
        return keep.externalStorage.existsSync(this);
      }

      return keep.internalStorage.existsSync(this);
    } catch (e, s) {
      final exception = toException(
        e.toString(),
        error: e,
        stackTrace: s,
      );

      keep.onError?.call(exception);

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
    } on KeepException<T> catch (e) {
      keep.onError?.call(e);
      rethrow;
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

  /// Removes this key and its associated value from both memory and disk.
  Future<void> remove() async {
    await keep.ensureInitialized;

    try {
      if (useExternalStorage) {
        await keep.externalStorage.remove(this);
      } else {
        await keep.internalStorage.remove(this);
      }
    } catch (e, s) {
      final exception = toException(
        e.toString(),
        error: e,
        stackTrace: s,
      );

      keep.onError?.call(exception);

      throw exception;
    }
  }

  @override
  StreamSubscription<KeepKey<T>> listen(
    void Function(KeepKey<T> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return keep.onChange
        .where((key) => key.name == name)
        .cast<KeepKey<T>>()
        .listen(
          onData,
          onError: onError,
          onDone: onDone,
          cancelOnError: cancelOnError,
        );
  }
}
