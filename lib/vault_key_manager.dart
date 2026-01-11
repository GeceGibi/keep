part of 'vault.dart';

class VaultKeyManager {
  VaultKeyManager({required Vault vault}) : _vault = vault;
  final Vault _vault;

  VaultKey<T> custom<T>({
    required String name,
    required T Function(Object? value) fromStorage,
    required T Function(T value) toStorage,
  }) {
    return VaultKey<T>(
      name: name,
      vault: _vault,
      toStorage: toStorage,
      fromStorage: fromStorage,
    );
  }

  VaultKey<int> integer(
    String name, {
    bool removable = false,
    bool useExternalStorage = false,
  }) {
    return VaultKey<int>(
      name: name,
      vault: _vault,
      removable: removable,
      useExternalStorage: useExternalStorage,
      toStorage: (value) => value,
      fromStorage: (value) => value as int?,
    );
  }

  VaultKeySecure<int> integerSecure(
    String name, {
    bool removable = false,
    bool useExternalStorage = false,
  }) {
    return VaultKeySecure<int>(
      name: name,
      vault: _vault,
      removable: removable,
      useExternalStorage: useExternalStorage,
      toStorage: (value) => value,
      fromStorage: (value) {
        return switch (value) {
          int() => value,
          String() => int.parse(value),
          _ => null,
        };
      },
    );
  }
}
