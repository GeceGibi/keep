import 'dart:async';
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

  /// Current binary format version of the keep storage.
  @internal
  @protected
  static const int version = 1;

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
  @protected
  final KeepEncrypter encrypter;

  /// External storage implementation for large datasets.
  @internal
  @protected
  final KeepStorage externalStorage;

  /// Callback invoked when a [KeepException] occurs.
  void Function(KeepException<dynamic> exception)? onError;

  /// Root directory path of the keep on disk.
  late String _path;

  /// Name of the folder that stores the keep files.
  late String _folderName;

  /// The root directory where keep files are stored.
  @internal
  @protected
  Directory get root => Directory('$_path/$_folderName');

  /// Internal controller used to dispatch change events to [onChange].
  ///
  /// Every time a [KeepKey] writes data, it adds itself to this controller
  /// to notify listeners of the value change.
  @internal
  @protected
  final StreamController<KeepKey<dynamic>> onChangeController =
      StreamController<KeepKey<dynamic>>.broadcast();

  /// A stream of key changes.
  Stream<KeepKey<dynamic>> get onChange => onChangeController.stream;

  /// Core storage for memory-based keep (main metadata and small values).
  @internal
  @protected
  final internalStorage = KeepInternalStorage();

  /// Completer for initialization.
  final Completer<void> _initCompleter = Completer<void>();

  /// Waits for [init] to complete. Safe to call multiple times.
  @internal
  @protected
  Future<void> get ensureInitialized => _initCompleter.future;

  /// The registry of all [KeepKey] created for this keep.
  /// The internal registry of all [KeepKey] instances managed by this [Keep].
  final Map<String, KeepKey<dynamic>> _registry = {};

  // --- Static Key Factories ---

  /// Creates a standard [int] key.
  ///
  /// This key will store plain integer values in the internal storage.
  static KeepKeyPlain<int> kInt(
    String name, {
    bool removable = false,
    bool useExternal = false,
    KeepStorage? storage,
    int? Function(Object? value)? fromStorage,
    Object? Function(int value)? toStorage,
  }) {
    final key = KeepKeyPlain<int>(
      name: name,
      removable: removable,
      useExternal: useExternal,
      storage: storage,
      fromStorage: fromStorage,
      toStorage: toStorage,
    );
    _pendingKeys.add(key);
    return key;
  }

  /// Creates an encrypted [int] key.
  ///
  /// The value is automatically encrypted before being stored.
  static KeepKeySecure<int> kIntSecure(
    String name, {
    bool removable = false,
    bool useExternal = false,
    KeepStorage? storage,
  }) {
    final key = KeepKeySecure<int>(
      name: name,
      removable: removable,
      useExternal: useExternal,
      storage: storage,
      toStorage: (v) => v,
      fromStorage: (v) => v is int ? v : (v is String ? int.tryParse(v) : null),
    );
    _pendingKeys.add(key);
    return key;
  }

  /// Creates a standard [String] key.
  ///
  /// This key will store plain string values in the internal storage.
  static KeepKeyPlain<String> kString(
    String name, {
    bool removable = false,
    bool useExternal = false,
    KeepStorage? storage,
    String? Function(Object? value)? fromStorage,
    Object? Function(String value)? toStorage,
  }) {
    final key = KeepKeyPlain<String>(
      name: name,
      removable: removable,
      useExternal: useExternal,
      storage: storage,
      fromStorage: fromStorage,
      toStorage: toStorage,
    );
    _pendingKeys.add(key);
    return key;
  }

  /// Creates an encrypted [String] key.
  ///
  /// The value is automatically encrypted before being stored.
  static KeepKeySecure<String> kStringSecure(
    String name, {
    bool removable = false,
    bool useExternal = false,
    KeepStorage? storage,
  }) {
    final key = KeepKeySecure<String>(
      name: name,
      removable: removable,
      useExternal: useExternal,
      storage: storage,
      toStorage: (v) => v,
      fromStorage: (v) => v?.toString(),
    );
    _pendingKeys.add(key);
    return key;
  }

  /// Creates a standard [bool] key.
  static KeepKeyPlain<bool> kBool(
    String name, {
    bool removable = false,
    bool useExternal = false,
    KeepStorage? storage,
    bool? Function(Object? value)? fromStorage,
    Object? Function(bool value)? toStorage,
  }) {
    final key = KeepKeyPlain<bool>(
      name: name,
      removable: removable,
      useExternal: useExternal,
      storage: storage,
      fromStorage: fromStorage,
      toStorage: toStorage,
    );
    _pendingKeys.add(key);
    return key;
  }

  /// Creates an encrypted [bool] key.
  ///
  /// The value is automatically encrypted before being stored.
  static KeepKeySecure<bool> kBoolSecure(
    String name, {
    bool removable = false,
    bool useExternal = false,
    KeepStorage? storage,
  }) {
    final key = KeepKeySecure<bool>(
      name: name,
      removable: removable,
      useExternal: useExternal,
      storage: storage,
      toStorage: (v) => v,
      fromStorage: (v) => v is bool ? v : (v == 'true' || v == 1),
    );
    _pendingKeys.add(key);
    return key;
  }

  /// Creates a standard [double] key.
  static KeepKeyPlain<double> kDouble(
    String name, {
    bool removable = false,
    bool useExternal = false,
    KeepStorage? storage,
    double? Function(Object? value)? fromStorage,
    Object? Function(double value)? toStorage,
  }) {
    final key = KeepKeyPlain<double>(
      name: name,
      removable: removable,
      useExternal: useExternal,
      storage: storage,
      fromStorage: fromStorage,
      toStorage: toStorage,
    );
    _pendingKeys.add(key);
    return key;
  }

  /// Creates an encrypted [double] key.
  ///
  /// The value is automatically encrypted before being stored.
  static KeepKeySecure<double> kDoubleSecure(
    String name, {
    bool removable = false,
    bool useExternal = false,
    KeepStorage? storage,
  }) {
    final key = KeepKeySecure<double>(
      name: name,
      removable: removable,
      useExternal: useExternal,
      storage: storage,
      toStorage: (v) => v,
      fromStorage: (v) =>
          v is num ? v.toDouble() : (v is String ? double.tryParse(v) : null),
    );
    _pendingKeys.add(key);
    return key;
  }

  /// Creates a standard [Map] key.
  static KeepKeyPlain<Map<String, dynamic>> kMap(
    String name, {
    bool removable = false,
    bool useExternal = false,
    KeepStorage? storage,
    Map<String, dynamic>? Function(Object? value)? fromStorage,
    Object? Function(Map<String, dynamic> value)? toStorage,
  }) {
    final key = KeepKeyPlain<Map<String, dynamic>>(
      name: name,
      removable: removable,
      useExternal: useExternal,
      storage: storage,
      fromStorage:
          fromStorage ?? (v) => v is Map ? v.cast<String, dynamic>() : null,
      toStorage: toStorage,
    );

    _pendingKeys.add(key);
    return key;
  }

  /// Creates an encrypted [Map] key.
  static KeepKeySecure<Map<String, dynamic>> kMapSecure(
    String name, {
    bool removable = false,
    bool useExternal = false,
    KeepStorage? storage,
  }) {
    final key = KeepKeySecure<Map<String, dynamic>>(
      name: name,
      removable: removable,
      useExternal: useExternal,
      storage: storage,
      toStorage: (v) => v,
      fromStorage: (v) => v is Map ? v.cast<String, dynamic>() : null,
    );
    _pendingKeys.add(key);
    return key;
  }

  /// Creates a standard [List] key.
  static KeepKeyPlain<List<T>> kList<T>(
    String name, {
    bool removable = false,
    bool useExternal = false,
    KeepStorage? storage,
    List<T>? Function(Object? value)? fromStorage,
    Object? Function(List<T> value)? toStorage,
  }) {
    final key = KeepKeyPlain<List<T>>(
      name: name,
      removable: removable,
      useExternal: useExternal,
      storage: storage,
      fromStorage: fromStorage ?? (v) => v is List ? v.cast<T>() : null,
      toStorage: toStorage,
    );

    _pendingKeys.add(key);
    return key;
  }

  /// Creates an encrypted [List] key.
  static KeepKeySecure<List<T>> kListSecure<T>(
    String name, {
    bool removable = false,
    bool useExternal = false,
    KeepStorage? storage,
  }) {
    final key = KeepKeySecure<List<T>>(
      name: name,
      removable: removable,
      useExternal: useExternal,
      storage: storage,
      toStorage: (v) => v,
      fromStorage: (v) => v is List ? v.cast<T>() : null,
    );
    _pendingKeys.add(key);
    return key;
  }

  /// Creates a custom plain key with specialized serialization.
  static KeepKeyPlain<T> custom<T>({
    required String name,
    required T? Function(Object? value) fromStorage,
    required Object? Function(T value) toStorage,
    bool removable = false,
    bool useExternal = false,
    KeepStorage? storage,
  }) {
    final key = KeepKeyPlain<T>(
      name: name,
      removable: removable,
      useExternal: useExternal,
      storage: storage,
      fromStorage: fromStorage,
      toStorage: toStorage,
    );
    _pendingKeys.add(key);
    return key;
  }

  /// Creates a custom encrypted key with specialized serialization.
  static KeepKeySecure<T> customSecure<T>({
    required String name,
    required T? Function(Object? value) fromStorage,
    required Object? Function(T value) toStorage,
    bool removable = false,
    bool useExternal = false,
    KeepStorage? storage,
  }) {
    final key = KeepKeySecure<T>(
      name: name,
      removable: removable,
      useExternal: useExternal,
      storage: storage,
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
  @mustCallSuper
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

  /// Returns a snapshot of all keys currently stored in the internal (memory) storage.
  List<KeepKey<dynamic>> get keys {
    return List.unmodifiable(_registry.entries.map((k) => k.value).toList());
  }

  /// Returns all removable `true` keys from internal storage.
  List<KeepKey<dynamic>> get removableKeys {
    return List.unmodifiable(
      _registry.entries
          .where((k) => k.value.removable)
          .map((k) => k.value)
          .toList(),
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
