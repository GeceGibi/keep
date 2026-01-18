part of 'utils.dart';

/// Handles binary encoding and decoding of Keep data structures.
class KeepCodec {
  /// Flag bitmask for **Removable** keys (Bit 0).
  @internal
  static const int flagRemovable = 1;

  /// Indicates that the payload is encrypted.
  @internal
  static const int flagSecure = 2;

  /// Infers the [KeepType] from a dynamic value.
  static KeepType inferType(Object? value) {
    return switch (value) {
      int() => .tInt,
      double() => .tDouble,
      bool() => .tBool,
      String() => .tString,
      Uint8List() => .tBytes,
      List() => .tList,
      Map() => .tMap,
      _ => .tNull,
    };
  }

  /// Encodes all entries into a single binary block (for Internal Storage).
  static Uint8List encodeAll(Map<String, KeepMemoryValue> entries) {
    try {
      final buffer = BytesBuilder();

      entries.forEach((storeName, entry) {
        // Encode the payload with StoreName inside (Double shifting happens here)
        final payloadBytes = encode(
          storeName: storeName,
          keyName: entry.name,
          flags: entry.flags,
          value: entry.value,
        );

        final payloadLen = payloadBytes.length;

        // Internal Format: [PayloadLen(4)] [PayloadBytes(N)]
        buffer
          ..addByte((payloadLen >> 24) & 0xFF)
          ..addByte((payloadLen >> 16) & 0xFF)
          ..addByte((payloadLen >> 8) & 0xFF)
          ..addByte(payloadLen & 0xFF)
          ..add(payloadBytes);
      });

      // Shift the entire block at once
      return shiftBytes(buffer.toBytes());
    } catch (error, stackTrace) {
      throw KeepException<dynamic>(
        'Failed to encode batch of entries',
        stackTrace: stackTrace,
        error: error,
      );
    }
  }

  /// Decodes a binary block into a map of entries (for Internal Storage).
  static Map<String, KeepMemoryValue> decodeAll(Uint8List bytes) {
    if (bytes.isEmpty) return {};

    try {
      final data = unShiftBytes(Uint8List.fromList(bytes));
      final map = <String, KeepMemoryValue>{};
      var offset = 0;

      while (offset < data.length) {
        // Read Payload Length
        if (offset + 4 > data.length) break;
        final payloadLen =
            ((data[offset] << 24) |
                    (data[offset + 1] << 16) |
                    (data[offset + 2] << 8) |
                    (data[offset + 3]))
                .toUnsigned(32);
        offset += 4;

        if (offset + payloadLen > data.length) break;

        // Read Payload
        final payloadBytes = data.sublist(offset, offset + payloadLen);
        final entry = decode(payloadBytes);

        if (entry != null) {
          map[entry.storeName] = entry;
        }

        offset += payloadLen;
      }

      return map;
    } catch (error, stackTrace) {
      throw KeepException<dynamic>(
        'Failed to decode batch of entries',
        stackTrace: stackTrace,
        error: error,
      );
    }
  }

  /// Encodes a single payload
  static Uint8List encode({
    required String storeName,
    required String keyName,
    required int flags,
    required dynamic value,
  }) {
    try {
      final buffer = BytesBuilder();
      final jsonString = jsonEncode(value);
      final valBytes = utf8.encode(jsonString);
      final keyNameBytes = utf8.encode(keyName);
      final storeNameBytes = utf8.encode(storeName);

      if (keyNameBytes.length > 255) {
        throw KeepException<dynamic>('Key name too long: $keyName');
      }

      if (storeNameBytes.length > 255) {
        throw KeepException<dynamic>('Store name too long: $storeName');
      }

      // FORMAT:
      // [StoreNameLen(1)]
      // [StoreNameBytes(N)]
      // [NameLen(1)]
      // [NameBytes(N)]
      // [Flags(1)]
      // [Version(1)]
      // [Type(1)]
      // [JSON(N)]

      final type = inferType(value);

      buffer
        ..addByte(storeNameBytes.length)
        ..add(storeNameBytes)
        ..addByte(keyNameBytes.length)
        ..add(keyNameBytes)
        ..addByte(flags)
        ..addByte(Keep.version)
        ..addByte(type.byte)
        ..add(valBytes);

      return shiftBytes(buffer.toBytes());
    } catch (error, stackTrace) {
      throw KeepException<dynamic>(
        'Failed to encode payload',
        stackTrace: stackTrace,
        error: error,
      );
    }
  }

  /// Decodes a binary payload into a [KeepMemoryValue].
  static KeepMemoryValue? decode(Uint8List bytes) {
    if (bytes.isEmpty) return null;

    try {
      // Un-shift first
      final data = unShiftBytes(Uint8List.fromList(bytes));

      if (data.length < 5) {
        // Min: StoreLen(1) + NameLen(1) + Flags(1) + Ver(1) + Type(1) = 5
        return null;
      }

      var offset = 0;

      // 1. Read Store Name
      final storeNameLen = data[offset++];
      if (offset + storeNameLen > data.length) return null;
      final storeName = utf8.decode(
        data.sublist(offset, offset + storeNameLen),
      );
      offset += storeNameLen;

      // 2. Read Original Key Name
      if (offset + 1 > data.length) return null;
      final nameLen = data[offset++];
      if (offset + nameLen > data.length) return null;
      final originalKey = utf8.decode(data.sublist(offset, offset + nameLen));
      offset += nameLen;

      // 3. Read Metadata
      if (offset + 3 > data.length) return null;
      final flags = data[offset++];
      final version = data[offset++];
      final type = data[offset++];

      // 4. Read JSON Value
      final jsonBytes = data.sublist(offset);
      final jsonString = utf8.decode(jsonBytes);
      final value = jsonDecode(jsonString);

      return KeepMigration.migrate(
        KeepMemoryValue(
          value: value,
          flags: flags,
          name: originalKey,
          storeName: storeName,
          version: version,
          type: KeepType.fromByte(type),
        ),
      );
    } catch (error) {
      // Ignore legacy format or corrupted data
      return null;
    }
  }

  /// Parses header metadata from unshifted content bytes.
  ///
  /// Returns a record with (storeName, name, flags) or null if parsing fails.
  /// This is useful for reading metadata without fully decoding the payload.
  static ({String storeName, String name, int flags})? parseHeader(
    Uint8List unShiftedData,
  ) {
    if (unShiftedData.length < 5) {
      // Min: StoreLen(1) + NameLen(1) + Flags(1) + Ver(1) + Type(1) = 5
      return null;
    }

    try {
      var offset = 0;

      // 1. Read StoreName
      final storeNameLen = unShiftedData[offset++];
      if (offset + storeNameLen > unShiftedData.length) return null;

      final storeName = utf8.decode(
        unShiftedData.sublist(offset, offset + storeNameLen),
      );
      offset += storeNameLen;

      // 2. Read Original Name
      if (offset + 1 > unShiftedData.length) return null;
      final nameLen = unShiftedData[offset++];
      if (offset + nameLen > unShiftedData.length) return null;

      final name = utf8.decode(unShiftedData.sublist(offset, offset + nameLen));
      offset += nameLen;

      // 3. Read Flags
      if (offset >= unShiftedData.length) return null;
      final flags = unShiftedData[offset];

      return (storeName: storeName, name: name, flags: flags);
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
