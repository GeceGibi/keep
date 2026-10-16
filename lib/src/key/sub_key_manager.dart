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
  /// Creates a [SubKeyManager] for the given parent key.
  SubKeyManager(this._parent);
  final KeepKey<T> _parent;

  /// Stream controller for sub-key events.
  final _controller = StreamController<SubKeyEvent>.broadcast();

  /// In-memory registry of instantiated sub-keys (even if not yet written).
  final Map<String, KeepKey<T>> _instantiatedKeys = {};

  /// A stream of sub-key events (added, removed, cleared).
  Stream<SubKeyEvent> get stream => _controller.stream;

  /// Registers a sub-key instance synchronously.
  ///
  /// Tracks the key in memory even if it hasn't been written to storage yet.
  void _register(KeepKey<T> key) {
    final isNew = !_instantiatedKeys.containsKey(key.name);
    _instantiatedKeys[key.name] = key;

    if (isNew) {
      if (!_controller.isClosed) {
        _controller.add(.added);
      }
      notifyListeners();
    }
  }

  /// Removes a specific sub-key from the registry.
  void _unregister(KeepKey<T> key) {
    final removed = _instantiatedKeys.remove(key.name);

    if (removed != null) {
      if (!_controller.isClosed) {
        _controller.add(.removed);
      }
      notifyListeners();
    }
  }

  /// Notifies active listeners of all instantiated sub-keys and clears the
  /// in-memory sub-key registry.
  @internal
  void notifyAndClearInstantiated() {
    if (_instantiatedKeys.isEmpty) return;

    final subKeys = _instantiatedKeys.values.toList();
    _instantiatedKeys.clear();

    for (final subKey in subKeys) {
      if (!_parent._keep.onChangeController.isClosed) {
        _parent._keep.onChangeController.add(subKey);
      }
      subKey.keys.notifyAndClearInstantiated();
    }

    if (!_controller.isClosed) {
      _controller.add(.cleared);
    }
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
      final externalKeys = await _parent.externalStorage.getKeys();
      await Future.wait(
        externalKeys
            .where((k) => k.startsWith(prefix))
            .map(_parent.externalStorage.removeKey),
      );

      // 3. Invalidate shared value cache for all sub-keys under this prefix
      _parent._keep.valueCache.removeWhere((k, _) => k.startsWith(prefix));

      // 4. Clear in-memory registry and notify listeners
      final hadInstantiated = _instantiatedKeys.isNotEmpty;
      notifyAndClearInstantiated();

      if (!hadInstantiated) {
        if (!_controller.isClosed) {
          _controller.add(.cleared);
        }
        notifyListeners();
      }
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
    foundNames.addAll(_instantiatedKeys.keys);

    // 2. Scan Internal Memory
    for (final entry in internalStorage.memory.values) {
      final storeName = entry.storeName;

      if (storeName.startsWith(prefix)) {
        // Only include direct children (no more '$' after prefix)
        if (!storeName.substring(prefix.length).contains(r'$')) {
          foundNames.add(entry.name);
        }
      }
    }

    // 3. Scan External Storage
    final externalKeys = await _parent.externalStorage.getKeys();

    for (final storeName in externalKeys) {
      if (!storeName.startsWith(prefix)) {
        continue;
      }

      // Only include direct children (no more '$' after prefix)
      if (storeName.substring(prefix.length).contains(r'$')) {
        continue;
      }

      try {
        final header = await _parent.externalStorage.header(storeName);

        if (header != null) {
          foundNames.add(header.name);
        }
      } catch (error, stackTrace) {
        final exception = KeepException<T>(
          'Failed to read sub-key header for $storeName',
          error: error,
          stackTrace: stackTrace,
        );

        _parent._keep.onError?.call(exception);
      }
    }

    // 4. Convert to KeepKey list
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
