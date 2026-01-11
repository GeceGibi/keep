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

  VaultKey<int> integer(String name) {
    return VaultKey<int>(
      name: name,
      vault: _vault,
      toStorage: (value) => value,
      fromStorage: (value) {
        return switch (value) {
          int() => value,
          double() => value.toInt(),
          String() => int.parse(value),
          _ => null,
        };
      },
    );
  }

  VaultKey<double> decimal(String name) {
    return VaultKey<double>(
      name: name,
      vault: _vault,
      toStorage: (value) => value,
      fromStorage: (value) {
        return switch (value) {
          int() => value.toDouble(),
          double() => value,
          String() => double.parse(value),
          _ => null,
        };
      },
    );
  }
}
