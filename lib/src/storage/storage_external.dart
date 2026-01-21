part of 'storage.dart';

/// Default implementation using the standard [Directory] and [File] system.
/// Uses [KeepCodec] for binary payload serialization.
class DefaultKeepExternalStorage extends KeepStorage {
  /// Creates a new [DefaultKeepExternalStorage] instance.
  DefaultKeepExternalStorage();
  late Directory _root;
  late Keep _keep;

  final _writer = KeepWriteQueue();

  final Map<String, KeepKeyHeader> _memory = {};

  /// Initializes the external storage by ensuring the 'external' directory exists.
  @override
  Future<void> init(Keep keep) async {
    try {
      _keep = keep;
      _root = Directory('${keep.root.path}/external');

      if (!_root.existsSync()) {
        await _root.create(recursive: true);
      } else {
        final names = await getKeys();

        for (final name in names) {
          final keepHeader = await header(name);

          if (keepHeader != null) {
            _memory[name] = keepHeader;
          }
        }
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
      return _writer.run<V?>(
        id: key.storeName,
        action: () async {
          final file = getFile(key);

          if (!file.existsSync()) {
            return null;
          }

          final bytes = await file.readAsBytes();
          final codec = KeepCodec.of(bytes);
          final entry = codec.decode();

          if (entry == null) {
            await file.delete();
            _memory.remove(key.storeName);
          }

          return entry?.value as V?;
        },
      );
    } on KeepException<dynamic> catch (error) {
      _keep.onError?.call(error);
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
    final codec = KeepCodec.of(bytes);
    final entry = codec.decode();

    if (entry == null) {
      file.deleteSync();
      _memory.remove(key.storeName);
    }

    return entry?.value as V?;
  }

  /// Writes a value to an external file using a temporary file for atomic updates.
  @override
  Future<void> write(KeepKey<dynamic> key, Object? value) async {
    try {
      if (value == null) {
        await _writer.run(
          id: key.storeName,
          action: () async {
            final file = getFile(key);

            if (file.existsSync()) {
              await file.delete();
            }

            _memory.remove(key.storeName);
          },
        );
        return;
      }

      await _writer.run(
        id: key.storeName,
        action: () async {
          final file = getFile(key);

          var flags = 0;
          if (key.removable) flags |= KeepCodec.flagRemovable;
          if (key is KeepKeySecure) flags |= KeepCodec.flagSecure;

          final bytes = KeepCodec.current.encode(
            storeName: key.storeName,
            keyName: key.name,
            flags: flags,
            value: value,
          );

          if (bytes == null) {
            return;
          }

          await atomicWrite(file, bytes);

          _memory[key.storeName] = KeepKeyHeader(
            storeName: key.storeName,
            name: key.name,
            flags: flags,
            type: KeepType.inferType(value),
            version: KeepCodec.current.version,
          );
        },
      );
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
    return _memory.containsKey(key.storeName);
  }

  /// Asynchronously checks if the file for [key] exists on disk.
  @override
  Future<bool> exists(KeepKey<dynamic> key) async {
    try {
      return _memory.containsKey(key.storeName);
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
    final toRemove = _memory.entries
        .where((e) => e.value.isRemovable)
        .map((e) => e.key)
        .toList();

    for (final name in toRemove) {
      await _writer.run(
        id: name,
        action: () async {
          try {
            final file = File('${_root.path}/$name');

            if (file.existsSync()) {
              await file.delete();
            }

            _memory.remove(name);
          } catch (error, stackTrace) {
            final exception = KeepException<dynamic>(
              'Failed to clear removable file $name',
              stackTrace: stackTrace,
              error: error,
            );

            _keep.onError?.call(exception);
            throw exception;
          }
        },
      );
    }
  }

  @override
  Future<KeepKeyHeader?> header(String storeName) async {
    if (_memory.containsKey(storeName)) {
      return _memory[storeName];
    }

    final file = File('${_root.path}/$storeName');
    if (!file.existsSync()) {
      return null;
    }

    final handle = await file.open();

    try {
      final fileLen = await file.length();
      if (fileLen == 0) {
        return null;
      }

      // Read header chunk (515 bytes should cover max header size)
      var readSize = 515;
      if (readSize > fileLen) readSize = fileLen;

      await handle.setPosition(0);
      final buffer = await handle.read(readSize);

      if (buffer.isEmpty) {
        return null;
      }

      final header = KeepCodec.of(buffer).header();

      if (header != null) {
        _memory[storeName] = header;
      }

      return header;
    } catch (_) {
      return null;
    } finally {
      await handle.close();
    }
  }

  /// Deletes all files in the external storage directory.
  @override
  Future<void> clear() async {
    final names = await getKeys();

    for (final name in names) {
      await _writer.run(
        id: name,
        action: () async {
          final file = File('${_root.path}/$name');

          try {
            if (await file.exists()) {
              await file.delete();
            }

            _memory.remove(name);
          } catch (error, stackTrace) {
            final exception = KeepException<dynamic>(
              'Failed to delete $file',
              stackTrace: stackTrace,
              error: error,
            );

            _keep.onError?.call(exception);
            throw exception;
          }
        },
      );
    }
  }

  /// Deletes the specific file associated with [key].
  @override
  Future<void> remove(KeepKey<dynamic> key) async {
    try {
      await _writer.run(
        id: key.storeName,
        action: () async {
          final file = getFile(key);

          if (!file.existsSync()) {
            return;
          }

          await file.delete();
          _memory.remove(key.storeName);
        },
      );
    } on KeepException<dynamic> catch (error) {
      _keep.onError?.call(error);
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
  Future<void> removeKey(String storeName) async {
    try {
      await _writer.run(
        id: storeName,
        action: () async {
          final file = File('${_root.path}/$storeName');

          if (file.existsSync()) {
            await file.delete();
            _memory.remove(storeName);
          }
        },
      );
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

  /// Returns a list of all storage keys (file names) in external storage.
  @override
  Future<List<String>> getKeys() async {
    if (!_root.existsSync()) {
      return [];
    }

    final list = await _root
        .list()
        .where((e) => e is File && !e.path.endsWith('.tmp'))
        .toList();

    // Return base names (filenames = storeNames)
    return list.map((e) => e.uri.pathSegments.last).toList();
  }

  @override
  Future<void> dispose() async {
    _writer.dispose();
  }
}
