part of 'codec.dart';

/// Version 2 codec instance.
final _keepCodecV2 = KeepCodecV2._();

/// Version 2 codec - StandardMessageCodec-based binary format.
///
/// **Binary Format:**
/// ```text
/// [Version(1)][Flags(1)][Type(1)][StoreNameLen(1)][NameLen(1)]
/// [StoreNameBytes(N)][NameBytes(N)][StandardMessageCodec(N)]
/// ```
///
/// **Changes from v1:**
/// - Uses StandardMessageCodec instead of JSON for value encoding
/// - More compact binary representation
/// - Faster encode/decode (no string parsing)
///
class KeepCodecV2 extends KeepCodec {
  KeepCodecV2._();

  final _standardCodec = const StandardMessageCodec();

  @override
  int get version => 2;

  @override
  KeepKeyValue? decode(Uint8List data) {
    // Min: Version(1) + Flags(1) + Type(1) + StoreNameLen(1) + NameLen(1) = 5
    if (data.length < 5) return null;

    try {
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

      // 4. Read StandardMessageCodec Value
      final valueBytes = data.sublist(offset);
      final byteData = ByteData.sublistView(valueBytes);
      final value = _standardCodec.decodeMessage(byteData);

      if (value == null) {
        return null;
      }

      return KeepKeyValue(
        value: value,
        flags: flags,
        name: originalKey,
        storeName: storeName,
        version: version,
        type: .fromByte(type),
      );
    } catch (error) {
      return null;
    }
  }

  @override
  Uint8List? encode({
    required String storeName,
    required String keyName,
    required Object? value,
    required int flags,
  }) {
    try {
      final buffer = BytesBuilder();

      // Encode value with StandardMessageCodec
      final valueByteData = _standardCodec.encodeMessage(value);

      final valBytes = valueByteData != null
          ? Uint8List.view(
              valueByteData.buffer,
              valueByteData.offsetInBytes,
              valueByteData.lengthInBytes,
            )
          : Uint8List(0);

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
      // [StandardMessageCodec(N)]

      final type = KeepType.inferType(value);

      buffer
        ..addByte(version)
        ..addByte(flags)
        ..addByte(type.byte)
        ..addByte(storeNameBytes.length)
        ..addByte(keyNameBytes.length)
        ..add(storeNameBytes)
        ..add(keyNameBytes)
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

  @override
  KeepKeyHeader? header(Uint8List data) {
    // Min: Version(1) + Flags(1) + Type(1) + StoreNameLen(1) + NameLen(1) = 5
    if (data.length < 5) return null;

    try {
      var offset = 0;

      // 1. Read header (first 5 bytes)
      final version = data[offset++];
      final flags = data[offset++];
      final typeByte = data[offset++];
      final storeNameLen = data[offset++];
      final nameLen = data[offset++];

      // 2. Read StoreName
      if (offset + storeNameLen > data.length) {
        return null;
      }

      final storeName = utf8.decode(
        data.sublist(offset, offset + storeNameLen),
      );

      offset += storeNameLen;

      // 3. Read Name
      if (offset + nameLen > data.length) {
        return null;
      }

      final name = utf8.decode(data.sublist(offset, offset + nameLen));

      return KeepKeyHeader(
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
