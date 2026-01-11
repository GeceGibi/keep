part of 'vault.dart';

/// Builder for creating standard (non-encrypted) storage keys
class KeyCreator {
  KeyCreator(this._vault);
  final Vault _vault;

  VaultKey<String> string(
    String name, {
    bool useFileSystem = false,
    bool removable = false,
  }) => _create(name, (v) => v as String, (v) => v, useFileSystem, removable);

  VaultKey<int> integer(
    String name, {
    bool useFileSystem = false,
    bool removable = false,
  }) => _create(
    name,
    (v) => v is int ? v : int.parse(v.toString()),
    (v) => v,
    useFileSystem,
    removable,
  );

  VaultKey<double> decimal(
    String name, {
    bool useFileSystem = false,
    bool removable = false,
  }) => _create(
    name,
    (v) => v is double ? v : double.parse(v.toString()),
    (v) => v,
    useFileSystem,
    removable,
  );

  VaultKey<bool> boolean(
    String name, {
    bool useFileSystem = false,
    bool removable = false,
  }) => _create(
    name,
    (v) => v is bool ? v : v.toString() == 'true',
    (v) => v,
    useFileSystem,
    removable,
  );

  VaultKey<List<T>> list<T>(
    String name, {
    bool useFileSystem = false,
    bool removable = false,
  }) => _create(
    name,
    (v) => (v as List).cast<T>(),
    (v) => v,
    useFileSystem,
    removable,
  );

  VaultKey<Map<K, V>> map<K, V>(
    String name, {
    bool useFileSystem = false,
    bool removable = false,
  }) => _create(
    name,
    (v) => (v as Map).cast<K, V>(),
    (v) => v,
    useFileSystem,
    removable,
  );

  VaultKey<T> custom<T>(
    String name, {
    required T Function(dynamic) fromStorage,
    required dynamic Function(T) toStorage,
    bool useFileSystem = false,
    bool removable = false,
  }) => _create(name, fromStorage, toStorage, useFileSystem, removable);

  VaultKey<T> _create<T>(
    String name,
    T Function(dynamic) fromStorage,
    dynamic Function(T) toStorage,
    bool useFileSystem,
    bool removable,
  ) {
    final key = VaultKey<T>._(
      vault: _vault,
      name: name,
      fromStorage: fromStorage,
      toStorage: toStorage,
      useFileSystem: useFileSystem,
      removable: removable,
    );
    _vault._register(key);
    return key;
  }
}

/// Builder for creating encrypted (secure) storage keys
class SecureKeyCreator {
  SecureKeyCreator(this._vault);
  final Vault _vault;

  SecureVaultKey<String> string(
    String name, {
    bool useFileSystem = false,
    bool removable = false,
  }) => _create(name, (v) => v as String, (v) => v, useFileSystem, removable);

  SecureVaultKey<int> integer(
    String name, {
    bool useFileSystem = false,
    bool removable = false,
  }) => _create(
    name,
    (v) => v is int ? v : int.parse(v.toString()),
    (v) => v,
    useFileSystem,
    removable,
  );

  SecureVaultKey<double> decimal(
    String name, {
    bool useFileSystem = false,
    bool removable = false,
  }) => _create(
    name,
    (v) => v is double ? v : double.parse(v.toString()),
    (v) => v,
    useFileSystem,
    removable,
  );

  SecureVaultKey<bool> boolean(
    String name, {
    bool useFileSystem = false,
    bool removable = false,
  }) => _create(
    name,
    (v) => v is bool ? v : v.toString() == 'true',
    (v) => v,
    useFileSystem,
    removable,
  );

  SecureVaultKey<List<T>> list<T>(
    String name, {
    bool useFileSystem = false,
    bool removable = false,
  }) => _create(
    name,
    (v) => (v as List).cast<T>(),
    (v) => v,
    useFileSystem,
    removable,
  );

  SecureVaultKey<Map<K, V>> map<K, V>(
    String name, {
    bool useFileSystem = false,
    bool removable = false,
  }) => _create(
    name,
    (v) => (v as Map).cast<K, V>(),
    (v) => v,
    useFileSystem,
    removable,
  );

  SecureVaultKey<T> custom<T>(
    String name, {
    required T Function(dynamic) fromStorage,
    required dynamic Function(T) toStorage,
    bool useFileSystem = false,
    bool removable = false,
  }) => _create(name, fromStorage, toStorage, useFileSystem, removable);

  SecureVaultKey<T> _create<T>(
    String name,
    T Function(dynamic) fromStorage,
    dynamic Function(T) toStorage,
    bool useFileSystem,
    bool removable,
  ) {
    final key = SecureVaultKey<T>._(
      vault: _vault,
      name: name,
      fromStorage: fromStorage,
      toStorage: toStorage,
      useFileSystem: useFileSystem,
      removable: removable,
    );
    _vault._register(key);
    return key;
  }
}
