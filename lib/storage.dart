part of 'vault.dart';

abstract class FileVaultBase {
  // Removed const constructor to allow dynamic root resolution
  // FileVaultBase({required this.root});

  // Abstract getter, must be implemented or resolved
  Directory get root;

  /// Error handler callback
  void Function(Object error, StackTrace stackTrace)? onError;

  Future<void> init();
  Future<void> clear();
  Future<bool> exists(String key);
  Future<String?> read(String key);
  Future<void> write(String key, List<int> content);
  Future<void> remove(String key);
  Future<List<FileSystemEntity>> getFiles();
}

class DefaultFileVault extends FileVaultBase {
  DefaultFileVault({Directory? root}) : _root = root;

  Directory? _root;

  @override
  Directory get root => _root!;

  @override
  Future<void> init() async {
    try {
      // If root is not provided, resolve safe location
      if (_root == null) {
        final appDir = await getApplicationSupportDirectory();
        _root = Directory('${appDir.path}/vault');
      }

      if (!_root!.existsSync()) {
        await _root!.create(recursive: true);
      }
    } catch (e, s) {
      onError?.call('Failed to initialize or resolve root directory', s);
      rethrow;
    }
  }

  File getFile(String key) {
    String? fileName;

    try {
      fileName = md5.convert(utf8.encode(key)).toString();
    } catch (e, s) {
      onError?.call('Error generating file hash for key: $key', s);
      fileName = '${key.hashCode}';
    }

    return File('${root.path}/$fileName');
  }

  @override
  Future<bool> exists(String key) async {
    try {
      return getFile(key).existsSync();
    } catch (e, s) {
      onError?.call('Exists check failed for key: $key', s);
      return false;
    }
  }

  @override
  Future<String?> read(String key) async {
    try {
      final file = getFile(key);
      if (!file.existsSync()) {
        return null;
      }
      return file.readAsStringSync();
    } catch (e, s) {
      onError?.call('Read failed for key: $key', s);
      return null;
    }
  }

  @override
  Future<void> write(String key, List<int> content) async {
    try {
      final file = getFile(key);
      await file.writeAsBytes(content);
    } catch (e, s) {
      onError?.call('Write failed for key: $key', s);
    }
  }

  @override
  Future<void> remove(String key) async {
    try {
      final file = getFile(key);
      if (file.existsSync()) {
        await file.delete();
      }
    } catch (e, s) {
      onError?.call('Remove failed for key: $key', s);
    }
  }

  @override
  Future<void> clear() async {
    try {
      final files = await getFiles();
      for (final file in files) {
        if (file is File) {
          try {
            await file.delete();
          } catch (e, s) {
            onError?.call('Failed to delete file: ${file.path}', s);
            continue;
          }
        }
      }
    } catch (e, s) {
      onError?.call('Clear failed', s);
    }
  }

  @override
  Future<List<FileSystemEntity>> getFiles() async {
    try {
      return root.list(recursive: true).toList();
    } catch (e, s) {
      onError?.call('GetFiles failed', s);
      return [];
    }
  }
}
