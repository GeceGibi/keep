part of 'storage.dart';

/// In-memory storage that syncs to a binary file.
/// Uses [KeepCodec] for binary serialization/deserialization.
@internal
class KeepInternalStorage extends KeepStorage {
  late File _rootFile;
  late final Keep _keep;

  /// In-memory cache of entries.
  Map<String, KeepInternalEntry> memory = {};

  Timer? _debounceTimer;

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

  /// Saves the current memory state to disk.
  Future<void> saveMemory() async {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 150), () async {
      try {
        final currentMemory = Map<String, KeepInternalEntry>.from(memory);
        final bytes = await compute(_encodeAll, currentMemory);

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

    memory[key.storeName] = KeepInternalEntry(
      value: value,
      flags: flags,
      name: key.name,
      storeName: key.storeName,
    );
    unawaited(saveMemory());
  }

  /// Removes an entry from memory and triggers a persistence sync.
  @override
  Future<void> remove(KeepKey<dynamic> key) async {
    memory.remove(key.storeName);
    unawaited(saveMemory());
  }

  /// Removes multiple entries from memory by their storage keys.
  @override
  Future<void> removeKey(String storeName) async {
    memory.remove(storeName);
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
  Future<({String name, int flags, int version, KeepType type})?> readHeader(
    String storeName,
  ) async {
    final entry = memory[storeName];
    if (entry == null) {
      return null;
    }

    return (
      name: entry.name,
      flags: entry.flags,
      version: entry.version,
      type: entry.type,
    );
  }

  @override
  Future<List<String>> getKeys() async {
    return memory.keys.toList();
  }

  /// Encodes all entries into a single binary block for file storage.
  static Uint8List _encodeAll(Map<String, KeepInternalEntry> entries) {
    try {
      final buffer = BytesBuilder();

      entries.forEach((storeName, entry) {
        final payloadBytes = KeepCodec.codecs.last.encode(
          storeName: storeName,
          keyName: entry.name,
          flags: entry.flags,
          value: entry.value,
        );

        if (payloadBytes == null) return;

        final payloadLen = payloadBytes.length;

        // Format: [PayloadLen(4)] [PayloadBytes(N)]
        buffer
          ..addByte((payloadLen >> 24) & 0xFF)
          ..addByte((payloadLen >> 16) & 0xFF)
          ..addByte((payloadLen >> 8) & 0xFF)
          ..addByte(payloadLen & 0xFF)
          ..add(payloadBytes);
      });

      return KeepCodec.shiftBytes(buffer.toBytes());
    } catch (error, stackTrace) {
      throw KeepException<dynamic>(
        'Failed to encode batch',
        stackTrace: stackTrace,
        error: error,
      );
    }
  }

  /// Decodes a binary block into a map of entries.
  static Map<String, KeepInternalEntry> _decodeAll(Uint8List bytes) {
    if (bytes.isEmpty) return {};

    try {
      final data = KeepCodec.unShiftBytes(Uint8List.fromList(bytes));
      final map = <String, KeepInternalEntry>{};
      var offset = 0;

      while (offset < data.length) {
        if (offset + 4 > data.length) break;

        final payloadLen =
            ((data[offset] << 24) |
                    (data[offset + 1] << 16) |
                    (data[offset + 2] << 8) |
                    (data[offset + 3]))
                .toUnsigned(32);
        offset += 4;

        if (offset + payloadLen > data.length) break;

        final payloadBytes = data.sublist(offset, offset + payloadLen);
        final entry = KeepCodec.of(payloadBytes).decode();

        if (entry != null) {
          map[entry.storeName] = entry;
        }

        offset += payloadLen;
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
}
