part of 'codec.dart';

/// Wrapper that automatically selects the correct codec version from bytes.
///
/// This class reads the version byte from the payload and selects the
/// appropriate [KeepCodec] implementation for decoding.
///
/// Example:
/// ```dart
/// final codec = KeepCodec.of(bytes);
/// final entry = codec.decode();
/// ```
class KeepCodecOf with KeepCodecUtils {
  /// Creates a codec wrapper by reading version from [bytes].
  ///
  /// The bytes are unShifted once and cached for subsequent operations.
  KeepCodecOf(Uint8List bytes) {
    _data = bytes.isEmpty ? Uint8List(0) : unShiftBytes(bytes);

    codec = _data.isEmpty ? KeepCodec.current : KeepCodec.forVersion(_data[0]);
  }

  /// The unShifted payload bytes.
  late final Uint8List _data;

  /// The selected codec instance for this payload.
  late final KeepCodec codec;

  /// Decodes the payload using the selected codec.
  KeepKeyValue? decode() => codec.decode(_data);

  /// Encodes a single entry to the selected codec's version format.
  Uint8List? encode({
    required String storeName,
    required String keyName,
    required Object? value,
    required int flags,
  }) => KeepCodec.current.encode(
    storeName: storeName,
    keyName: keyName,
    value: value,
    flags: flags,
  );

  /// Parses header metadata without full decoding.
  KeepKeyHeader? header() => codec.header(_data);
}
