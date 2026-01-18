part of 'key.dart';

/// Manages registration and persistence of sub-keys.
///
/// Sub-keys are stored in a separate file (hashed) associated with the parent key.
class SubKeyManager<T> extends Iterable<KeepKey<T>> {
  /// Creates a [SubKeyManager] for the given [parent] key.
  SubKeyManager(this._parent);

  final KeepKey<T> _parent;

  /// In-memory cache of registered sub-key names.
  final _keysMemory = <String>[];

  /// The file name for storing sub-key names, derived from the parent key's name.
  late final String _fileName = KeepCodec.generateHash('${_parent.name}\$sk');

  /// File path: `root/hash(parentName$sk)`
  File get _file => File('${_parent._keep.root.path}/$_fileName');

  /// Registers a sub-key name synchronously.
  ///
  /// Adds to memory immediately and schedules a background sync to merge with disk.
  void register(KeepKey<T> key) {
    if (_keysMemory.contains(key.name)) {
      return;
    }

    _keysMemory.add(key.name);
    _scheduleSync();
  }

  Timer? _timer;

  /// Schedules a debounced sync operation (150ms delay).
  void _scheduleSync() {
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 150), _performSync);
  }

  Future<Set<String>> _performLoad() async {
    if (_file.existsSync()) {
      final bytes = await _file.readAsBytes();
      try {
        final decoded = KeepCodec.decodePayload(bytes);
        if (decoded?.value is List) {
          return (decoded!.value as List).toSet().cast();
        }
      } catch (error, stackTrace) {
        final exception = KeepException<T>(
          'Failed to decode sub-key file',
          error: error,
          stackTrace: stackTrace,
        );

        _parent._keep.onError?.call(exception);
        throw exception;
      }
    }

    return <String>{};
  }

  Future<void> _performSave() async {
    try {
      // Atomic write: Write to temp file -> Rename
      final tempFile = File(
        '${_file.path}.${DateTime.now().microsecondsSinceEpoch}.tmp',
      );

      // Use KeepCodec to encode (Shift bytes)
      await tempFile.writeAsBytes(KeepCodec.encodePayload(_keysMemory, 0));
      await tempFile.rename(_file.path);
    } catch (error, stackTrace) {
      final exception = KeepException<T>(
        'Failed to save sub-key file',
        error: error,
        stackTrace: stackTrace,
      );

      _parent._keep.onError?.call(exception);
      throw exception;
    }
  }

  /// Merges memory keys with disk keys and saves the result atomically if changed.
  Future<void> _performSync() async {
    final keysLoaded = await _performLoad();

    // Merge: Disk + Memory (Union)
    final keys = {...keysLoaded, ..._keysMemory};

    // Update memory to reflect full state (Disk + Memory)
    _keysMemory
      ..clear()
      ..addAll(keys);

    // If disk already has all keys, no need to write
    if (setEquals(keysLoaded, keys)) {
      return;
    }

    await _performSave();
  }

  @override
  Iterator<KeepKey<T>> get iterator {
    return _keysMemory.map((name) => _parent(name.split(r'$').last)).iterator;
  }

  /// Clears all registered sub-keys from memory and disk.
  Future<void> clear() async {
    _keysMemory.clear();

    try {
      if (_file.existsSync()) {
        await _file.delete();
      }
    } catch (error, stackTrace) {
      final exception = KeepException<T>(
        'Failed to clear sub-key file',
        error: error,
        stackTrace: stackTrace,
      );

      _parent._keep.onError?.call(exception);
      throw exception;
    }
  }

  /// Returns `true` if sub-keys exist in memory or on disk.
  bool get exists {
    return _keysMemory.isNotEmpty || _file.existsSync();
  }

  /// Removes a specific sub-key from the registry.
  Future<void> remove(KeepKey<T> key) async {
    _keysMemory.remove(key.name);
    await _performSave();
  }
}
