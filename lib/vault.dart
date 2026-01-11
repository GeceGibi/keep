library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:flutter/foundation.dart';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

part 'widgets.dart';
part 'encrypter.dart';
part 'encrypter_simple.dart';
part 'key.dart';
part 'storage_internal.dart';
part 'storage_external.dart';
part 'storage.dart';
part 'key_manager.dart';
part 'key_secure.dart';
part 'exception.dart';

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
  }) : _external = externalStorage ?? DefaultVaultExternalStorage(),
       encrypter = encrypter ?? SimpleVaultEncrypter(secureKey: '0' * 32);

  /// The encrypter used for [VaultKeySecure].
  @protected
  final VaultEncrypter encrypter;

  /// External storage implementation for large datasets.
  final VaultStorage _external;

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
  final _internal = _VaultInternalStorage();

  /// Completer for initialization.
  final Completer<void> _initCompleter = Completer<void>();

  /// Waits for [init] to complete. Safe to call multiple times.
  Future<void> get _ensureInitialized => _initCompleter.future;

  /// Registry of all keys created for this vault.
  final List<VaultKey<dynamic>> _keys = [];

  /// Returns all registered keys.
  List<VaultKey<dynamic>> get keys => List.unmodifiable(_keys);

  /// Returns all removable `true` keys.
  List<VaultKey<dynamic>> get removableKeys {
    return List.unmodifiable(_keys.where((k) => k.removable));
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
      _internal.init(this),
      _external.init(this),
    ]);

    _initCompleter.complete();
  }

  /// Removes all keys marked as `removable: true`.
  Future<void> clearRemovable() async {
    await Future.wait(
      removableKeys.map((key) => key.remove()),
    );

    // Notify all removable keys
    removableKeys.forEach(_controller.add);
  }

  /// Clears all data from both internal and external storage.
  Future<void> clear() async {
    await _external.clear();
    _internal.clear();

    // Notify all keys
    _keys.forEach(_controller.add);
  }
}
