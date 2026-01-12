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
part 'storage.dart';
part 'storage_external.dart';
part 'storage_internal.dart';
part 'codec.dart';
part 'entry.dart';
part 'widgets.dart';

/// Simple, Singleton-based Vault storage with Field-Level Encryption support.
class Vault {
  /// Creates a new [Vault] instance.
  ///
  /// [encrypter] is used for secure keys. Defaults to [SimpleVaultEncrypter].
  /// [externalStorage] is used for large data. Defaults to [DefaultVaultExternalStorage].
  Vault({
    this.onError,
    VaultEncrypter? encrypter,
    VaultStorage? externalStorage,
  }) : external = externalStorage ?? DefaultVaultExternalStorage(),
       encrypter = encrypter ?? SimpleVaultEncrypter(secureKey: '0' * 32);

  /// The encrypter used for [VaultKeySecure].
  @protected
  final VaultEncrypter encrypter;

  /// External storage implementation for large datasets.
  final VaultStorage external;

  /// Callback invoked when a [VaultException] occurs.
  void Function(VaultException<dynamic> exception)? onError;

  /// Root directory path of the vault on disk.
  late String _path;

  /// Name of the folder that stores the vault files.
  late String _folderName;

  /// The root directory where vault files are stored.
  @protected
  Directory get root => Directory('$_path/$_folderName');

  final StreamController<VaultKey<dynamic>> _controller =
      StreamController<VaultKey<dynamic>>.broadcast();

  /// A stream of key changes.
  Stream<VaultKey<dynamic>> get onChange => _controller.stream;

  /// Core storage for memory-based vault (main metadata and small values).
  final internal = _VaultInternalStorage();

  /// Completer for initialization.
  final Completer<void> _initCompleter = Completer<void>();

  /// Waits for [init] to complete. Safe to call multiple times.
  Future<void> get _ensureInitialized => _initCompleter.future;

  /// Registry of all keys created for this vault.
  final Map<String, VaultKey<dynamic>> _registry = {};

  /// Returns all registered keys.
  List<VaultKey<dynamic>> get keys => List.unmodifiable(_registry.values);

  /// Registers or retrieves a key from the registry.
  ///
  /// This ensures that [VaultKey] instances are singletons per name.
  T _registerKey<T extends VaultKey<dynamic>>(
    String name,
    T Function() creator,
  ) {
    if (_registry.containsKey(name)) {
      final existing = _registry[name];
      if (existing is T) {
        return existing;
      }
      throw VaultException<T>(
        'Key "$name" already exists with type ${existing.runtimeType}, '
        'but requested $T.',
      );
    }

    final newKey = creator();
    _registry[name] = newKey;
    return newKey;
  }

  /// Returns all removable `true` keys.
  List<VaultKey<dynamic>> get removableKeys {
    return List.unmodifiable(_registry.values.where((k) => k.removable));
  }

  /// Returns a [VaultKeyManager] to create typed storage keys.
  ///
  /// Use this inside subclasses to define key fields.
  @protected
  VaultKeyManager get key => VaultKeyManager(vault: this);

  /// Initializes the vault by creating directories and starting storage adapters.
  ///
  /// [path] specifies the base directory. Defaults to app support directory.
  /// [folderName] is the name of the folder created inside [path].
  Future<void> init({String? path, String folderName = 'vault'}) async {
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

  /// Removes all keys marked as `removable: true` from the vault.
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
