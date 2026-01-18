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
/// Sub-keys are stored in a separate file (hashed) associated with the parent key.
class SubKeyManager<T> extends ChangeNotifier {
  /// Creates a [SubKeyManager] for the given [parent] key.
  SubKeyManager(this._parent);
  final KeepKey<T> _parent;

  /// Stream controller for sub-key events.
  final _controller = StreamController<SubKeyEvent>.broadcast();

  /// A stream of sub-key events (added, removed, cleared).
  Stream<SubKeyEvent> get stream => _controller.stream;

  /// In-memory cache of registered sub-key names.
  final _keys = <String>[];

  /// Completer for initialization.
  Completer<void>? _completer;

  /// Ensures the sub-key manager is initialized.
  Future<void> _ensureInitialized() async {
    if (_completer != null) {
      return _completer!.future;
    }

    _completer = Completer<void>();
    try {
      await _performLoad();
      _completer!.complete();
    } catch (e) {
      _completer!.completeError(e);
      rethrow;
    }
  }

  /// The file name for storing sub-key names, derived from the parent key's name.
  late final String _fileName = KeepCodec.generateHash('${_parent.name}\$sk');

  /// File path: `root/hash(parentName$sk)`
  File get _file => File('${_parent._keep.root.path}/$_fileName');

  /// Registers a sub-key name synchronously.
  ///
  /// Adds to memory immediately and schedules a background sync to merge with disk.
  Future<void> register(KeepKey<T> key) async {
    await _ensureInitialized();

    if (_keys.contains(key.name)) {
      return;
    }

    _keys.add(key.name);

    _controller.add(.added);
    notifyListeners();

    _performSave();
  }

  /// Loads sub-key names from disk into memory.
  Future<void> _performLoad() async {
    if (_file.existsSync()) {
      final bytes = await _file.readAsBytes();
      try {
        final decoded = KeepCodec.decodePayload(bytes);
        if (decoded?.value is List) {
          _keys.addAll((decoded!.value as List).cast());
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
  }

  Timer? _timer;
  void _performSave() {
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 150), () async {
      try {
        // Atomic write: Write to temp file -> Rename
        final tempFile = File(
          '${_file.path}.${DateTime.now().microsecondsSinceEpoch}.tmp',
        );

        // Use KeepCodec to encode (Shift bytes)
        await tempFile.writeAsBytes(KeepCodec.encodePayload(_keys, 0));
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
    });
  }

  /// Clears all registered sub-keys from memory and disk.
  Future<void> clear() async {
    _keys.clear();
    _controller.add(.cleared);
    notifyListeners();

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
  Future<bool> get exists async {
    await _ensureInitialized();
    return _keys.isNotEmpty;
  }

  /// Returns all registered sub-keys as [KeepKey] instances.
  ///
  /// Re-registers each key via [KeepKey.call], but duplicates are ignored.
  Future<List<KeepKey<T>>> toList() async {
    await _ensureInitialized();
    return _keys.map(_parent.call).toList();
  }

  /// Removes a specific sub-key from the registry.
  Future<void> remove(KeepKey<T> key) async {
    await _ensureInitialized();
    _keys.remove(key.name);
    _controller.add(.removed);
    notifyListeners();

    _performSave();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.close().ignore();
    super.dispose();
  }
}
