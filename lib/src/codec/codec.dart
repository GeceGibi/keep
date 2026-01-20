import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:keep/src/keep.dart';
import 'package:keep/src/storage/storage.dart';
import 'package:keep/src/utils/utils.dart';

part 'codec_of.dart';
part 'header.dart';
part 'v1.dart';

/// Abstract base class for version-based data migration.
///
/// Each [KeepCodec] represents a specific storage format version and
/// provides methods to encode data to that version and decode data from that version.
abstract class KeepCodec {
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
    required dynamic value,
    required int flags,
  });

  /// Decodes [bytes] from this codec's version format.
  KeepInternalEntry? decode(Uint8List bytes);

  /// Parses header metadata from payload bytes without full decoding.
  ///
  /// Returns metadata including version, flags, type, and key names.
  KeepHeader? header(Uint8List bytes);

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

  /// Generates a non-reversible hash for a given [key] name using DJB2.
  /// Used for obfuscating filenames and internal map keys.
  static String hash(String key) {
    final bytes = utf8.encode(key);

    var hash = 5381;
    for (final byte in bytes) {
      hash = ((hash << 5) + hash) + byte;
    }

    return hash.toUnsigned(64).toRadixString(36);
  }

  /// Version 1 codec instance (default).
  static final _v1 = KeepCodecV1._();

  /// Gets the latest available codec.
  static KeepCodec get current => _v1;

  /// Selects the appropriate codec based on version number.
  static KeepCodec forVersion(int version) {
    return switch (version) {
      1 => _v1,
      _ => _v1, // Fallback
    };
  }

  /// Reads version from raw bytes and returns appropriate codec.
  static KeepCodec fromBytes(Uint8List bytes) {
    if (bytes.isEmpty) {
      return _v1;
    }

    // UnShift to get actual data
    final data = unShiftBytes(Uint8List.fromList(bytes));
    if (data.isEmpty) {
      return _v1;
    }

    // First byte is version
    final version = data[0];
    return forVersion(version);
  }
}
