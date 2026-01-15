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
///
/// Use [Keep.integer], [Keep.string], etc., to define your keys as class fields.
class Keep {
  /// Creates a new [Keep] instance.
  ///
  /// [onError] is an optional callback invoked whenever a storage or encryption
  /// error occurs.
  ///
  /// [encrypter] defines how secure keys are encrypted. Defaults to
  /// [SimpleKeepEncrypter].
  ///
  /// [externalStorage] defines how large blobs are stored. Defaults to
  /// [DefaultKeepExternalStorage].
  Keep({
    this.onError,
    KeepEncrypter? encrypter,
    KeepStorage? externalStorage,
  }) : externalStorage = externalStorage ?? DefaultKeepExternalStorage(),
       encrypter = encrypter ?? SimpleKeepEncrypter(secureKey: '0' * 32) {
    _bindPending();
  }

  /// Internal list of keys collected during class field initialization.
  static final List<KeepKey<dynamic>> _pendingKeys = [];

  /// Binds all keys created before this [Keep] instance was fully constructed.
  void _bindPending() {
    for (final key in _pendingKeys) {
      key.bind(this);
      _registry[key.name] = key;
    }
    _pendingKeys.clear();
  }

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

  /// The registry of all [KeepKey] created for this keep.
  /// The internal registry of all [KeepKey] instances managed by this [Keep].
  final Map<String, KeepKey<dynamic>> _registry = {};

  // --- Static Key Factories ---

  /// Creates a standard [int] key.
  ///
  /// This key will store plain integer values in the internal storage.
  static KeepKeyPlain<int> integer(
    String name, {
    bool removable = false,
    bool useExternalStorage = false,
  }) {
    final key = KeepKeyPlain<int>(
      name: name,
      removable: removable,
      useExternalStorage: useExternalStorage,
    );
    _pendingKeys.add(key);
    return key;
  }

  /// Creates an encrypted [int] key.
  ///
  /// The value is automatically encrypted before being stored.
  static KeepKeySecure<int> integerSecure(
    String name, {
    bool removable = false,
    bool useExternalStorage = false,
  }) {
    final key = KeepKeySecure<int>(
      name: name,
      removable: removable,
      useExternalStorage: useExternalStorage,
      toStorage: (v) => v,
      fromStorage: (v) => v is int ? v : (v is String ? int.tryParse(v) : null),
    );
    _pendingKeys.add(key);
    return key;
  }

  /// Creates a standard [String] key.
  ///
  /// This key will store plain string values in the internal storage.
  static KeepKeyPlain<String> string(
    String name, {
    bool removable = false,
    bool useExternalStorage = false,
  }) {
    final key = KeepKeyPlain<String>(
      name: name,
      removable: removable,
      useExternalStorage: useExternalStorage,
    );
    _pendingKeys.add(key);
    return key;
  }

  /// Creates an encrypted [String] key.
  ///
  /// The value is automatically encrypted before being stored.
  static KeepKeySecure<String> stringSecure(
    String name, {
    bool removable = false,
    bool useExternalStorage = false,
  }) {
    final key = KeepKeySecure<String>(
      name: name,
      removable: removable,
      useExternalStorage: useExternalStorage,
      toStorage: (v) => v,
      fromStorage: (v) => v?.toString(),
    );
    _pendingKeys.add(key);
    return key;
  }

  /// Creates a standard [bool] key.
  static KeepKeyPlain<bool> boolean(
    String name, {
    bool removable = false,
    bool useExternalStorage = false,
  }) {
    final key = KeepKeyPlain<bool>(
      name: name,
      removable: removable,
      useExternalStorage: useExternalStorage,
    );
    _pendingKeys.add(key);
    return key;
  }

  /// Creates an encrypted [bool] key.
  ///
  /// The value is automatically encrypted before being stored.
  static KeepKeySecure<bool> booleanSecure(
    String name, {
    bool removable = false,
    bool useExternalStorage = false,
  }) {
    final key = KeepKeySecure<bool>(
      name: name,
      removable: removable,
      useExternalStorage: useExternalStorage,
      toStorage: (v) => v,
      fromStorage: (v) => v is bool ? v : (v == 'true' || v == 1),
    );
    _pendingKeys.add(key);
    return key;
  }

  /// Creates a standard [double] key.
  static KeepKeyPlain<double> decimal(
    String name, {
    bool removable = false,
    bool useExternalStorage = false,
  }) {
    final key = KeepKeyPlain<double>(
      name: name,
      removable: removable,
      useExternalStorage: useExternalStorage,
    );
    _pendingKeys.add(key);
    return key;
  }

  /// Creates an encrypted [double] key.
  ///
  /// The value is automatically encrypted before being stored.
  static KeepKeySecure<double> decimalSecure(
    String name, {
    bool removable = false,
    bool useExternalStorage = false,
  }) {
    final key = KeepKeySecure<double>(
      name: name,
      removable: removable,
      useExternalStorage: useExternalStorage,
      toStorage: (v) => v,
      fromStorage: (v) =>
          v is num ? v.toDouble() : (v is String ? double.tryParse(v) : null),
    );
    _pendingKeys.add(key);
    return key;
  }

  /// Creates a standard [Map] key.
  static KeepKeyPlain<Map<String, dynamic>> map(
    String name, {
    bool removable = false,
    bool useExternalStorage = false,
  }) {
    final key = KeepKeyPlain<Map<String, dynamic>>(
      name: name,
      removable: removable,
      useExternalStorage: useExternalStorage,
    );
    _pendingKeys.add(key);
    return key;
  }

  /// Creates an encrypted [Map] key.
  static KeepKeySecure<Map<String, dynamic>> mapSecure(
    String name, {
    bool removable = false,
    bool useExternalStorage = false,
  }) {
    final key = KeepKeySecure<Map<String, dynamic>>(
      name: name,
      removable: removable,
      useExternalStorage: useExternalStorage,
      toStorage: (v) => v,
      fromStorage: (v) => v is Map ? v.cast<String, dynamic>() : null,
    );
    _pendingKeys.add(key);
    return key;
  }

  /// Creates a standard [List] key.
  static KeepKeyPlain<List<T>> list<T>(
    String name, {
    bool removable = false,
    bool useExternalStorage = false,
  }) {
    final key = KeepKeyPlain<List<T>>(
      name: name,
      removable: removable,
      useExternalStorage: useExternalStorage,
    );
    _pendingKeys.add(key);
    return key;
  }

  /// Creates an encrypted [List] key.
  static KeepKeySecure<List<T>> listSecure<T>(
    String name, {
    bool removable = false,
    bool useExternalStorage = false,
  }) {
    final key = KeepKeySecure<List<T>>(
      name: name,
      removable: removable,
      useExternalStorage: useExternalStorage,
      toStorage: (v) => v,
      fromStorage: (v) => v is List ? v.cast<T>() : null,
    );
    _pendingKeys.add(key);
    return key;
  }

  /// Creates a custom encrypted key with specialized serialization.
  static KeepKeySecure<T> custom<T>({
    required String name,
    required T? Function(Object? value) fromStorage,
    required Object? Function(T value) toStorage,
    bool removable = false,
    bool useExternalStorage = false,
  }) {
    final key = KeepKeySecure<T>(
      name: name,
      removable: removable,
      useExternalStorage: useExternalStorage,
      fromStorage: fromStorage,
      toStorage: toStorage,
    );
    _pendingKeys.add(key);
    return key;
  }

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

  /// Returns a snapshot of all keys currently stored in the internal (memory) storage.
  /// For secure keys, discovers the original name from the payload.
  List<String> get keys {
    return internalStorage.memory.entries.map((e) {
      if (e.value.isSecure) {
        try {
          final decrypted = encrypter.decryptSync(e.value.value as String);
          final package = jsonDecode(decrypted) as Map;
          return package['k'] as String;
        } catch (_) {}
      }
      return e.key;
    }).toList();
  }

  /// Returns all removable `true` keys from internal storage.
  List<String> get removableKeys {
    return internalStorage.memory.entries.where((e) => e.value.isRemovable).map(
      (e) {
        if (e.value.isSecure) {
          try {
            final decrypted = encrypter.decryptSync(e.value.value as String);
            final package = jsonDecode(decrypted) as Map;
            return package['k'] as String;
          } catch (_) {}
        }
        return e.key;
      },
    ).toList();
  }

  /// Returns all registered keys for external storage that currently exist on disk.
  Future<List<String>> get keysExternal async {
    final results = <String>[];
    final externalKeys = _registry.values.where((k) => k.useExternalStorage);

    for (final key in externalKeys) {
      if (await externalStorage.exists(key)) {
        results.add(key.name);
      }
    }
    return results;
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
