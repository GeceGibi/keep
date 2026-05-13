part of 'storage.dart';

/// In-memory storage that syncs to a binary file.
/// Uses [KeepCodec] for binary serialization/deserialization.
@internal
class KeepInternalStorage extends KeepStorage {
  late File _rootFile;
  late final Keep _keep;

  /// In-memory cache of entries.
  Map<String, KeepKeyValue> memory = {};

  final _writer = KeepWriteQueue();

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

      // Isolate logic for decoding
      memory = await compute(_decodeAll, bytes);
    } catch (error, stackTrace) {
      final exception = KeepException<dynamic>(
        'Failed to initialize internal storage',
        stackTrace: stackTrace,
        error: error,
      );

      keep.onError?.call(exception);

      // Delete corrupted file and continue with empty memory
      try {
        await _rootFile.delete();
      } catch (_) {}

      memory = {};
    }
  }

  /// Saves the current memory state to disk and awaits the actual flush.
  ///
  /// Multiple rapid calls are debounced through [KeepWriteQueue]: only the
  /// latest enqueued snapshot is written, but ALL awaiting callers resolve
  /// once that flush completes (via the queue's supersede chain). This is
  /// what gives `await write()` its durability guarantee even when several
  /// writes are concurrently coalesced into a single disk operation.
  Future<void> saveMemory() async {
    await _writer.run<void>(
      id: 'main',
      action: () async {
        final currentMemory = Map<String, KeepKeyValue>.from(memory);
        final bytes = await compute(_encodeAll, currentMemory);

        await atomicWrite(_rootFile, bytes);
      },
      onError: (error) => _keep.onError?.call(error),
    );
  }

  /// Asynchronously reads a value from the memory cache.
  ///
  /// Awaits [Keep.ensureInitialized] so callers that access storage directly
  /// (bypassing the [KeepKey] wrapper) still observe a fully loaded memory
  /// map. Sync read remains the fast path once init has completed.
  @override
  Future<V?> read<V>(KeepKey<dynamic> key) async {
    await _keep.ensureInitialized;
    return readSync<V>(key);
  }

  /// Writes a value to the memory cache and awaits the disk flush.
  ///
  /// The returned future only resolves once the value is durably persisted
  /// (or after a successor write that already includes it has flushed).
  @override
  Future<void> write(KeepKey<dynamic> key, dynamic value) async {
    var flags = 0;
    if (key.removable) {
      flags |= KeepCodec.flagRemovable;
    }
    if (key is KeepKeySecure) {
      flags |= KeepCodec.flagSecure;
    }

    memory[key.storeName] = KeepKeyValue(
      value: value,
      name: key.name,
      flags: flags,
      storeName: key.storeName,
      version: KeepCodec.current.version,
      type: KeepType.inferType(value),
    );
    await saveMemory();
  }

  /// Removes an entry from memory and awaits the disk flush.
  @override
  Future<void> remove(KeepKey<dynamic> key) async {
    memory.remove(key.storeName);
    await saveMemory();
  }

  /// Removes a single entry by its storage key and awaits the disk flush.
  @override
  Future<void> removeKey(String storeName) async {
    memory.remove(storeName);
    await saveMemory();
  }

  /// Clears all entries from the internal storage and awaits the disk flush.
  @override
  Future<void> clear() async {
    memory.clear();
    await saveMemory();
  }

  /// Removes all entries marked as removable from memory and awaits the
  /// disk flush.
  @override
  Future<void> clearRemovable() async {
    final keysToRemove = memory.keys
        .where((k) => memory[k]?.isRemovable ?? false)
        .toList();

    if (keysToRemove.isNotEmpty) {
      keysToRemove.forEach(memory.remove);
      await saveMemory();
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
  Future<KeepKeyHeader?> header(String storeName) async {
    final entry = memory[storeName];
    if (entry == null) {
      return null;
    }

    return entry;
  }

  @override
  Future<List<String>> getKeys() async {
    return memory.keys.toList();
  }

  /// Encodes all entries into a single binary block for file storage.
  static Uint8List _encodeAll(Map<String, KeepKeyValue> entries) {
    try {
      final buffer = BytesBuilder();

      for (final entry in entries.values) {
        final payload = KeepCodec.current.encode(
          storeName: entry.storeName,
          keyName: entry.name,
          flags: entry.flags,
          value: entry.value,
        );

        if (payload != null) {
          final len = payload.length;
          buffer
            ..addByte(len >> 24 & 0xFF)
            ..addByte(len >> 16 & 0xFF)
            ..addByte(len >> 8 & 0xFF)
            ..addByte(len & 0xFF)
            ..add(payload);
        }
      }
      return KeepCodec.current.shiftBytes(buffer.toBytes());
    } catch (error, stackTrace) {
      throw KeepException<dynamic>(
        'Failed to encode batch',
        stackTrace: stackTrace,
        error: error,
      );
    }
  }

  /// Decodes a binary block into a map of entries.
  static Map<String, KeepKeyValue> _decodeAll(Uint8List bytes) {
    if (bytes.isEmpty) {
      return {};
    }

    try {
      final data = KeepCodec.current.unShiftBytes(bytes);
      final map = <String, KeepKeyValue>{};
      var offset = 0;

      while (offset + 4 <= data.length) {
        final len =
            (data[offset] << 24 |
                    data[offset + 1] << 16 |
                    data[offset + 2] << 8 |
                    data[offset + 3])
                .toUnsigned(32);

        offset += 4;
        if (offset + len > data.length) {
          break;
        }

        final entry = KeepCodec.of(data.sublist(offset, offset + len)).decode();

        if (entry != null) {
          map[entry.storeName] = entry;
        }

        offset += len;
      }
      return map;
    } catch (error, stackTrace) {
      throw KeepException<dynamic>(
        'Failed to decode batch',
        stackTrace: stackTrace,
        error: error,
      );
    }
  }

  /// Awaits any in-flight save without disposing the underlying queue.
  @override
  Future<void> flush() => _writer.flush();

  /// Awaits any in-flight save before disposing the underlying queue.
  ///
  /// Without this flush, pending debounced saves would be cancelled and the
  /// last in-memory mutations would never reach disk.
  @override
  Future<void> dispose() async {
    await _writer.flush();
    _writer.dispose();
  }
}
