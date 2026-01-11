part of 'vault.dart';

/// Strongly-typed storage key bound to a specific Storage instance
class VaultKey<T> {
  VaultKey._({
    required this.vault,
    required this.name,
    required this.fromStorage,
    required this.toStorage,
    required this.useFileSystem,
    required this.removable,
  });

  final Vault vault;
  final String name;
  final bool useFileSystem;
  final bool removable;
  final T Function(dynamic value) fromStorage;
  final dynamic Function(T value) toStorage;

  VaultException toException(
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    return VaultException(
      message,
      key: this,
      error: error,
      stackTrace: stackTrace,
    );
  }

  /// Encrypts the raw string payload.
  /// Base implementation returns as-is (no encryption).
  Future<String> encrypt(String payload) async => payload;

  /// Decrypts the raw string payload.
  /// Base implementation returns as-is (no decryption).
  Future<String> decrypt(String payload) async => payload;

  Future<bool> get exists => vault.keyExists(this);

  Future<T?> read() => vault.readKey(this);
  Future<T> readSafe(T defaultValue) async => (await read()) ?? defaultValue;
  Future<void> write(T value) => vault.writeKey(this, value);
  Future<void> remove() => vault.removeKey(this);
  Future<void> update(T Function(T? currentValue) updateFn) async {
    final current = await read();
    final newVal = updateFn(current);
    await write(newVal);
  }

  Stream<T?> get stream => vault.listen(this);
}

/// Encrypted Variant of VaultKey
class SecureVaultKey<T> extends VaultKey<T> {
  SecureVaultKey._({
    required super.vault,
    required super.name,
    required super.fromStorage,
    required super.toStorage,
    required super.useFileSystem,
    required super.removable,
  }) : super._();

  @override
  Future<String> encrypt(String payload) async {
    // Uses compute for safer isolation (defined in encryption_utils.dart)
    return compute(_aesEncrypt, _EncryptPayload(payload, vault.secureKey));
  }

  @override
  Future<String> decrypt(String payload) async {
    // Uses compute for safer isolation (defined in encryption_utils.dart)
    return compute(_aesDecrypt, _EncryptPayload(payload, vault.secureKey));
  }
}
