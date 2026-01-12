part of 'vault.dart';

/// In-memory storage that syncs to a binary file.
/// Uses [VaultCodec] for binary serialization/deserialization.
class _VaultInternalStorage extends VaultStorage {
  late File _rootFile;
  late final Vault _vault;

  /// In-memory cache of entries.
  Map<String, VaultEntry> memory = {};

  Timer? _saveDebounce;

  static const int _flagRemovable = 1;

  @override
  Future<void> init(Vault vault) async {
    try {
      _vault = vault;
      _rootFile = File('${vault.root.path}/main.vault');

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
      memory = await compute(VaultCodec.decodeAll, bytes);
    } catch (error, stackTrace) {
      final exception = VaultException<dynamic>(
        'Failed to initialize internal storage',
        stackTrace: stackTrace,
        error: error,
      );

      vault.onError?.call(exception);
      memory = {};
    }
  }

  /// Saves the current memory state to disk.
  Future<void> saveMemory() async {
    if (_saveDebounce?.isActive ?? false) _saveDebounce!.cancel();

    _saveDebounce = Timer(const Duration(milliseconds: 150), () async {
      try {
        final currentMemory = Map<String, VaultEntry>.from(memory);
        final bytes = await compute(VaultCodec.encodeAll, currentMemory);

        final tmp = File('${_rootFile.path}.tmp');
        await tmp.writeAsBytes(bytes, flush: true);
        await tmp.rename(_rootFile.path);
      } catch (error, stackTrace) {
        final exception = VaultException<dynamic>(
          'Failed to save internal storage',
          stackTrace: stackTrace,
          error: error,
        );
        _vault.onError?.call(exception);
      }
    });
  }

  @override
  Future<V?> read<V>(VaultKey<dynamic> key) async {
    return readSync<V>(key);
  }

  @override
  Future<void> write(VaultKey<dynamic> key, dynamic value) async {
    int flags = 0;
    if (key.removable) {
      flags |= _flagRemovable;
    }

    memory[key.name] = VaultEntry(value, flags);
    unawaited(saveMemory());
  }

  @override
  Future<void> remove(VaultKey<dynamic> key) async {
    memory.remove(key.name);
    unawaited(saveMemory());
  }

  @override
  Future<void> clear() async {
    memory.clear();
    unawaited(saveMemory());
  }

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

  @override
  V? readSync<V>(VaultKey<dynamic> key) {
    final entry = memory[key.name];
    if (entry == null) return null;
    return entry.value as V?;
  }

  @override
  FutureOr<bool> exists(VaultKey<dynamic> key) => memory.containsKey(key.name);

  @override
  bool existsSync(VaultKey<dynamic> key) => memory.containsKey(key.name);

  @override
  F getEntry<F>(VaultKey<dynamic> key) {
    final entry = memory[key.name];
    if (entry == null) {
      throw VaultException<dynamic>(
        'Key "${key.name}" not found in internal storage',
      );
    }
    return entry as F;
  }

  @override
  FutureOr<List<E>> getEntries<E>() {
    // Return values or keys?
    // Protocol says "raw entries". Usually for inspection.
    return memory.values.map((e) => e.value).toList().cast<E>();
  }
}
