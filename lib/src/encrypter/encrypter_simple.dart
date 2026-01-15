part of 'encrypter.dart';

/// Default XOR-based implementation of [KeepEncrypter].
///
/// This provides basic obfuscation (not strong encryption).
/// For sensitive data, implement [KeepEncrypter] with AES-GCM or use
/// platform-native secure storage.
class SimpleKeepEncrypter extends KeepEncrypter {
  /// Creates a [SimpleKeepEncrypter].
  ///
  /// [secureKey] is the key used for XOR obfuscation.
  SimpleKeepEncrypter({required this.secureKey});

  /// The key used for XOR obfuscation.
  final String secureKey;

  @override
  Future<void> init() async {}

  @override
  String encrypt(String data) => encryptSync(data);

  @override
  String encryptSync(String data) {
    final result = <int>[];
    for (var i = 0; i < data.length; i++) {
      result.add(
        data.codeUnitAt(i) ^ secureKey.codeUnitAt(i % secureKey.length),
      );
    }
    return base64Encode(result);
  }

  @override
  String decrypt(String data) => decryptSync(data);

  @override
  String decryptSync(String data) {
    final bytes = base64Decode(data);
    final result = <int>[];
    for (var i = 0; i < bytes.length; i++) {
      result.add(bytes[i] ^ secureKey.codeUnitAt(i % secureKey.length));
    }
    return String.fromCharCodes(result);
  }
}
