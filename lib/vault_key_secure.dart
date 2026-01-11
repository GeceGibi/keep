part of 'vault.dart';

class VaultKeySecure<T> extends VaultKey<T> {
  VaultKeySecure({
    required super.name,
    required super.vault,
    required super.fromStorage,
    required super.toStorage,
    required super.removable,
    required super.useExternalStorage,
  });

  @override
  String get name => base64Encode(utf8.encode(super.name));

  @override
  Future<V?> read<V>() async {
    final data = await super.read<String>();

    if (data == null) {
      return null;
    }

    final decrypted = vault.encrypter.decrypt(data);
    final json = jsonDecode(decrypted);
    return fromStorage(json) as V?;
  }

  @override
  Future<void> write(Object? value) async {
    final storageValue = toStorage(value as T);
    final jsonStr = jsonEncode(storageValue);
    final encrypted = vault.encrypter.encrypt(jsonStr);
    await super.write(encrypted);
  }
}
