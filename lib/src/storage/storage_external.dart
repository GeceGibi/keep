part of 'storage.dart';

/// Default implementation using the standard [Directory] and [File] system.
/// Uses [KeepCodec] for binary payload serialization.
class DefaultKeepExternalStorage extends KeepStorage {
  /// Creates a new [DefaultKeepExternalStorage] instance.
  DefaultKeepExternalStorage();
  late Directory _root;
  late Keep _keep;
  final Map<String, Future<void>> _queue = {};

  /// Executes a file [action] by queuing it to prevent concurrent write/read conflicts
  /// on the same [key].
  Future<T> _withQueue<T>(String key, Future<T> Function() action) async {
    final previous = _queue[key];
    final completer = Completer<void>();
    _queue[key] = completer.future;

    try {
      await previous;
      return await action();
    } finally {
      completer.complete();

      if (_queue[key] == completer.future) {
        _queue.remove(key)?.ignore();
      }
    }
  }

  /// Initializes the external storage by ensuring the 'external' directory exists.
  @override
  Future<void> init(Keep keep) async {
    try {
      _keep = keep;
      _root = Directory('${keep.root.path}/external');

      if (!_root.existsSync()) {
        await _root.create(recursive: true);
      }
    } catch (error, stackTrace) {
      final exception = KeepException<dynamic>(
        'Failed to initialize external storage',
        stackTrace: stackTrace,
        error: error,
      );

      keep.onError?.call(exception);
      throw exception;
    }
  }

  /// Gets the [File] object for a given [key].
  File getFile(KeepKey<dynamic> key) {
    return File('${_root.path}/${key.storeName}');
  }

  /// Asynchronously reads a file's content and decodes the payload.
  @override
  Future<V?> read<V>(KeepKey<dynamic> key) async {
    try {
      return _withQueue(key.storeName, () async {
        final file = getFile(key);

        if (!file.existsSync()) {
          return null;
        }

        final bytes = await file.readAsBytes();
        if (bytes.isEmpty) {
          return null;
        }

        final entry = KeepCodec.decode(bytes);

        // If decode failed (legacy format or corrupted), delete the file
        if (entry == null && file.existsSync()) {
          await file.delete();
        }

        return entry?.value as V?;
      });
    } on KeepException<dynamic> catch (e) {
      _keep.onError?.call(e);
      rethrow;
    } catch (error, stackTrace) {
      final exception = key.toException(
        'Failed to read $key',
        error: error,
        stackTrace: stackTrace,
      );

      _keep.onError?.call(exception);
      throw exception;
    }
  }

  /// Synchronously reads a file's content and decodes the payload.
  @override
  V? readSync<V>(KeepKey<dynamic> key) {
    final file = getFile(key);
    if (!file.existsSync()) {
      return null;
    }

    final bytes = file.readAsBytesSync();
    if (bytes.isEmpty) {
      return null;
    }

    final entry = KeepCodec.decode(bytes);

    // If decode failed (legacy format or corrupted), delete the file
    if (entry == null && file.existsSync()) {
      file.delete().ignore();
    }

    return entry?.value as V?;
  }

  /// Writes a value to an external file using a temporary file for atomic updates.
  @override
  Future<void> write(KeepKey<dynamic> key, Object? value) async {
    try {
      await _withQueue(key.storeName, () async {
        final file = getFile(key);
        final tmp = File('${file.path}.tmp');

        var flags = 0;
        if (key.removable) flags |= KeepCodec.flagRemovable;
        if (key is KeepKeySecure) flags |= KeepCodec.flagSecure;

        final bytes = KeepCodec.encode(
          storeName: key.storeName,
          keyName: key.name,
          flags: flags,
          value: value,
        );

        await tmp.writeAsBytes(bytes, flush: true);
        await tmp.rename(file.path);
      });
    } on KeepException<dynamic> catch (e) {
      _keep.onError?.call(e);
      rethrow;
    } catch (error, stackTrace) {
      final exception = key.toException(
        'Failed to write $key',
        error: error,
        stackTrace: stackTrace,
      );

      _keep.onError?.call(exception);
      throw exception;
    }
  }

  @override
  bool existsSync(KeepKey<dynamic> key) {
    return getFile(key).existsSync();
  }

  /// Asynchronously checks if the file for [key] exists on disk.
  @override
  Future<bool> exists(KeepKey<dynamic> key) async {
    try {
      return getFile(key).existsSync();
    } on KeepException<dynamic> catch (e) {
      _keep.onError?.call(e);
      rethrow;
    } catch (error, stackTrace) {
      final exception = key.toException(
        'Failed to check if $key exists',
        error: error,
        stackTrace: stackTrace,
      );

      _keep.onError?.call(exception);
      throw exception;
    }
  }

  @override
  Future<void> clearRemovable() async {
    // Manual flag check for performance (read only required bytes)
    final names = await getKeys();

    for (final name in names) {
      final file = File('${_keep.root.path}/external/$name');

      try {
        if (!file.existsSync()) continue;

        final handle = await file.open();

        var flagsByte = -1;

        try {
          final fileLen = await file.length();

          if (fileLen > 0) {
            // Read header chunk (515 bytes should cover max header size)
            var readSize = 515;
            if (readSize > fileLen) readSize = fileLen;

            await handle.setPosition(0);
            final buffer = await handle.read(readSize);

            if (buffer.isNotEmpty) {
              final unShifted = KeepCodec.unShiftBytes(buffer);

              // Parse header using helper
              final header = KeepCodec.parseHeader(unShifted);
              if (header != null) {
                flagsByte = header.flags;
              }
            }
          }
        } finally {
          await handle.close();
        }

        if (flagsByte != -1 && (flagsByte & KeepCodec.flagRemovable) != 0) {
          await file.delete();
        }
      } catch (error, stackTrace) {
        final exception = KeepException<dynamic>(
          'Failed to clear removable file $file',
          stackTrace: stackTrace,
          error: error,
        );

        _keep.onError?.call(exception);
        throw exception;
      }
    }
  }

  /// Deletes all files in the external storage directory.
  @override
  Future<void> clear() async {
    final names = await getKeys();
    for (final name in names) {
      final file = File('${_keep.root.path}/external/$name');
      try {
        if (await file.exists()) {
          await file.delete();
        }
      } catch (error, stackTrace) {
        final exception = KeepException<dynamic>(
          'Failed to delete $file',
          stackTrace: stackTrace,
          error: error,
        );

        _keep.onError?.call(exception);
        throw exception;
      }
    }
  }

  /// Deletes the specific file associated with [key].
  @override
  Future<void> remove(KeepKey<dynamic> key) async {
    try {
      final file = getFile(key);

      if (!existsSync(key)) {
        return;
      }

      await file.delete();
    } on KeepException<dynamic> catch (e) {
      _keep.onError?.call(e);
      rethrow;
    } catch (error, stackTrace) {
      final exception = key.toException(
        'Failed to remove $key',
        error: error,
        stackTrace: stackTrace,
      );

      _keep.onError?.call(exception);
      throw exception;
    }
  }

  /// Removes multiple files by their storage keys (file names).
  @override
  Future<void> removeKeys(List<String> storeNames) async {
    for (final storeName in storeNames) {
      try {
        final file = File('${_keep.root.path}/external/$storeName');

        if (file.existsSync()) {
          await file.delete();
        }
      } catch (error, stackTrace) {
        final exception = KeepException<dynamic>(
          'Failed to remove file $storeName',
          error: error,
          stackTrace: stackTrace,
        );

        _keep.onError?.call(exception);
        throw exception;
      }
    }
  }

  /// Returns a list of all storage keys (file names) in external storage.
  @override
  Future<List<String>> getKeys() async {
    final dir = Directory('${_keep.root.path}/external');

    if (!dir.existsSync()) {
      return [];
    }

    final list = await dir.list().where((e) => e is File).toList();

    // Return base names (filenames = storeNames)
    return list.map((e) => e.uri.pathSegments.last).toList();
  }
}
