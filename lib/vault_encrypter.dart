part of 'vault.dart';

abstract class VaultEncrypter {
  const VaultEncrypter();

  Future<void> init();
  String encrypt(Object? data);
  String decrypt(String data);
}

class DefaultVaultEncrypter extends VaultEncrypter {
  DefaultVaultEncrypter({required this.secureKey})
    : assert(
        secureKey.length >= 32,
        'Secure key must be at least 32 characters long',
      );

  final String secureKey;
  late encrypt_lib.Encrypter encrypter;

  @override
  Future<void> init() async {
    encrypter = encrypt_lib.Encrypter(
      encrypt_lib.AES(
        encrypt_lib.Key.fromUtf8(secureKey.substring(0, 32)),
      ),
    );
  }

  @override
  String encrypt(Object? value) {
    final iv = encrypt_lib.IV.fromSecureRandom(16);
    final payload = jsonEncode(value);
    final encrypted = encrypter.encrypt(payload, iv: iv);
    return base64Encode([...iv.bytes, ...encrypted.bytes]);
  }

  @override
  String decrypt(String value) {
    final payload = base64Decode(value);
    final iv = encrypt_lib.IV(payload.sublist(0, 16));
    final encryptedData = encrypt_lib.Encrypted(payload.sublist(16));
    return encrypter.decrypt(encryptedData, iv: iv);
  }
}
