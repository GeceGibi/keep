part of 'key.dart';

/// Factory for creating typed [KeepKeyPlain] and [KeepKeySecure] instances.
///
/// Use [KeepKeyManager] to define your storage schema. It provides helpers
/// for common types and allows creating both plain and encrypted keys.
class KeepKeyManager {
  /// Creates a [KeepKeyManager] linked to a [Keep] instance.
  KeepKeyManager({required Keep keep}) : _keep = keep;
  final Keep _keep;

  /// Creates a standard [int] key.
  KeepKeyPlain<int> integer(
    String name, {
    bool removable = false,
    bool useExternalStorage = false,
  }) {
    return _keep.registerKey(
      name,
      () => KeepKeyPlain<int>(
        name: name,
        keep: _keep,
        removable: removable,
        useExternalStorage: useExternalStorage,
      ),
    );
  }

  /// Creates an encrypted [int] key.
  KeepKeySecure<int> integerSecure(
    String name, {
    bool removable = false,
    bool useExternalStorage = false,
  }) {
    return _keep.registerKey(
      KeepKeySecure.generateHash(name),
      () => KeepKeySecure<int>(
        name: name,
        keep: _keep,
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
  KeepKeyPlain<String> string(
    String name, {
    bool removable = false,
    bool useExternalStorage = false,
  }) {
    return _keep.registerKey(
      name,
      () => KeepKeyPlain<String>(
        name: name,
        keep: _keep,
        removable: removable,
        useExternalStorage: useExternalStorage,
      ),
    );
  }

  /// Creates an encrypted [String] key.
  KeepKeySecure<String> stringSecure(
    String name, {
    bool removable = false,
    bool useExternalStorage = false,
  }) {
    return _keep.registerKey(
      KeepKeySecure.generateHash(name),
      () => KeepKeySecure<String>(
        name: name,
        keep: _keep,
        removable: removable,
        useExternalStorage: useExternalStorage,
        toStorage: (value) => value,
        fromStorage: (value) => value?.toString(),
      ),
    );
  }

  /// Creates a standard [bool] key.
  KeepKeyPlain<bool> boolean(
    String name, {
    bool removable = false,
    bool useExternalStorage = false,
  }) {
    return _keep.registerKey(
      name,
      () => KeepKeyPlain<bool>(
        name: name,
        keep: _keep,
        removable: removable,
        useExternalStorage: useExternalStorage,
      ),
    );
  }

  /// Creates an encrypted [bool] key.
  KeepKeySecure<bool> booleanSecure(
    String name, {
    bool removable = false,
    bool useExternalStorage = false,
  }) {
    return _keep.registerKey(
      KeepKeySecure.generateHash(name),
      () => KeepKeySecure<bool>(
        name: name,
        keep: _keep,
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
  KeepKeyPlain<double> decimal(
    String name, {
    bool removable = false,
    bool useExternalStorage = false,
  }) {
    return _keep.registerKey(
      name,
      () => KeepKeyPlain<double>(
        name: name,
        keep: _keep,
        removable: removable,
        useExternalStorage: useExternalStorage,
      ),
    );
  }

  /// Creates an encrypted [double] key.
  KeepKeySecure<double> decimalSecure(
    String name, {
    bool removable = false,
    bool useExternalStorage = false,
  }) {
    return _keep.registerKey(
      KeepKeySecure.generateHash(name),
      () => KeepKeySecure<double>(
        name: name,
        keep: _keep,
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

  /// Creates a standard [Map] key.
  KeepKeyPlain<Map<String, dynamic>> map(
    String name, {
    bool removable = false,
    bool useExternalStorage = false,
  }) {
    return _keep.registerKey(
      name,
      () => KeepKeyPlain<Map<String, dynamic>>(
        name: name,
        keep: _keep,
        removable: removable,
        useExternalStorage: useExternalStorage,
      ),
    );
  }

  /// Creates an encrypted [Map] key.
  KeepKeySecure<Map<String, dynamic>> mapSecure(
    String name, {
    bool removable = false,
    bool useExternalStorage = false,
  }) {
    return _keep.registerKey(
      KeepKeySecure.generateHash(name),
      () => KeepKeySecure<Map<String, dynamic>>(
        name: name,
        keep: _keep,
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

  /// Creates a standard [List] key.
  KeepKeyPlain<List<T>> list<T>(
    String name, {
    bool removable = false,
    bool useExternalStorage = false,
  }) {
    return _keep.registerKey(
      name,
      () => KeepKeyPlain<List<T>>(
        name: name,
        keep: _keep,
        removable: removable,
        useExternalStorage: useExternalStorage,
      ),
    );
  }

  /// Creates an encrypted [List] key.
  KeepKeySecure<List<T>> listSecure<T>(
    String name, {
    bool removable = false,
    bool useExternalStorage = false,
  }) {
    return _keep.registerKey(
      KeepKeySecure.generateHash(name),
      () => KeepKeySecure<List<T>>(
        name: name,
        keep: _keep,
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

  /// Creates a custom encrypted key with specialized serialization.
  KeepKeySecure<T> custom<T>({
    required String name,
    required T? Function(Object? value) fromStorage,
    required Object? Function(T value) toStorage,
    bool removable = false,
    bool useExternalStorage = false,
  }) {
    return _keep.registerKey(
      KeepKeySecure.generateHash(name),
      () => KeepKeySecure<T>(
        name: name,
        keep: _keep,
        removable: removable,
        useExternalStorage: useExternalStorage,
        toStorage: toStorage,
        fromStorage: fromStorage,
      ),
    );
  }
}
