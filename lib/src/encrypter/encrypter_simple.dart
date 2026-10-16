part of 'encrypter.dart';

/// Default XOR-based implementation of [KeepEncrypter].
///
/// This provides basic obfuscation (not strong encryption).
/// For sensitive data, implement [KeepEncrypter] with AES-GCM or use
/// platform-native secure storage.
class SimpleKeepEncrypter extends KeepEncrypter {
  /// Creates a [SimpleKeepEncrypter].
  ///
  /// [secureKey] is the key used for XOR obfuscation. Must be at least
  /// 8 characters long. Note that this class only provides basic
  /// obfuscation; for sensitive data use a real cipher (e.g. AES-GCM).
  SimpleKeepEncrypter({required this.secureKey})
    : assert(
        secureKey.length >= 8,
        'SimpleKeepEncrypter.secureKey must be at least 8 characters long.',
      );

  /// The key used for XOR obfuscation.
  final String secureKey;

  @override
  Future<void> init() async {}

  @override
  String encrypt(String data) => encryptSync(data);

  @override
  String encryptSync(String data) {
    final dataBytes = utf8.encode(data);
    final keyBytes = utf8.encode(secureKey);
    final result = Uint8List(dataBytes.length);
    for (var i = 0; i < dataBytes.length; i++) {
      result[i] = dataBytes[i] ^ keyBytes[i % keyBytes.length];
    }
    return base64Encode(result);
  }

  @override
  String decrypt(String data) => decryptSync(data);

  @override
  String decryptSync(String data) {
    final bytes = base64Decode(data);
    final keyBytes = utf8.encode(secureKey);
    final result = Uint8List(bytes.length);
    for (var i = 0; i < bytes.length; i++) {
      result[i] = bytes[i] ^ keyBytes[i % keyBytes.length];
    }
    return utf8.decode(result);
  }
}
