part of 'keep.dart';

/// Handles binary encoding and decoding of Keep data structures.
///
/// The [KeepCodec] is responsible for serializing [KeepMemoryValue] objects into optimized binary formats
/// for both internal (single-file) and external (multi-file) storage.
///
/// It uses a **Binary Container** approach, where metadata (flags) and payload (data) are packed together.
/// The payload itself is a JSON-encoded string converted to UTF-8 bytes to ensure compatibility with
/// standard Dart types while maintaining the benefits of binary metadata.
class KeepCodec {
  /// Flag bitmask for **Removable** keys (Bit 0).
  ///
  /// If this bit is set (1), the key is effectively "lazy-loaded" and candidates for
  /// cleanup operations via [clearRemovable].
  static const int _flagRemovable = 1;

  /// Encodes a map of [KeepMemoryValue] objects into a single binary block (for Internal Storage).
  ///
  /// This method iterates through the registry and serializes each entry sequentially.
  ///
  /// # Binary Format Specification
  ///
  /// Each entry is stored in the following structure:
  ///
  /// ```text
  /// [Key Length] [Key Bytes] [Flags] [Value Length] [Value Payload]
  /// |   1 Byte  |  N Bytes  | 1 Byte|    4 Bytes   |     M Bytes     |
  /// ```
  ///
  /// - **Key Length (1 Byte):** The length of the key string in bytes. Keys are limited to 255 bytes.
  /// - **Key Bytes (N Bytes):** The UTF-8 encoded bytes of the key string.
  /// - **Flags (1 Byte):** A bitmask byte containing metadata (e.g., Removable bit).
  /// - **Value Length (4 Bytes):** The length of the value payload (Big Endian integer).
  /// - **Value Payload (M Bytes):** The UTF-8 encoded JSON string of the stored value.
  ///
  /// Total Logic: `KeyLen + Key + Flags + ValLen + Value`.
  static Uint8List encodeAll(Map<String, KeepMemoryValue> entries) {
    final buffer = BytesBuilder();

    entries.forEach((key, entry) {
      final keyBytes = utf8.encode(key);
      if (keyBytes.length > 255) {
        // Skip keys that exceed the 1-byte length limit (255 bytes).
        // This is a safety constraint for the internal storage format.
        return;
      }

      final jsonString = jsonEncode(entry.value);
      final valBytes = utf8.encode(jsonString);

      // 1. Key Length & Key
      buffer
        ..addByte(keyBytes.length)
        ..add(keyBytes);

      // 2. Flags
      // ignore: cascade_invocations
      buffer.addByte(entry.flags);

      // 3. Value Length (Big Endian 32-bit Integer)
      // We decompose the 32-bit integer into 4 separate bytes by shifting bits.
      // Example: If valLen is 0xAABBCCDD
      // 1. (>> 24) & 0xFF -> AA (Most Significant Byte)
      // 2. (>> 16) & 0xFF -> BB
      // 3. (>> 8)  & 0xFF -> CC
      // 4. (Last)  & 0xFF -> DD (Least Significant Byte)
      final valLen = valBytes.length;
      buffer
        ..addByte((valLen >> 24) & 0xFF)
        ..addByte((valLen >> 16) & 0xFF)
        ..addByte((valLen >> 8) & 0xFF)
        ..addByte(valLen & 0xFF);

      // 4. Value Payload
      // ignore: cascade_invocations
      buffer.add(valBytes);
    });

    return buffer.toBytes();
  }

  /// Decodes a binary block into a map of [KeepMemoryValue] objects (for Internal Storage).
  ///
  /// This method parses the binary stream sequentially, reconstructing the [KeepMemoryValue]
  /// objects with their associated metadata flags.
  ///
  /// It is robust against partial reads but assumes the binary integrity is valid up to the
  /// last complete entry.
  static Map<String, KeepMemoryValue> decodeAll(Uint8List bytes) {
    final map = <String, KeepMemoryValue>{};
    var offset = 0;

    while (offset < bytes.length) {
      // Safety check: Ensure at least 1 byte exists for Key Length
      if (offset + 1 > bytes.length) break;

      // 1. Read Key
      final keyLen = bytes[offset++];
      if (offset + keyLen > bytes.length) break;

      final key = utf8.decode(bytes.sublist(offset, offset + keyLen));
      offset += keyLen;

      // Safety check: Ensure at least 1 byte exists for Flags
      if (offset + 1 > bytes.length) break;

      // 2. Read Flags
      final flags = bytes[offset++];

      // Safety check: Ensure 4 bytes exist for Value Length
      if (offset + 4 > bytes.length) break;

      // 3. Read Value Length (Big Endian)
      // We reconstruct the 32-bit integer by reading 4 bytes and shifting them back.
      // 1. Shift 1st byte 24 bits left  (AA000000)
      // 2. Shift 2nd byte 16 bits left  (00BB0000)
      // 3. Shift 3rd byte 8 bits left   (0000CC00)
      // 4. Leave 4th byte as is         (000000DD)
      // OR (|) them all together -> 0xAABBCCDD
      final valLen =
          (bytes[offset] << 24) |
          (bytes[offset + 1] << 16) |
          (bytes[offset + 2] << 8) |
          (bytes[offset + 3]);
      offset += 4;

      if (offset + valLen > bytes.length) break;

      // 4. Read Value
      final jsonString = utf8.decode(bytes.sublist(offset, offset + valLen));
      final value = jsonDecode(jsonString);
      offset += valLen;

      map[key] = KeepMemoryValue(value, flags);
    }

    return map;
  }

  /// Encodes a single value with flags into a binary payload (for External Storage).
  ///
  /// Unlike internal storage, external storage files do not need to store the Key,
  /// as the filename serves that purpose.
  ///
  /// # Payload Structure
  /// ```text
  /// [Flags] [Value Payload]
  /// |1 Byte|    M Bytes    |
  /// ```
  static Uint8List encodePayload(dynamic value, int flags) {
    final buffer = BytesBuilder();
    final jsonString = jsonEncode(value);
    final valBytes = utf8.encode(jsonString);

    buffer
      ..addByte(flags)
      ..add(valBytes);

    return buffer.toBytes();
  }

  /// Decodes a binary payload into a [KeepMemoryValue] (for External Storage).
  ///
  /// Reads the first byte as flags and the rest as the JSON value.
  static KeepMemoryValue? decodePayload(Uint8List bytes) {
    if (bytes.isEmpty) return null;

    final flags = bytes[0];

    // Case: Only flags byte exists (Empty payload)
    if (bytes.length == 1) {
      return KeepMemoryValue(null, flags);
    }

    final valBytes = bytes.sublist(1);
    if (valBytes.isEmpty) return KeepMemoryValue(null, flags);

    try {
      final jsonString = utf8.decode(valBytes);
      final value = jsonDecode(jsonString);
      return KeepMemoryValue(value, flags);
    } catch (_) {
      // Return null on corruption to handle gracefully
      return null;
    }
  }
}
