part of 'vault.dart';

/// Factory for creating typed [VaultKey] and [VaultKeySecure] instances.
///
/// Access via [Vault.key] to create storage keys with built-in serialization.
class VaultKeyManager {
  /// Creates a [VaultKeyManager] linked to a [vault].
  VaultKeyManager({required Vault vault}) : _vault = vault;
  final Vault _vault;

  /// Creates a standard [int] key.
  VaultKey<int> integer(
    String name, {
    bool removable = false,
    bool useExternalStorage = false,
  }) {
    return _vault._registerKey(
      name,
      () => VaultKey<int>(
        name: name,
        vault: _vault,
        removable: removable,
        useExternalStorage: useExternalStorage,
      ),
    );
  }

  /// Creates an encrypted [int] key using [VaultKeySecure].
  VaultKeySecure<int> integerSecure(
    String name, {
    bool removable = false,
    bool useExternalStorage = false,
  }) {
    return _vault._registerKey(
      VaultKeySecure.generateHash(name),
      () => VaultKeySecure<int>(
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
      ),
    );
  }

  /// Creates a standard [String] key.
  VaultKey<String> string(
    String name, {
    bool removable = false,
    bool useExternalStorage = false,
  }) {
    return _vault._registerKey(
      name,
      () => VaultKey<String>(
        name: name,
        vault: _vault,
        removable: removable,
        useExternalStorage: useExternalStorage,
      ),
    );
  }

  /// Creates an encrypted [String] key using [VaultKeySecure].
  VaultKeySecure<String> stringSecure(
    String name, {
    bool removable = false,
    bool useExternalStorage = false,
  }) {
    return _vault._registerKey(
      VaultKeySecure.generateHash(name),
      () => VaultKeySecure<String>(
        name: name,
        vault: _vault,
        removable: removable,
        useExternalStorage: useExternalStorage,
        toStorage: (value) => value,
        fromStorage: (value) => value?.toString(),
      ),
    );
  }

  /// Creates a standard [bool] key.
  VaultKey<bool> boolean(
    String name, {
    bool removable = false,
    bool useExternalStorage = false,
  }) {
    return _vault._registerKey(
      name,
      () => VaultKey<bool>(
        name: name,
        vault: _vault,
        removable: removable,
        useExternalStorage: useExternalStorage,
      ),
    );
  }

  /// Creates an encrypted [bool] key using [VaultKeySecure].
  VaultKeySecure<bool> booleanSecure(
    String name, {
    bool removable = false,
    bool useExternalStorage = false,
  }) {
    return _vault._registerKey(
      VaultKeySecure.generateHash(name),
      () => VaultKeySecure<bool>(
        name: name,
        vault: _vault,
        removable: removable,
        useExternalStorage: useExternalStorage,
        toStorage: (value) => value,
        fromStorage: (value) {
          return switch (value) {
            bool() => value,
            String() => value == 'true',
            _ => null,
          };
        },
      ),
    );
  }

  /// Creates a standard [double] key.
  VaultKey<double> decimal(
    String name, {
    bool removable = false,
    bool useExternalStorage = false,
  }) {
    return _vault._registerKey(
      name,
      () => VaultKey<double>(
        name: name,
        vault: _vault,
        removable: removable,
        useExternalStorage: useExternalStorage,
      ),
    );
  }

  /// Creates an encrypted [double] key using [VaultKeySecure].
  VaultKeySecure<double> decimalSecure(
    String name, {
    bool removable = false,
    bool useExternalStorage = false,
  }) {
    return _vault._registerKey(
      VaultKeySecure.generateHash(name),
      () => VaultKeySecure<double>(
        name: name,
        vault: _vault,
        removable: removable,
        useExternalStorage: useExternalStorage,
        toStorage: (value) => value,
        fromStorage: (value) {
          return switch (value) {
            double() => value,
            int() => value.toDouble(),
            String() => double.parse(value),
            _ => null,
          };
        },
      ),
    );
  }

  /// Creates a [Map<String, dynamic>] key.
  VaultKey<Map<String, dynamic>> map(
    String name, {
    bool removable = false,
    bool useExternalStorage = false,
  }) {
    return _vault._registerKey(
      name,
      () => VaultKey<Map<String, dynamic>>(
        name: name,
        vault: _vault,
        removable: removable,
        useExternalStorage: useExternalStorage,
      ),
    );
  }

  /// Creates an encrypted [Map<String, dynamic>] key.
  VaultKeySecure<Map<String, dynamic>> mapSecure(
    String name, {
    bool removable = false,
    bool useExternalStorage = false,
  }) {
    return _vault._registerKey(
      VaultKeySecure.generateHash(name),
      () => VaultKeySecure<Map<String, dynamic>>(
        name: name,
        vault: _vault,
        removable: removable,
        useExternalStorage: useExternalStorage,
        toStorage: (value) => value,
        fromStorage: (value) {
          return switch (value) {
            Map() => value.cast<String, dynamic>(),
            _ => null,
          };
        },
      ),
    );
  }

  /// Creates a [List<T>] key.
  VaultKey<List<T>> list<T>(
    String name, {
    bool removable = false,
    bool useExternalStorage = false,
  }) {
    return _vault._registerKey(
      name,
      () => VaultKey<List<T>>(
        name: name,
        vault: _vault,
        removable: removable,
        useExternalStorage: useExternalStorage,
      ),
    );
  }

  /// Creates an encrypted [List<T>] key.
  VaultKeySecure<List<T>> listSecure<T>(
    String name, {
    bool removable = false,
    bool useExternalStorage = false,
  }) {
    return _vault._registerKey(
      VaultKeySecure.generateHash(name),
      () => VaultKeySecure<List<T>>(
        name: name,
        vault: _vault,
        removable: removable,
        useExternalStorage: useExternalStorage,
        toStorage: (value) => value,
        fromStorage: (value) {
          return switch (value) {
            List() => value.cast<T>(),
            _ => null,
          };
        },
      ),
    );
  }

  /// Creates a custom encrypted key with serialization.
  VaultKeySecure<T> custom<T>({
    required String name,
    required T? Function(Object? value) fromStorage,
    required Object? Function(T value) toStorage,
    bool removable = false,
    bool useExternalStorage = false,
  }) {
    return _vault._registerKey(
      VaultKeySecure.generateHash(name),
      () => VaultKeySecure<T>(
        name: name,
        vault: _vault,
        removable: removable,
        useExternalStorage: useExternalStorage,
        toStorage: toStorage,
        fromStorage: fromStorage,
      ),
    );
  }
}
