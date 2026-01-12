part of 'vault.dart';

/// Abstract base class for solid storage implementations (Files, Cloud, etc.).
abstract class VaultStorage {
  /// Creates a new instance of [VaultStorage].
  VaultStorage();

  /// Initializes the storage adapter with the main [vault] instance.
  Future<void> init(Vault vault);

  /// Gets the raw storage object (e.g., [File]) for a given [key].
  F getEntry<F>(VaultKey<dynamic> key);

  /// Synchronously reads content from storage.
  ///
  /// This bypasses the async queue for external storage and may block the UI thread.
  V? readSync<V>(VaultKey<dynamic> key);

  /// Reads content from storage for the specified [key].
  FutureOr<V?> read<V>(VaultKey<dynamic> key);

  /// Writes [value] to storage for the specified [key].
  FutureOr<void> write(VaultKey<dynamic> key, Object? value);

  /// Removes the entry associated with [key].
  FutureOr<void> remove(VaultKey<dynamic> key);

  /// Checks if an entry exists for [key].
  FutureOr<bool> exists(VaultKey<dynamic> key);

  /// Synchronously checks if an entry exists for [key].
  bool existsSync(VaultKey<dynamic> key);

  /// Returns a list of all raw entries in this storage.
  FutureOr<List<E>> getEntries<E>();

  /// Scans the storage and removes all entries marked with the **Removable** flag.
  ///
  /// Implementations should respect the binary metadata flag (Bit 0) ensuring
  /// efficient cleanup of temporary data without full content parsing.
  Future<void> clearRemovable();

  /// Deletes all entries in this storage instance.
  FutureOr<void> clear();
}
