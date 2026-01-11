part of 'vault.dart';

//Wrapper payloads for compute
class _EncryptPayload {
  final String content;
  final String keyStr;
  _EncryptPayload(this.content, this.keyStr);
}

String _aesEncrypt(_EncryptPayload p) {
  if (p.content.isEmpty) return p.content;

  final first = p.keyStr;
  final second = first.split('').reversed.join();
  final digest = sha256.convert(utf8.encode('$first.$second.${p.keyStr}'));
  final derivedKey = encrypt_lib.Key.fromUtf8(
    digest.toString().substring(0, 32),
  );
  final iv = encrypt_lib.IV.fromSecureRandom(16);
  final encrypter = encrypt_lib.Encrypter(encrypt_lib.AES(derivedKey));

  final encrypted = encrypter.encrypt(p.content, iv: iv);
  return base64Encode([...iv.bytes, ...encrypted.bytes]);
}

String _aesDecrypt(_EncryptPayload p) {
  if (p.content.isEmpty) return p.content;

  final first = p.keyStr;
  final second = first.split('').reversed.join();
  final digest = sha256.convert(utf8.encode('$first.$second.${p.keyStr}'));
  final derivedKey = encrypt_lib.Key.fromUtf8(
    digest.toString().substring(0, 32),
  );
  final encrypter = encrypt_lib.Encrypter(encrypt_lib.AES(derivedKey));

  try {
    final payload = base64Decode(p.content);
    final iv = encrypt_lib.IV(payload.sublist(0, 16));
    final encryptedData = encrypt_lib.Encrypted(payload.sublist(16));
    return encrypter.decrypt(encryptedData, iv: iv);
  } catch (_) {
    return '';
  }
}
