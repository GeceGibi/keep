library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:encrypt/encrypt.dart' as encrypt_lib;
import 'package:flutter/material.dart';

part 'widgets.dart';
part 'vault_encrypter.dart';
part 'vault_key.dart';
part 'vault_memory.dart';
part 'vault_storage.dart';
part 'vault_key_manager.dart';
part 'vault_key_secure.dart';

/// Simple, Singleton-based Vault storage with Field-Level Encryption support.
class Vault {
  Vault({
    VaultEncrypter? encrypter,
    VaultStorage? externalStorage,
  }) : external = externalStorage ?? DefaultVaultExternalStorage(),
       encrypter = encrypter ?? DefaultVaultEncrypter(secureKey: '0' * 32);

  final VaultEncrypter encrypter;

  String _path = '/';
  String _folderName = 'vault';
  Directory get root => Directory('$_path/$_folderName');

  final StreamController<VaultKey<dynamic>> _controller =
      StreamController<VaultKey<dynamic>>.broadcast();

  Stream<VaultKey<dynamic>> get onChange => _controller.stream;

  /// User can override this to provide their own external storage
  final VaultStorage external;

  /// Core storage for memory-based vault
  final internal = _VaultInternalStorage();

  /// Key Manager
  VaultKeyManager get key => VaultKeyManager(vault: this);

  Future<void> init({String path = '/', String folderName = 'vault'}) async {
    _path = path;
    _folderName = folderName;

    await encrypter.init();

    await root.create(recursive: true);

    await Future.wait([
      internal.init(this),
      external.init(this),
    ]);
  }

  /// Key Operations
  ///
  FutureOr<bool> exists<T>(VaultKey<T> key) async {
    return key.useExternalStorage
        ? await external.exists(key)
        : internal.exists(key);
  }

  FutureOr<void> remove<T>(VaultKey<T> key) async {
    if (key.useExternalStorage) {
      return await external.remove(key);
    }

    return internal.remove(key);
  }

  Future<void> clear() async {
    internal.clear();
    await external.clear();
  }
}
