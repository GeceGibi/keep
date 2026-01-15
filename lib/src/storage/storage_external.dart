part of 'storage.dart';

/// Default implementation using the standard [Directory] and [File] system.
/// Uses [KeepCodec] for binary payload serialization.
class DefaultKeepExternalStorage extends KeepStorage {
  /// Creates a new [DefaultKeepExternalStorage] instance.
  DefaultKeepExternalStorage();
  late Directory _root;
  late Keep _keep;
  final Map<String, Future<void>> _queue = {};

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

  @override
  F getEntry<F>(KeepKey<dynamic> key) {
    return File('${_root.path}/${key.storeName}') as F;
  }

  @override
  Future<V?> read<V>(KeepKey<dynamic> key) async {
    try {
      return _withQueue(key.storeName, () async {
        final file = getEntry<File>(key);

        if (!file.existsSync()) {
          return null;
        }

        final bytes = await file.readAsBytes();
        if (bytes.isEmpty) {
          return null;
        }

        final entry = KeepCodec.decodePayload(bytes);
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

  @override
  V? readSync<V>(KeepKey<dynamic> key) {
    final file = getEntry<File>(key);
    if (!file.existsSync()) return null;

    final bytes = file.readAsBytesSync();
    if (bytes.isEmpty) return null;

    final entry = KeepCodec.decodePayload(bytes);
    return entry?.value as V?;
  }

  @override
  Future<void> write(KeepKey<dynamic> key, Object? value) async {
    try {
      await _withQueue(key.storeName, () async {
        final file = getEntry<File>(key);
        final tmp = File('${file.path}.tmp');

        var flags = 0;
        if (key.removable) flags |= KeepCodec.flagRemovable;
        if (key is KeepKeySecure) flags |= KeepCodec.flagSecure;

        final bytes = KeepCodec.encodePayload(value, flags);

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
  bool existsSync(KeepKey<dynamic> key) => getEntry<File>(key).existsSync();

  @override
  Future<bool> exists(KeepKey<dynamic> key) async {
    try {
      return getEntry<File>(key).existsSync();
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
    // Manual flag check for performance (read only first byte)
    final names = await getEntries<String>();
    for (final name in names) {
      final file = File('${_keep.root.path}/external/$name');
      try {
        if (!file.existsSync()) continue;

        final handle = await file.open(mode: FileMode.read);
        int firstByte = -1;
        try {
          if (await file.length() > 0) {
            // Header is first byte
            firstByte = await handle.readByte();
          }
        } finally {
          await handle.close();
        }

        if (firstByte != -1 && (firstByte & KeepCodec.flagRemovable) != 0) {
          await file.delete();
        }
      } catch (error, stackTrace) {
        final exception = KeepException<dynamic>(
          'Failed to clear removable file $file',
          stackTrace: stackTrace,
          error: error,
        );
        _keep.onError?.call(exception);
      }
    }
  }

  @override
  Future<void> clear() async {
    final names = await getEntries<String>();
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

  @override
  Future<void> remove(KeepKey<dynamic> key) async {
    try {
      final file = getEntry<File>(key);

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

  @override
  Future<List<E>> getEntries<E>() async {
    final dir = Directory('${_keep.root.path}/external');
    if (!dir.existsSync()) return [];

    final list = await dir.list().where((e) => e is File).toList();
    // Return base names (filenames)
    return list.map((e) => e.uri.pathSegments.last).cast<E>().toList();
  }
}
