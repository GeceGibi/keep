part of 'storage.dart';

/// Default implementation using the standard [Directory] and [File] system.
/// Uses [KeepCodec] for binary payload serialization.
class DefaultKeepExternalStorage extends KeepStorage {
  late Directory _root;
  late Keep _keep;

  final Map<String, Future<void>> _queue = {};

  static const int _flagRemovable = 1;

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
      _root = Directory('${keep.root.path}/external');
      _keep = keep;

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
    return File('${_root.path}/${key.name}') as F;
  }

  @override
  Future<V?> read<V>(KeepKey<dynamic> key) async {
    try {
      return _withQueue(key.name, () async {
        final file = getEntry<File>(key);

        if (!await file.exists()) {
          return null;
        }

        final bytes = await file.readAsBytes();
        if (bytes.isEmpty) return null;

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
      await _withQueue(key.name, () async {
        final file = getEntry<File>(key);
        final tmp = File('${file.path}.tmp');

        final flags = key.removable ? _flagRemovable : 0;
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
    final files = await getEntries<File>();
    for (final file in files) {
      try {
        if (!await file.exists()) continue;

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

        if (firstByte != -1 && (firstByte & _flagRemovable) != 0) {
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
    for (final file in await getEntries<FileSystemEntity>()) {
      try {
        await file.delete();
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
    try {
      if (!_root.existsSync()) return [];
      return (await _root.list().toList()).cast<E>();
    } catch (error, stackTrace) {
      final exception = KeepException<dynamic>(
        'Failed to get entries',
        stackTrace: stackTrace,
        error: error,
      );

      _keep.onError?.call(exception);
      throw exception;
    }
  }
}
