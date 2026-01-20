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
class KeepCodecOf {
  /// Creates a codec wrapper by reading version from [bytes].
  KeepCodecOf(this.bytes) {
    // UnShift and read version
    if (bytes.isEmpty) {
      codec = KeepCodec._v1;
      return;
    }

    final data = KeepCodec.unShiftBytes(Uint8List.fromList(bytes));

    if (data.isEmpty) {
      codec = KeepCodec._v1;
      return;
    }

    final version = data[0];
    codec = KeepCodec.forVersion(version);
  }

  /// The raw payload bytes.
  final Uint8List bytes;

  /// The selected codec instance for this payload.
  late final KeepCodec codec;

  /// Decodes the payload using the selected codec.
  KeepInternalEntry? decode() => codec.decode(bytes);

  /// Parses header metadata without full decoding.
  KeepHeader? header() => codec.header(bytes);
}
