part of 'vault.dart';

/// Abstract base class for solid storage implementations (Files, Cloud, etc.).
///
abstract class VaultStorage {
  /// Creates a new instance of [VaultStorage].
  VaultStorage();

  /// Initializes the file vault with main [vault] instance.
  Future<void> init(Vault vault);

  /// Gets the raw file object for a given [key].
  F getFile<F>(VaultKey<dynamic> key);

  /// Reads content from file storage for [key].
  FutureOr<V?> read<V>(VaultKey<dynamic> key);

  /// Writes [value] to file storage for [key].
  FutureOr<void> write(VaultKey<dynamic> key, Object? value);

  /// Removes the file associated with [key].
  FutureOr<void> remove(VaultKey<dynamic> key);

  /// Checks if file exists for [key].
  FutureOr<bool> exists(VaultKey<dynamic> key);

  /// Returns list of all stored files.
  FutureOr<List<E>> getEntries<E>();

  /// Deletes all files in storage.
  FutureOr<void> clear();
}

/// Default implementation using standard [File] system.
class DefaultVaultExternalStorage extends VaultStorage {
  late Directory _root;

  @override
  Future<void> init(Vault vault) async {
    _root = Directory('${vault.root.path}/external');

    if (!_root.existsSync()) {
      await _root.create(recursive: true);
    }
  }

  @override
  F getFile<F>(VaultKey<dynamic> key) => File('${_root.path}/${key.name}') as F;

  @override
  Future<V?> read<V>(VaultKey<dynamic> key) async {
    final file = getFile<File>(key);

    if (!exists(key)) {
      return null;
    }

    return file.readAsString() as V?;
  }

  @override
  Future<void> remove(VaultKey<dynamic> key) async {
    final file = getFile<File>(key);

    if (!exists(key)) {
      return;
    }

    await file.delete();
  }

  @override
  Future<void> write(VaultKey<dynamic> key, dynamic value) async {
    await getFile<File>(key).writeAsString(value as String);
  }

  @override
  bool exists(VaultKey<dynamic> key) {
    return getFile<File>(key).existsSync();
  }

  @override
  Future<void> clear() async {
    for (final file in await getEntries<FileSystemEntity>()) {
      await file.delete();
    }
  }

  @override
  Future<List<E>> getEntries<E>() async {
    return (await _root.list().toList()).cast<E>();
  }
}
