part of 'utils.dart';

/// Utility mixin for codec operations.
mixin KeepCodecUtils {
  /// Obfuscates bytes using a bitwise left rotation (ROL 1).
  ///
  /// Returns a freshly allocated [Uint8List]; the input buffer is not
  /// modified. Callers that need an in-place transform should copy the
  /// result back themselves.
  Uint8List shiftBytes(Uint8List bytes) {
    final out = Uint8List(bytes.length);
    for (var i = 0; i < bytes.length; i++) {
      final b = bytes[i];
      out[i] = ((b << 1) | (b >> 7)) & 0xFF;
    }
    return out;
  }

  /// Reverses the bitwise rotation obfuscation (ROR 1).
  ///
  /// Returns a freshly allocated [Uint8List]; the input buffer is not
  /// modified.
  Uint8List unShiftBytes(Uint8List bytes) {
    final out = Uint8List(bytes.length);
    for (var i = 0; i < bytes.length; i++) {
      final b = bytes[i];
      out[i] = ((b >> 1) | (b << 7)) & 0xFF;
    }
    return out;
  }

  /// Generates a non-reversible hash for a given [key] name using DJB2.
  /// Used for obfuscating filenames and internal map keys.
  String hash(String key) {
    final bytes = utf8.encode(key);

    var hash = 5381;
    for (final byte in bytes) {
      hash = ((hash << 5) + hash) + byte;
    }

    return hash.toUnsigned(64).toRadixString(36);
  }
}
