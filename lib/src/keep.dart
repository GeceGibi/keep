import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:keep/src/encrypter/encrypter.dart';
import 'package:keep/src/key/key.dart';
import 'package:keep/src/storage/storage.dart';
import 'package:keep/src/utils/utils.dart';
import 'package:path_provider/path_provider.dart';

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
  }) : externalStorage = externalStorage ?? DefaultKeepExternalStorage(),
       encrypter = encrypter ?? SimpleKeepEncrypter(secureKey: '0' * 32);

  /// The encrypter used for [KeepKeySecure].
  @internal
  final KeepEncrypter encrypter;

  /// External storage implementation for large datasets.
  @internal
  final KeepStorage externalStorage;

  /// Callback invoked when a [KeepException] occurs.
  void Function(KeepException<dynamic> exception)? onError;

  /// Root directory path of the keep on disk.
  late String _path;

  /// Name of the folder that stores the keep files.
  late String _folderName;

  /// The root directory where keep files are stored.

  @internal
  Directory get root => Directory('$_path/$_folderName');

  @internal
  final StreamController<KeepKey<dynamic>> onChangeController =
      StreamController<KeepKey<dynamic>>.broadcast();

  /// A stream of key changes.
  Stream<KeepKey<dynamic>> get onChange => onChangeController.stream;

  /// Core storage for memory-based keep (main metadata and small values).
  @internal
  final internalStorage = KeepInternalStorage();

  /// Completer for initialization.
  final Completer<void> _initCompleter = Completer<void>();

  /// Waits for [init] to complete. Safe to call multiple times.
  @internal
  Future<void> get ensureInitialized => _initCompleter.future;

  /// Registry of all [KeepKey] created for this keep.
  /// [KeepKey] is lazy, so it's not represent all keys in the storage.
  final Map<String, KeepKey<dynamic>> _registry = {};

  /// Registers or retrieves a key from the registry.
  ///
  /// This ensures that [KeepKey] instances are singletons per name.
  @internal
  T registerKey<T extends KeepKey<dynamic>>(
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
  @internal
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
      internalStorage.init(this),
      externalStorage.init(this),
    ]);

    _initCompleter.complete();
  }

  /// Returns a snapshot of all entries currently stored in the internal (memory) storage.
  List<KeepMemoryValue> get keys {
    return List.unmodifiable(internalStorage.getEntries<KeepMemoryValue>());
  }

  /// Returns all removable `true` keys.
  List<KeepKey<KeepMemoryValue>> get removableKeys {
    return List.unmodifiable(keys.where((k) => k.isRemovable));
  }

  /// Returns all registered keys for external storage.
  Future<List<dynamic>> get keysExternal async {
    return List.unmodifiable(await externalStorage.getEntries());
  }

  /// Returns all currently registered keys that are designated for external storage.
  ///
  /// Note: This only includes keys that have been instantiated/accessed at least once.
  List<KeepKey<dynamic>> get removableKeysExternal {
    return List.unmodifiable(
      _registry.values.where((k) => k.removable && k.useExternalStorage),
    );
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
    await ensureInitialized;

    await Future.wait([
      internalStorage.clearRemovable(),
      externalStorage.clearRemovable(),
    ]);

    // Notify currently registered removable keys that their data has been cleared.
    // This updates any UI listening to these keys.
    removableKeys.forEach(onChangeController.add);
  }

  /// Deletes all data from both internal and external storage.
  ///
  /// This is a complete reset of the keep. It removes the main database file
  /// and all individual external files. Active listeners will be notified
  /// with a `null` value event.
  Future<void> clear() async {
    await externalStorage.clear();
    await internalStorage.clear();

    // Notify all keys in the registry so they can update their respective UI components.
    _registry.values.forEach(onChangeController.add);
  }
}
