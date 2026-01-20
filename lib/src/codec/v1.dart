part of 'codec.dart';

/// Version 1 codec - the baseline Keep storage format.
///
/// **Binary Format:**
/// ```
/// [Version(1)][Flags(1)][Type(1)][StoreNameLen(1)][NameLen(1)]
/// [StoreNameBytes(N)][NameBytes(N)][JSON(N)]
/// ```
///
/// **Features:**
/// - JSON serialization for universal type support
/// - Bitwise rotation obfuscation for basic security
/// - Type metadata in header for efficient filtering
/// - Forward-compatible version byte
class KeepCodecV1 extends KeepCodec {
  KeepCodecV1._();

  @override
  int get version => 1;

  @override
  KeepInternalEntry? decode(Uint8List bytes) {
    if (bytes.isEmpty) return null;

    try {
      // Un-shift first
      final data = KeepCodec.unShiftBytes(Uint8List.fromList(bytes));

      // Min: Version(1) + Flags(1) + Type(1) + StoreNameLen(1) + NameLen(1) = 5
      if (data.length < 5) return null;

      var offset = 0;

      // 1. Read header
      final version = data[offset++];
      final flags = data[offset++];
      final type = data[offset++];
      final storeNameLen = data[offset++];
      final nameLen = data[offset++];

      // 2. Read Store Name
      if (offset + storeNameLen > data.length) return null;
      final storeName = utf8.decode(
        data.sublist(offset, offset + storeNameLen),
      );
      offset += storeNameLen;

      // 3. Read Key Name
      if (offset + nameLen > data.length) return null;
      final originalKey = utf8.decode(data.sublist(offset, offset + nameLen));
      offset += nameLen;

      // 4. Read JSON Value
      final jsonBytes = data.sublist(offset);
      final jsonString = utf8.decode(jsonBytes);
      final value = jsonDecode(jsonString);

      if (value == null) {
        return null;
      }

      return KeepInternalEntry(
        value: value,
        flags: flags,
        name: originalKey,
        storeName: storeName,
        version: version,
        type: KeepType.fromByte(type),
      );
    } catch (error) {
      // Ignore legacy format or corrupted data
      return null;
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
      // [Version(1)]
      // [Flags(1)]
      // [Type(1)]
      // [StoreNameLen(1)]
      // [NameLen(1)]
      // [StoreNameBytes(N)]
      // [NameBytes(N)]
      // [JSON(N)]

      final type = KeepType.inferType(value);

      buffer
        ..addByte(Keep.version)
        ..addByte(flags)
        ..addByte(type.byte)
        ..addByte(storeNameBytes.length)
        ..addByte(keyNameBytes.length)
        ..add(storeNameBytes)
        ..add(keyNameBytes)
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
  KeepHeader? header(Uint8List bytes) {
    // Min: Version(1) + Flags(1) + Type(1) + StoreNameLen(1) + NameLen(1) = 5
    if (bytes.length < 5) return null;

    try {
      var offset = 0;

      // 1. Read header (first 5 bytes)
      final version = bytes[offset++];
      final flags = bytes[offset++];
      final typeByte = bytes[offset++];
      final storeNameLen = bytes[offset++];
      final nameLen = bytes[offset++];

      // 2. Read StoreName
      if (offset + storeNameLen > bytes.length) return null;
      final storeName = utf8.decode(
        bytes.sublist(offset, offset + storeNameLen),
      );
      offset += storeNameLen;

      // 3. Read Name
      if (offset + nameLen > bytes.length) return null;
      final name = utf8.decode(bytes.sublist(offset, offset + nameLen));

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
