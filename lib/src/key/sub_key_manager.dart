part of 'key.dart';

/// Event types for [SubKeyManager] changes.
enum SubKeyEvent {
  /// A sub-key was registered.
  added,

  /// A sub-key was removed.
  removed,

  /// All sub-keys were cleared.
  cleared,
}

/// Manages registration and persistence of sub-keys.
///
/// Sub-keys are dynamically resolved from storage using the parent's prefix.
class SubKeyManager<T> extends ChangeNotifier {
  /// Creates a [SubKeyManager] for the given [parent] key.
  SubKeyManager(this._parent);
  final KeepKey<T> _parent;

  /// Stream controller for sub-key events.
  final _controller = StreamController<SubKeyEvent>.broadcast();

  /// In-memory registry of instantiated sub-keys (even if not yet written).
  final _instantiatedKeys = <String>{};

  /// A stream of sub-key events (added, removed, cleared).
  Stream<SubKeyEvent> get stream => _controller.stream;

  /// Registers a sub-key name synchronously.
  ///
  /// Tracks the key in memory even if it hasn't been written to storage yet.
  Future<void> _register(KeepKey<T> key) async {
    // Only notify if this is a new key
    final wasAdded = _instantiatedKeys.add(key.name);

    if (wasAdded) {
      _controller.add(.added);
      notifyListeners();
    }
  }

  /// Removes a specific sub-key from the registry.
  Future<void> _unregister(KeepKey<T> key) async {
    _instantiatedKeys.remove(key.name);
    _controller.add(.removed);
    notifyListeners();
  }

  /// Clears all sub-keys associated with the parent key from memory and disk.
  Future<void> clear() async {
    await _parent._keep.ensureInitialized;

    try {
      final prefix = '${_parent.storeName}\$';

      // 1. Clear Internal Storage
      final internalKeys = await _parent._keep.internalStorage.getKeys();
      await Future.wait(
        internalKeys
            .where((k) => k.startsWith(prefix))
            .map(_parent._keep.internalStorage.removeKey),
      );

      // 2. Clear External Storage
      final externalKeys = await _parent._keep.externalStorage.getKeys();
      await Future.wait(
        externalKeys
            .where((k) => k.startsWith(prefix))
            .map(_parent._keep.externalStorage.removeKey),
      );

      // 3. Clear in-memory registry
      _instantiatedKeys.clear();

      _controller.add(.cleared);
      notifyListeners();
    } catch (error, stackTrace) {
      final exception = KeepException<T>(
        'Failed to clear sub-keys',
        error: error,
        stackTrace: stackTrace,
      );

      _parent._keep.onError?.call(exception);
      throw exception;
    }
  }

  /// Returns all registered sub-keys as [KeepKey] instances.
  ///
  /// Recovers original key names from storage headers and in-memory registry.
  Future<List<KeepKey<T>>> toList() async {
    await _parent._keep.ensureInitialized;

    final prefix = '${_parent.storeName}\$';
    final foundNames = <String>{};
    final internalStorage = _parent._keep.internalStorage;

    // 1. Add instantiated keys (even if not written yet)
    foundNames.addAll(_instantiatedKeys);

    // 2. Scan Internal Memory
    for (final entry in internalStorage.memory.values) {
      final storeName = entry.storeName;

      if (storeName.startsWith(prefix)) {
        // Only include direct children (no more '$' after prefix)
        final remaining = storeName.substring(prefix.length);
        if (!remaining.contains(r'$')) {
          foundNames.add(entry.name);
        }
      }
    }

    // 2. Scan External Storage
    final externalKeys = await _parent._keep.externalStorage.getKeys();

    for (final storeName in externalKeys) {
      if (!storeName.startsWith(prefix)) continue;

      // Only include direct children (no more '$' after prefix)
      final remaining = storeName.substring(prefix.length);
      if (remaining.contains(r'$')) continue;

      try {
        final root = _parent._keep.root;
        final file = File('${root.path}/external/$storeName');

        if (!file.existsSync()) continue;

        final handle = await file.open();
        try {
          final fileLen = await file.length();
          if (fileLen == 0) continue;

          // Read header chunk (512 bytes should be enough)
          var readSize = 512;
          if (readSize > fileLen) readSize = fileLen;

          await handle.setPosition(0);
          final buffer = await handle.read(readSize);
          final unShifted = KeepCodec.unShiftBytes(buffer);

          // Parse header using helper
          final header = KeepCodec.parseHeader(unShifted);

          if (header != null) {
            foundNames.add(header.name);
          }
        } finally {
          await handle.close();
        }
      } catch (_) {
        // Ignore read errors for individual files
      }
    }

    // 3. Convert to KeepKey list
    final result = <KeepKey<T>>[];
    for (final name in foundNames) {
      result.add(_parent.call(name));
    }

    return result;
  }

  @override
  void dispose() {
    _controller.close().ignore();
    super.dispose();
  }
}
