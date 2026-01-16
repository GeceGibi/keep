part of 'utils.dart';

/// Handles binary encoding and decoding of Keep data structures.
class KeepCodec {
  /// Flag bitmask for **Removable** keys (Bit 0).
  @internal
  static const int flagRemovable = 1;

  /// Indicates that the payload is encrypted.
  @internal
  static const int flagSecure = 2;

  /// Encodes all entries into a single binary block (for Internal Storage).
  static Uint8List encodeAll(Map<String, KeepMemoryValue> entries) {
    final buffer = BytesBuilder();

    entries.forEach((key, entry) {
      final keyBytes = utf8.encode(key);
      if (keyBytes.length > 255) return;

      final jsonString = jsonEncode(entry.value);
      final valBytes = utf8.encode(jsonString);

      // [KeyLen] [Key] [Flags] [Version] [ValLen] [Value]
      buffer
        ..addByte(keyBytes.length)
        ..add(keyBytes)
        ..addByte(entry.flags)
        ..addByte(entry.version);

      final valLen = valBytes.length;
      buffer
        ..addByte((valLen >> 24) & 0xFF)
        ..addByte((valLen >> 16) & 0xFF)
        ..addByte((valLen >> 8) & 0xFF)
        ..addByte(valLen & 0xFF)
        // Add value
        ..add(valBytes);
    });

    return shiftBytes(buffer.toBytes());
  }

  /// Decodes a binary block into a map of entries (for Internal Storage).
  static Map<String, KeepMemoryValue> decodeAll(Uint8List bytes) {
    if (bytes.isEmpty) return {};

    final data = unShiftBytes(Uint8List.fromList(bytes));
    final map = <String, KeepMemoryValue>{};
    var offset = 0;

    while (offset < data.length) {
      if (offset + 1 > data.length) break;

      // 1. Read Key
      final keyLen = data[offset++];
      if (offset + keyLen > data.length) break;
      final key = utf8.decode(data.sublist(offset, offset + keyLen));
      offset += keyLen;

      // 2. Read Flags & Version
      if (offset + 2 > data.length) break;
      final flags = data[offset++];
      final version = data[offset++];

      // 3. Read Value Length
      if (offset + 4 > data.length) break;
      final valLen =
          ((data[offset] << 24) |
                  (data[offset + 1] << 16) |
                  (data[offset + 2] << 8) |
                  (data[offset + 3]))
              .toUnsigned(32);
      offset += 4;

      if (offset + valLen > data.length) break;

      // 4. Read Value
      final jsonString = utf8.decode(data.sublist(offset, offset + valLen));
      final value = jsonDecode(jsonString);
      offset += valLen;

      map[key] = KeepMigration.migrate(
        KeepMemoryValue(value, flags, version: version),
      );
    }

    return map;
  }

  /// Encodes a single payload (for External Storage).
  static Uint8List encodePayload(dynamic value, int flags) {
    final buffer = BytesBuilder();
    final jsonString = jsonEncode(value);
    final valBytes = utf8.encode(jsonString);

    // [Flags] [Version] [JSON]
    buffer
      ..addByte(flags)
      ..addByte(Keep.version)
      ..add(valBytes);

    return shiftBytes(buffer.toBytes());
  }

  /// Decodes a binary payload into a [KeepMemoryValue] (for External Storage).
  static KeepMemoryValue? decodePayload(Uint8List bytes) {
    if (bytes.isEmpty) {
      return null;
    }

    final data = unShiftBytes(bytes);
    if (data.length < 2) {
      return null;
    }

    final flags = data[0];
    final version = data[1];

    try {
      final jsonBytes = data.sublist(2);
      final jsonString = utf8.decode(jsonBytes);
      final value = jsonDecode(jsonString);

      return KeepMigration.migrate(
        KeepMemoryValue(value, flags, version: version),
      );
    } catch (_) {
      return null;
    }
  }

  /// Generates a non-reversible hash for a given [key] name using DJB2.
  /// Used for obfuscating filenames and internal map keys.
  static String generateHash(String key) {
    final bytes = utf8.encode(key);
    var hash = 5381;
    for (final byte in bytes) {
      hash = ((hash << 5) + hash) + byte;
    }
    return hash.toUnsigned(64).toRadixString(36);
  }

  /// Obfuscates bytes using a bitwise left rotation (ROL 1).
  static Uint8List shiftBytes(Uint8List bytes) {
    for (var i = 0; i < bytes.length; i++) {
      final b = bytes[i];
      bytes[i] = ((b << 1) | (b >> 7)) & 0xFF;
    }
    return Uint8List.fromList(bytes);
  }

  /// Reverses the bitwise rotation obfuscation (ROR 1).
  static Uint8List unShiftBytes(Uint8List bytes) {
    for (var i = 0; i < bytes.length; i++) {
      final b = bytes[i];
      bytes[i] = ((b >> 1) | (b << 7)) & 0xFF;
    }
    return bytes;
  }
}
