part of 'codec.dart';

/// Version 1 migration codec - the original Keep storage format.
///
/// This codec passes data through without modification, representing
/// the baseline storage format.
class KeepCodecV1 extends KeepCodec {
  KeepCodecV1._();

  @override
  int get version => 1;

  @override
  KeepMemoryValue? decode(Uint8List bytes) {
    if (bytes.isEmpty) return null;

    try {
      // Un-shift first
      final data = KeepCodec.unShiftBytes(Uint8List.fromList(bytes));

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

      if (value == null) {
        return null;
      }

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

  @override
  Map<String, KeepMemoryValue> decodeAll(Uint8List bytes) {
    if (bytes.isEmpty) return {};

    try {
      final data = KeepCodec.unShiftBytes(Uint8List.fromList(bytes));
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

  @override
  Uint8List? encode({
    required String storeName,
    required String keyName,
    required dynamic value,
    required int flags,
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

      final type = KeepType.inferType(value);

      buffer
        ..addByte(storeNameBytes.length)
        ..add(storeNameBytes)
        ..addByte(keyNameBytes.length)
        ..add(keyNameBytes)
        ..addByte(flags)
        ..addByte(Keep.version)
        ..addByte(type.byte)
        ..add(valBytes);

      return KeepCodec.shiftBytes(buffer.toBytes());
    } catch (error, stackTrace) {
      throw KeepException<dynamic>(
        'Failed to encode payload',
        stackTrace: stackTrace,
        error: error,
      );
    }
  }

  @override
  Uint8List encodeAll(Map<String, KeepMemoryValue> entries) {
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

        if (payloadBytes == null) {
          return;
        }

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
      return KeepCodec.shiftBytes(buffer.toBytes());
    } catch (error, stackTrace) {
      throw KeepException<dynamic>(
        'Failed to encode batch of entries',
        stackTrace: stackTrace,
        error: error,
      );
    }
  }

  @override
  KeepHeader? header(Uint8List bytes) {
    if (bytes.length < 5) {
      // Min: StoreLen(1) + NameLen(1) + Flags(1) + Ver(1) + Type(1) = 5
      return null;
    }

    try {
      var offset = 0;

      // 1. Read StoreName
      final storeNameLen = bytes[offset++];
      if (offset + storeNameLen > bytes.length) return null;

      final storeName = utf8.decode(
        bytes.sublist(offset, offset + storeNameLen),
      );
      offset += storeNameLen;

      // 2. Read Original Name
      if (offset + 1 > bytes.length) return null;
      final nameLen = bytes[offset++];
      if (offset + nameLen > bytes.length) return null;

      final name = utf8.decode(bytes.sublist(offset, offset + nameLen));
      offset += nameLen;

      // 3. Read Metadata
      if (offset + 2 >= bytes.length) return null;
      final flags = bytes[offset++];
      final version = bytes[offset++];
      final typeByte = bytes[offset++];

      return KeepHeader(
        type: KeepType.fromByte(typeByte),
        storeName: storeName,
        version: version,
        flags: flags,
        name: name,
      );
    } catch (_) {
      return null;
    }
  }
}
