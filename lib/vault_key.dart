part of 'vault.dart';

class VaultKey<T> {
  VaultKey({
    required this.name,
    required this.vault,
    required this.fromStorage,
    required this.toStorage,
    this.removable = false,
    this.useExternalStorage = false,
  });

  final Vault vault;
  final String name;
  final bool removable;
  final bool useExternalStorage;

  final T? Function(Object? value) fromStorage;
  final Object? Function(T value) toStorage;

  VaultKey<T> call(Object? subKeyName) {
    return VaultKey<T>(
      name: '$name.$subKeyName',
      removable: removable,
      fromStorage: fromStorage,
      toStorage: toStorage,
      vault: vault,
      useExternalStorage: useExternalStorage,
    );
  }

  FutureOr<bool> get exists {
    if (useExternalStorage) {
      return vault.external.exists(this);
    }

    return vault.internal.exists(this);
  }

  Future<void> remove() async {
    if (useExternalStorage) {
      await vault.external.remove(this);
    } else {
      vault.internal.remove(this);
    }
  }

  Future<T> readSafe(T defaultValue) async {
    return (await read<T>()) ?? defaultValue;
  }

  /// Reads value from storage
  Future<V?> read<V>() async {
    try {
      return switch (useExternalStorage) {
        true => await vault.external.read(this),
        false => vault.internal.read(this),
      };
    } catch (e) {
      unawaited(remove());
      return null;
    }
  }

  /// Writes value to storage
  Future<void> write(Object? value) async {
    vault._controller.add(this);

    if (value == null) {
      await remove();
      return;
    }

    try {
      if (useExternalStorage) {
        await vault.external.write(this, value);
      } else {
        vault.internal.write(this, value);
      }
    } catch (e) {}
  }

  /// Updates the stored value using a callback function.
  Future<void> update(T Function(T? currentValue) updateFn) async {
    final currentValue = await read<T>();
    final newValue = updateFn(currentValue);

    await write(newValue);
  }

  Stream<VaultKey<T>> get stream {
    return vault.onChange.where((key) => key.name == name).cast<VaultKey<T>>();
  }
}
