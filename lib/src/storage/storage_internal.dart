part of 'storage.dart';

/// In-memory storage that syncs to a binary file.
/// Uses [KeepCodec] for binary serialization/deserialization.
@internal
class KeepInternalStorage extends KeepStorage {
  late File _rootFile;
  late final Keep _keep;

  /// In-memory cache of entries.
  Map<String, KeepMemoryValue> memory = {};

  Timer? _saveDebounce;

  /// Initializes the internal storage by loading the 'main.keep' file.
  @override
  Future<void> init(Keep keep) async {
    _keep = keep;
    _rootFile = File('${keep.root.path}/main.keep');

    try {
      if (!_rootFile.existsSync()) {
        await _rootFile.create(recursive: true);
        await _rootFile.writeAsBytes(Uint8List(0)); // Empty binary
        memory = {};
        return;
      }

      final bytes = await _rootFile.readAsBytes();

      if (bytes.isEmpty) {
        memory = {};
        return;
      }

      // Isolate logic for decoding
      memory = await compute(KeepCodec.decodeAll, bytes);
    } catch (error, stackTrace) {
      final exception = KeepException<dynamic>(
        'Failed to initialize internal storage',
        stackTrace: stackTrace,
        error: error,
      );

      keep.onError?.call(exception);
      memory = {};
      throw exception;
    }
  }

  /// Saves the current memory state to disk.
  Future<void> saveMemory() async {
    if (_saveDebounce?.isActive ?? false) {
      _saveDebounce!.cancel();
    }

    _saveDebounce = Timer(const Duration(milliseconds: 150), () async {
      try {
        final currentMemory = Map<String, KeepMemoryValue>.from(memory);
        final bytes = await compute(KeepCodec.encodeAll, currentMemory);

        final tmp = File('${_rootFile.path}.tmp');
        await tmp.writeAsBytes(bytes, flush: true);
        await tmp.rename(_rootFile.path);
      } catch (error, stackTrace) {
        final exception = KeepException<dynamic>(
          'Failed to save internal storage',
          stackTrace: stackTrace,
          error: error,
        );

        /// Call onError callback if provided
        _keep.onError?.call(exception);
        throw exception;
      }
    });
  }

  /// Asynchronously reads a value from the memory cache.
  @override
  Future<V?> read<V>(KeepKey<dynamic> key) async {
    return readSync<V>(key);
  }

  /// Writes a value to the memory cache and triggers a persistence sync.
  @override
  Future<void> write(KeepKey<dynamic> key, dynamic value) async {
    var flags = 0;
    if (key.removable) {
      flags |= KeepCodec.flagRemovable;
    }
    if (key is KeepKeySecure) {
      flags |= KeepCodec.flagSecure;
    }

    memory[key.storeName] = KeepMemoryValue(value, flags);
    unawaited(saveMemory());
  }

  /// Removes an entry from memory and triggers a persistence sync.
  @override
  Future<void> remove(KeepKey<dynamic> key) async {
    memory.remove(key.storeName);
    unawaited(saveMemory());
  }

  /// Clears all entries from the internal storage.
  @override
  Future<void> clear() async {
    memory.clear();
    unawaited(saveMemory());
  }

  /// Removes all entries marked as removable from memory.
  @override
  Future<void> clearRemovable() async {
    final keysToRemove = memory.keys
        .where((k) => memory[k]?.isRemovable ?? false)
        .toList();

    if (keysToRemove.isNotEmpty) {
      keysToRemove.forEach(memory.remove);
      unawaited(saveMemory());
    }
  }

  /// Synchronously reads a value from the memory cache.
  @override
  V? readSync<V>(KeepKey<dynamic> key) {
    final entry = memory[key.storeName];
    if (entry == null) {
      return null;
    }
    return entry.value as V?;
  }

  @override
  FutureOr<bool> exists(KeepKey<dynamic> key) {
    return memory.containsKey(key.storeName);
  }

  @override
  bool existsSync(KeepKey<dynamic> key) {
    return memory.containsKey(key.storeName);
  }

  @override
  F getEntry<F>(KeepKey<dynamic> key) {
    final entry = memory[key.storeName];
    if (entry == null) {
      throw KeepException<dynamic>(
        'Key "${key.storeName}" not found in internal storage',
      );
    }
    return entry as F;
  }

  @override
  List<E> getEntries<E>() {
    /// Returns a list of all raw entries in memory.
    return memory.entries.toList().cast<E>();
  }
}
