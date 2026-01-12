part of 'vault.dart';

/// Default implementation using the standard [Directory] and [File] system.
class DefaultVaultExternalStorage extends VaultStorage {
  late Directory _root;
  late Vault _vault;

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
  Future<void> init(Vault vault) async {
    try {
      _root = Directory('${vault.root.path}/external');
      _vault = vault;

      if (!_root.existsSync()) {
        await _root.create(recursive: true);
      }
    } catch (error, stackTrace) {
      final exception = VaultException<dynamic>(
        'Failed to initialize external storage',
        stackTrace: stackTrace,
        error: error,
      );

      vault.onError?.call(exception);
      throw exception;
    }
  }

  @override
  F getEntry<F>(VaultKey<dynamic> key) {
    return File('${_root.path}/${key.name}') as F;
  }

  @override
  Future<V?> read<V>(VaultKey<dynamic> key) async {
    try {
      return _withQueue(key.name, () async {
        final file = getEntry<File>(key);

        if (!existsSync(key)) {
          return null;
        }

        return jsonDecode(file.readAsStringSync()) as V?;
      });
    } on VaultException<dynamic> catch (e) {
      _vault.onError?.call(e);
      rethrow;
    } catch (error, stackTrace) {
      final exception = key.toException(
        'Failed to read $key',
        error: error,
        stackTrace: stackTrace,
      );

      _vault.onError?.call(exception);

      throw exception;
    }
  }

  @override
  Future<void> write(VaultKey<dynamic> key, Object? value) async {
    try {
      await _withQueue(key.name, () async {
        final file = getEntry<File>(key);
        final tmp = File('${file.path}.tmp');
        await tmp.writeAsString(jsonEncode(value), flush: true);
        await tmp.rename(file.path);
      });
    } on VaultException<dynamic> catch (e) {
      _vault.onError?.call(e);
      rethrow;
    } catch (error, stackTrace) {
      final exception = key.toException(
        'Failed to write $key',
        error: error,
        stackTrace: stackTrace,
      );

      _vault.onError?.call(exception);
      throw exception;
    }
  }

  @override
  bool existsSync(VaultKey<dynamic> key) => getEntry<File>(key).existsSync();

  @override
  Future<bool> exists(VaultKey<dynamic> key) async {
    try {
      return getEntry<File>(key).existsSync();
    } on VaultException<dynamic> catch (e) {
      _vault.onError?.call(e);
      rethrow;
    } catch (error, stackTrace) {
      final exception = key.toException(
        'Failed to check if $key exists',
        error: error,
        stackTrace: stackTrace,
      );

      _vault.onError?.call(exception);
      throw exception;
    }
  }

  @override
  Future<void> clear() async {
    for (final file in await getEntries<FileSystemEntity>()) {
      try {
        await file.delete();
      } catch (error, stackTrace) {
        final exception = VaultException<dynamic>(
          'Failed to delete $file',
          stackTrace: stackTrace,
          error: error,
        );

        _vault.onError?.call(exception);
        throw exception;
      }
    }
  }

  @override
  Future<void> remove(VaultKey<dynamic> key) async {
    try {
      final file = getEntry<File>(key);

      if (!existsSync(key)) {
        return;
      }

      await file.delete();
    } on VaultException<dynamic> catch (e) {
      _vault.onError?.call(e);
      rethrow;
    } catch (error, stackTrace) {
      final exception = key.toException(
        'Failed to remove $key',
        error: error,
        stackTrace: stackTrace,
      );

      _vault.onError?.call(exception);
      throw exception;
    }
  }

  @override
  Future<List<E>> getEntries<E>() async {
    try {
      return (await _root.list().toList()).cast<E>();
    } catch (error, stackTrace) {
      final exception = VaultException<dynamic>(
        'Failed to get entries',
        stackTrace: stackTrace,
        error: error,
      );

      _vault.onError?.call(exception);
      throw exception;
    }
  }

  /// Synchronously reads the file content.
  ///
  /// This operation blocks the thread until the file is read.
  @override
  V? readSync<V>(VaultKey<dynamic> key) {
    final file = getEntry<File>(key);
    return jsonDecode(file.readAsStringSync()) as V?;
  }
}
