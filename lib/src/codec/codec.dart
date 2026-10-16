import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:keep/src/utils/utils.dart';

part 'codec_of.dart';
part 'header.dart';
part 'value.dart';
part 'codec_v1.dart';
part 'codec_v2.dart';

/// Abstract base class for version-based data migration.
///
/// Each [KeepCodec] represents a specific storage format version and
/// provides methods to encode data to that version and decode data from that
/// version.
abstract class KeepCodec with KeepCodecUtils {
  /// The version number this codec handles.
  int get version;

  /// Creates a codec wrapper that auto-selects version from bytes.
  static KeepCodecOf of(Uint8List bytes) => KeepCodecOf(bytes);

  /// Flag bitmask for **Removable** keys (Bit 0).
  @internal
  @protected
  static const int flagRemovable = 1;

  /// Indicates that the payload is encrypted.
  @internal
  @protected
  static const int flagSecure = 2;

  /// Encodes a single entry to this codec's version format.
  Uint8List? encode({
    required String storeName,
    required String keyName,
    required Object? value,
    required int flags,
  });

  /// Decodes [bytes] from this codec's version format.
  KeepKeyValue? decode(Uint8List bytes);

  /// Parses header metadata from payload bytes without full decoding.
  ///
  /// Returns metadata including version, flags, type, and key names.
  KeepKeyHeader? header(Uint8List bytes);

  /// Gets the latest available codec.
  static KeepCodec get current => _keepCodecV2;

  /// Selects the appropriate codec based on version number.
  static KeepCodec forVersion(int version) {
    return switch (version) {
      1 => _keepCodecV1,
      2 => _keepCodecV2,

      /// Fallback for unknown versions
      _ => throw KeepException<dynamic>('Unsupported version: $version'),
    };
  }
}
