library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

part 'encrypter.dart';
part 'encrypter_simple.dart';
part 'exception.dart';
part 'key.dart';
part 'key_manager.dart';
part 'key_secure.dart';
part 'key_plain.dart';
part 'storage.dart';
part 'storage_external.dart';
part 'storage_internal.dart';
part 'codec.dart';
part 'entry.dart';
part 'widgets.dart';

/// Simple, Singleton-based Keep storage with Field-Level Encryption support.
class Keep {
  /// Creates a new [Keep] instance.
  ///
  /// [encrypter] is used for secure keys. Defaults to [SimpleKeepEncrypter].
  /// [externalStorage] is used for large data. Defaults to [DefaultKeepExternalStorage].
  Keep({
    this.onError,
    KeepEncrypter? encrypter,
    KeepStorage? externalStorage,
  }) : external = externalStorage ?? DefaultKeepExternalStorage(),
       encrypter = encrypter ?? SimpleKeepEncrypter(secureKey: '0' * 32);

  /// The encrypter used for [KeepKeySecure].
  @protected
  final KeepEncrypter encrypter;

  /// External storage implementation for large datasets.
  final KeepStorage external;

  /// Callback invoked when a [KeepException] occurs.
  void Function(KeepException<dynamic> exception)? onError;

  /// Root directory path of the keep on disk.
  late String _path;

  /// Name of the folder that stores the keep files.
  late String _folderName;

  /// The root directory where keep files are stored.
  @protected
  Directory get root => Directory('$_path/$_folderName');

  final StreamController<KeepKey<dynamic>> _controller =
      StreamController<KeepKey<dynamic>>.broadcast();

  /// A stream of key changes.
  Stream<KeepKey<dynamic>> get onChange => _controller.stream;

  /// Core storage for memory-based keep (main metadata and small values).
  final internal = _KeepInternalStorage();

  /// Completer for initialization.
  final Completer<void> _initCompleter = Completer<void>();

  /// Waits for [init] to complete. Safe to call multiple times.
  Future<void> get _ensureInitialized => _initCompleter.future;

  /// Registry of all [KeepKey] created for this keep.
  /// [KeepKey] is lazy, so it's not represent all keys in the storage.
  final Map<String, KeepKey<dynamic>> _registry = {};

  /// Registers or retrieves a key from the registry.
  ///
  /// This ensures that [KeepKey] instances are singletons per name.
  T _registerKey<T extends KeepKey<dynamic>>(
    String name,
    T Function() creator,
  ) {
    if (_registry.containsKey(name)) {
      final existing = _registry[name];
      if (existing is T) {
        return existing;
      }
      throw KeepException<T>(
        'Key "$name" already exists with type ${existing.runtimeType}, '
        'but requested $T.',
      );
    }

    final newKey = creator();
    _registry[name] = newKey;
    return newKey;
  }

  /// Returns a [KeepKeyManager] to create typed storage keys.
  ///
  /// Use this inside subclasses to define key fields.
  @protected
  KeepKeyManager get keep => KeepKeyManager(keep: this);

  /// Initializes the keep by creating directories and starting storage adapters.
  ///
  /// [path] specifies the base directory. Defaults to app support directory.
  /// [folderName] is the name of the folder created inside [path].
  Future<void> init({String? path, String folderName = 'keep'}) async {
    _path = path ?? (await getApplicationSupportDirectory()).path;
    _folderName = folderName;

    await encrypter.init();

    await root.create(recursive: true);

    await Future.wait([
      internal.init(this),
      external.init(this),
    ]);

    _initCompleter.complete();
  }

  /// Returns all registered keys for not external storage.
  List<KeepMemoryValue> get keys {
    return List.unmodifiable(internal.getEntries<KeepMemoryValue>());
  }

  /// Returns all removable `true` keys.
  List<KeepKey<KeepMemoryValue>> get removableKeys {
    return List.unmodifiable(keys.where((k) => k.isRemovable));
  }

  /// Returns all registered keys for external storage.
  Future<List<dynamic>> get keysExternal async {
    return List.unmodifiable(await external.getEntries());
  }

  /// Returns all removable `true` keys for external storage.
  List<KeepKey<dynamic>> get removableKeysExternal {
    return List.unmodifiable(_registry.values.where((k) => k.removable));
  }

  /// Removes all keys marked as `removable: true` from the keep.
  ///
  /// This operation performs a **storage-level cleanup** by scanning both internal memory
  /// and external files for entries with the **Removable Flag** set.
  ///
  /// Unlike manually iterating over keys, this method:
  /// 1. **Handles Lazy Keys:** Deletes removable data even if the key objects haven't been accessed/initialized.
  /// 2. **Is Efficient:** Uses binary headers/flags to identify targets without full data parsing.
  /// 3. **Syncs State:** Updates internal memory state and notifies active listeners.
  Future<void> clearRemovable() async {
    await _ensureInitialized;

    await Future.wait([
      internal.clearRemovable(),
      external.clearRemovable(),
    ]);

    // Notify currently registered removable keys that their data has been cleared.
    // This updates any UI listening to these keys.
    removableKeys.forEach(_controller.add);
  }

  /// Clears all data from both internal and external storage.
  Future<void> clear() async {
    await external.clear();
    internal.clear();

    // Notify all keys
    _registry.values.forEach(_controller.add);
  }
}
