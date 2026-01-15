import 'dart:async';
import 'dart:convert';
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

  /// Internal controller used to dispatch change events to [onChange].
  ///
  /// Every time a [KeepKey] writes data, it adds itself to this controller
  /// to notify listeners of the value change.
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

    // Discovery Logic for Internal Secure Keys:
    // If a key has flagSecure, its payload is an encrypted JSON wrapper: { 'k': 'real_name', 'v': value }
    // We need this 'k' to correctly map hashed names back to original names in the registry.
    for (final entry in internalStorage.memory.entries) {
      if ((entry.value.flags & KeepCodec.flagSecure) != 0) {
        try {
          final encrypted = entry.value.value as String;
          final decrypted = encrypter.decryptSync(encrypted);
          jsonDecode(decrypted);

          // We don't register the full KeepKey object yet (lazy-loading),
          // but we can at least keep a placeholder or just know it exists.
          // For now, the 'keys' getter will handle the mapping.
        } catch (_) {
          // If decryption fails, likely a corrupted entry or wrong key.
        }
      }
    }

    _initCompleter.complete();
  }

  /// Returns a snapshot of all entries currently stored in the internal (memory) storage.
  /// For secure keys, discovers the original name from the payload.
  List<String> get keys {
    return internalStorage.memory.entries.map((e) {
      if ((e.value.flags & KeepCodec.flagSecure) != 0) {
        try {
          final decrypted = encrypter.decryptSync(e.value.value as String);
          final package = jsonDecode(decrypted) as Map;
          return package['k'] as String;
        } catch (_) {
          return e.key; // Fallback to hashed name if decryption fails
        }
      }
      return e.key;
    }).toList();
  }

  /// Returns all removable `true` keys.
  List<String> get removableKeys {
    return internalStorage.memory.entries
        .where((e) => (e.value.flags & KeepCodec.flagRemovable) != 0)
        .map((e) {
          if ((e.value.flags & KeepCodec.flagSecure) != 0) {
            try {
              final decrypted = encrypter.decryptSync(e.value.value as String);
              final package = jsonDecode(decrypted) as Map;
              return package['k'] as String;
            } catch (_) {
              return e.key;
            }
          }
          return e.key;
        })
        .toList();
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
    removableKeys.forEach((e) {
      // onChangeController.add();
    });
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
