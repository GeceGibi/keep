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
/// Use [Keep.kInt], [Keep.kString], etc., to define your keys as class fields.
class Keep with KeepCodecUtils {
  /// Creates a new [Keep] instance.
  ///
  /// [id] is a unique identifier for this storage. It is used to derive
  /// the directory name where data is stored.
  ///
  /// [onError] is an optional callback invoked whenever a storage or encryption
  /// error occurs.
  ///
  /// [encrypter] defines how secure keys are encrypted. Defaults to
  /// [SimpleKeepEncrypter].
  ///
  /// [externalStorage] defines how large blobs are stored. Defaults to
  /// [DefaultKeepExternalStorage].
  Keep(
    this.id, {
    this.onError,
    KeepEncrypter? encrypter,
    KeepStorage? externalStorage,
  }) : externalStorage = externalStorage ?? DefaultKeepExternalStorage(),
       _usingDefaultEncrypter = encrypter == null,
       encrypter = encrypter ?? SimpleKeepEncrypter(secureKey: '0' * 32) {
    _bindPending();
  }

  /// Whether the encrypter was created by [Keep] itself (i.e. the user did
  /// not provide one). When `true`, [init] emits a debug-mode warning if any
  /// secure keys are registered, because the fallback [SimpleKeepEncrypter]
  /// is keyed with a publicly known constant.
  final bool _usingDefaultEncrypter;

  /// Name of the folder that stores the keep files.
  final String id;

  /// Hashed name of the folder that stores the keep files.
  String get _hashedId => hash('keep-it-$id');

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

  /// The root directory where keep files are stored.
  @internal
  @protected
  Directory get root => Directory('$_path/$_hashedId');

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

  /// Helper to register a key to the pending list.
  static T _register<T extends KeepKey<dynamic>>(T key) {
    _pendingKeys.add(key);
    return key;
  }

  // --- Static Key Factories ---

  /// Creates a standard [int] key.
  static KeepKeyPlain<int> kInt(
    String name, {
    bool removable = false,
    bool useExternal = false,
    KeepStorage? storage,
    int? Function(Object? value)? fromStorage,
    Object? Function(int value)? toStorage,
  }) {
    return _register(
      KeepKeyPlain<int>(
        name: name,
        removable: removable,
        useExternal: useExternal,
        storage: storage,
        fromStorage: fromStorage,
        toStorage: toStorage,
      ),
    );
  }

  /// Creates an encrypted [int] key.
  static KeepKeySecure<int> kIntSecure(
    String name, {
    bool removable = false,
    bool useExternal = false,
    KeepStorage? storage,
    int? Function(Object? value)? fromStorage,
    Object? Function(int value)? toStorage,
  }) {
    return _register(
      KeepKeySecure<int>(
        name: name,
        removable: removable,
        useExternal: useExternal,
        storage: storage,
        toStorage: toStorage ?? (v) => v,
        fromStorage: (v) {
          if (fromStorage != null) {
            return fromStorage(v);
          }
          if (v is int) return v;
          if (v is String) return int.tryParse(v);
          return null;
        },
      ),
    );
  }

  /// Creates a standard [String] key.
  static KeepKeyPlain<String> kString(
    String name, {
    bool removable = false,
    bool useExternal = false,
    KeepStorage? storage,
    String? Function(Object? value)? fromStorage,
    Object? Function(String value)? toStorage,
  }) {
    return _register(
      KeepKeyPlain<String>(
        name: name,
        removable: removable,
        useExternal: useExternal,
        storage: storage,
        fromStorage: fromStorage,
        toStorage: toStorage,
      ),
    );
  }

  /// Creates an encrypted [String] key.
  static KeepKeySecure<String> kStringSecure(
    String name, {
    bool removable = false,
    bool useExternal = false,
    KeepStorage? storage,
    String? Function(Object? value)? fromStorage,
    Object? Function(String value)? toStorage,
  }) {
    return _register(
      KeepKeySecure<String>(
        name: name,
        removable: removable,
        useExternal: useExternal,
        storage: storage,
        toStorage: toStorage ?? (v) => v,
        fromStorage: (v) {
          if (fromStorage != null) {
            return fromStorage(v);
          }
          return v?.toString();
        },
      ),
    );
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
    return _register(
      KeepKeyPlain<bool>(
        name: name,
        removable: removable,
        useExternal: useExternal,
        storage: storage,
        fromStorage: fromStorage,
        toStorage: toStorage,
      ),
    );
  }

  /// Creates an encrypted [bool] key.
  static KeepKeySecure<bool> kBoolSecure(
    String name, {
    bool removable = false,
    bool useExternal = false,
    KeepStorage? storage,
    bool? Function(Object? value)? fromStorage,
    Object? Function(bool value)? toStorage,
  }) {
    return _register(
      KeepKeySecure<bool>(
        name: name,
        removable: removable,
        useExternal: useExternal,
        storage: storage,
        toStorage: toStorage ?? (v) => v,
        fromStorage: (v) {
          if (fromStorage != null) {
            return fromStorage(v);
          }
          if (v is bool) return v;
          if (v == 'true' || v == 1) return true;
          return false;
        },
      ),
    );
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
    return _register(
      KeepKeyPlain<double>(
        name: name,
        removable: removable,
        useExternal: useExternal,
        storage: storage,
        fromStorage: fromStorage,
        toStorage: toStorage,
      ),
    );
  }

  /// Creates an encrypted [double] key.
  static KeepKeySecure<double> kDoubleSecure(
    String name, {
    bool removable = false,
    bool useExternal = false,
    KeepStorage? storage,
    double? Function(Object? value)? fromStorage,
    Object? Function(double value)? toStorage,
  }) {
    return _register(
      KeepKeySecure<double>(
        name: name,
        removable: removable,
        useExternal: useExternal,
        storage: storage,
        toStorage: toStorage ?? (v) => v,
        fromStorage: (v) {
          if (fromStorage != null) {
            return fromStorage(v);
          }
          if (v is num) return v.toDouble();
          if (v is String) return double.tryParse(v);
          return null;
        },
      ),
    );
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
    return _register(
      KeepKeyPlain<Map<String, dynamic>>(
        name: name,
        removable: removable,
        useExternal: useExternal,
        storage: storage,
        fromStorage: (v) {
          if (fromStorage != null) {
            return fromStorage(v);
          }
          return v is Map ? v.cast<String, dynamic>() : null;
        },
        toStorage: toStorage,
      ),
    );
  }

  /// Creates an encrypted [Map] key.
  static KeepKeySecure<Map<String, dynamic>> kMapSecure(
    String name, {
    bool removable = false,
    bool useExternal = false,
    KeepStorage? storage,
    Map<String, dynamic>? Function(Object? value)? fromStorage,
    Object? Function(Map<String, dynamic> value)? toStorage,
  }) {
    return _register(
      KeepKeySecure<Map<String, dynamic>>(
        name: name,
        removable: removable,
        useExternal: useExternal,
        storage: storage,
        toStorage: toStorage ?? (v) => v,
        fromStorage: (v) {
          if (fromStorage != null) {
            return fromStorage(v);
          }
          return v is Map ? v.cast<String, dynamic>() : null;
        },
      ),
    );
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
    return _register(
      KeepKeyPlain<List<T>>(
        name: name,
        removable: removable,
        useExternal: useExternal,
        storage: storage,
        fromStorage: (v) {
          if (fromStorage != null) {
            return fromStorage(v);
          }
          return v is List ? v.cast<T>() : null;
        },
        toStorage: toStorage,
      ),
    );
  }

  /// Creates an encrypted [List] key.
  static KeepKeySecure<List<T>> kListSecure<T>(
    String name, {
    bool removable = false,
    bool useExternal = false,
    KeepStorage? storage,
    List<T>? Function(Object? value)? fromStorage,
    Object? Function(List<T> value)? toStorage,
  }) {
    return _register(
      KeepKeySecure<List<T>>(
        name: name,
        removable: removable,
        useExternal: useExternal,
        storage: storage,
        toStorage: toStorage ?? (v) => v,
        fromStorage: (v) {
          if (fromStorage != null) {
            return fromStorage(v);
          }
          return v is List ? v.cast<T>() : null;
        },
      ),
    );
  }

  /// Creates a standard [Uint8List] key.
  static KeepKeyPlain<Uint8List> kBytes(
    String name, {
    bool removable = false,
    bool useExternal = false,
    KeepStorage? storage,
    Uint8List? Function(Object? value)? fromStorage,
    Object? Function(Uint8List value)? toStorage,
  }) {
    return _register(
      KeepKeyPlain<Uint8List>(
        name: name,
        removable: removable,
        useExternal: useExternal,
        storage: storage,
        fromStorage: (v) {
          if (fromStorage != null) {
            return fromStorage(v);
          }

          if (v is String) return base64Decode(v);
          if (v is List) return Uint8List.fromList(v.cast<int>());
          return null;
        },
        toStorage: toStorage ?? base64Encode,
      ),
    );
  }

  /// Creates an encrypted [Uint8List] key.
  static KeepKeySecure<Uint8List> kBytesSecure(
    String name, {
    bool removable = false,
    bool useExternal = false,
    KeepStorage? storage,
    Uint8List? Function(Object? value)? fromStorage,
    Object? Function(Uint8List value)? toStorage,
  }) {
    return _register(
      KeepKeySecure<Uint8List>(
        name: name,
        removable: removable,
        useExternal: useExternal,
        storage: storage,
        toStorage: toStorage ?? base64Encode,
        fromStorage: (v) {
          if (fromStorage != null) {
            return fromStorage(v);
          }

          if (v is String) return base64Decode(v);
          if (v is List) return Uint8List.fromList(v.cast<int>());
          return null;
        },
      ),
    );
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
    return _register(
      KeepKeyPlain<T>(
        name: name,
        removable: removable,
        useExternal: useExternal,
        storage: storage,
        fromStorage: fromStorage,
        toStorage: toStorage,
      ),
    );
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
    return _register(
      KeepKeySecure<T>(
        name: name,
        removable: removable,
        useExternal: useExternal,
        storage: storage,
        fromStorage: fromStorage,
        toStorage: toStorage,
      ),
    );
  }

  var _isInitializing = false;

  /// Initializes the keep by creating directories and starting storage adapters.
  ///
  /// [path] specifies the base directory. Defaults to app support directory.
  /// Folder name is automatically derived from the class name hash.
  ///
  /// If initialization fails, [_initCompleter] is completed with the error so
  /// subsequent `ensureInitialized` awaits throw instead of hanging forever.
  /// The original exception is also propagated to the caller via [onError]
  /// and rethrown.
  @mustCallSuper
  Future<void> init({String? path}) async {
    if (_initCompleter.isCompleted || _isInitializing) {
      return _initCompleter.future;
    }

    _isInitializing = true;

    try {
      _path = path ?? (await getApplicationSupportDirectory()).path;

      await encrypter.init();
      await root.create(recursive: true);

      await Future.wait([
        internalStorage.init(this),
        externalStorage.init(this),
      ]);

      // Warn in debug builds when secure keys are used together with the
      // built-in fallback encrypter, whose key is a public constant and
      // offers only basic obfuscation.
      if (_usingDefaultEncrypter &&
          kDebugMode &&
          _registry.values.any((k) => k is KeepKeySecure)) {
        debugPrint(
          '⚠️ Keep: Using the default SimpleKeepEncrypter with a public key. '
          'This provides only basic obfuscation and is NOT safe for sensitive '
          'data. Provide a strong `encrypter` (e.g. AES-GCM backed by a '
          'platform keychain) via the Keep constructor.',
        );
      }

      _initCompleter.complete();
    } catch (error, stackTrace) {
      final exception = error is KeepException
          ? error
          : KeepException<dynamic>(
              'Failed to initialize Keep',
              error: error,
              stackTrace: stackTrace,
            );

      onError?.call(exception);

      if (!_initCompleter.isCompleted) {
        _initCompleter.completeError(exception, stackTrace);
      }

      rethrow;
    } finally {
      _isInitializing = false;
    }
  }

  /// Per-key serialization locks used by [KeepKey.update] to prevent
  /// lost-update races between concurrent atomic updates targeting the same
  /// underlying key.
  final Map<String, Future<void>> _serialLocks = {};

  /// Runs [action] under a per-key mutex keyed by [id].
  ///
  /// Successive callers with the same [id] are queued and execute strictly
  /// sequentially. The result (or error) of [action] is returned/thrown to
  /// the caller; errors do not poison the queue — the next waiter still
  /// runs.
  @internal
  Future<R> runSerialized<R>(String id, Future<R> Function() action) async {
    final previous = _serialLocks[id];
    final completer = Completer<void>();
    _serialLocks[id] = completer.future;

    try {
      if (previous != null) {
        await previous.catchError((Object _) {});
      }
      return await action();
    } finally {
      completer.complete();
      // Only clear the slot if no later caller has replaced it.
      if (identical(_serialLocks[id], completer.future)) {
        _serialLocks.remove(id);
      }
    }
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

    // Invalidate caches and notify currently registered removable keys that
    // their data has been cleared so any UI listening to these keys updates.
    for (final key in removableKeys) {
      key.invalidateCache();
      if (!onChangeController.isClosed) {
        onChangeController.add(key);
      }
    }
  }

  /// Deletes all data from both internal and external storage.
  ///
  /// This is a complete reset of the keep. It removes the main database file
  /// and all individual external files. Active listeners will be notified
  /// with a `null` value event after their caches are invalidated.
  Future<void> clear() async {
    await ensureInitialized;

    await externalStorage.clear();
    await internalStorage.clear();

    // Invalidate caches for all known keys and notify listeners.
    for (final key in _registry.values) {
      key.invalidateCache();
      if (!onChangeController.isClosed) {
        onChangeController.add(key);
      }
    }
  }

  /// Flushes any pending writes in both internal and external storage to
  /// disk.
  ///
  /// `await keep.flush()` returns only after every in-flight or debounced
  /// write has been persisted. Most callers do not need to invoke this —
  /// `await keepKey.write(...)` already guarantees durability for that
  /// particular value — but `flush` is useful in two situations:
  ///
  /// 1. You issued one or more `unawaited(keepKey.write(...))` calls and now
  ///    want to ensure they have all reached disk (e.g. before exiting a
  ///    test, or before calling [dispose]).
  /// 2. You want to make a snapshot of the storage directory at a known
  ///    consistent point.
  Future<void> flush() async {
    await ensureInitialized;
    await Future.wait([
      internalStorage.flush(),
      externalStorage.flush(),
    ]);
  }

  /// Disposes resources held by this [Keep] instance.
  ///
  /// Pending writes are flushed to disk before tearing down the underlying
  /// writer queues so that data is never silently lost during shutdown. Call
  /// this when the [Keep] instance is no longer needed to prevent memory
  /// leaks.
  Future<void> dispose() async {
    await onChangeController.close();
    await internalStorage.dispose();
    await externalStorage.dispose();
  }
}
