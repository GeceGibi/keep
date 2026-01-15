import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:keep/src/keep.dart';
import 'package:keep/src/key/key.dart';
import 'package:keep/src/utils/utils.dart';

part 'storage_internal.dart';
part 'storage_external.dart';
part 'storage_internal_entry.dart';

/// Abstract base class for solid storage implementations (Files, Cloud, etc.).
abstract class KeepStorage {
  /// Creates a new instance of [KeepStorage].
  KeepStorage();

  /// Initializes the storage adapter with the main [keep] instance.
  Future<void> init(Keep keep);

  /// Gets the raw storage object (e.g., [File]) for a given [key].
  F getEntry<F>(KeepKey<dynamic> key);

  /// Synchronously reads content from storage.
  ///
  /// This bypasses the async queue for external storage and may block the UI thread.
  V? readSync<V>(KeepKey<dynamic> key);

  /// Reads content from storage for the specified [key].
  FutureOr<V?> read<V>(KeepKey<dynamic> key);

  /// Writes [value] to storage for the specified [key].
  FutureOr<void> write(KeepKey<dynamic> key, Object? value);

  /// Removes the entry associated with [key].
  FutureOr<void> remove(KeepKey<dynamic> key);

  /// Checks if an entry exists for [key].
  FutureOr<bool> exists(KeepKey<dynamic> key);

  /// Synchronously checks if an entry exists for [key].
  bool existsSync(KeepKey<dynamic> key);

  /// Returns a list of all raw entries in this storage.
  FutureOr<List<E>> getEntries<E>();

  /// Scans the storage and removes all entries marked with the **Removable** flag.
  ///
  /// Implementations should respect the binary metadata flag (Bit 0) ensuring
  /// efficient cleanup of temporary data without full content parsing.
  Future<void> clearRemovable();

  /// Deletes all entries in this storage instance.
  FutureOr<void> clear();
}
