import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:keep/src/keep.dart';
import 'package:keep/src/storage/storage.dart';
import 'package:keep/src/utils/utils.dart';

part 'header.dart';
part 'v1.dart';

/// Abstract base class for version-based data migration.
///
/// Each [KeepCodec] represents a specific storage format version and
/// provides methods to encode data to that version and decode data from that version.
abstract class KeepCodec {
  /// The version number this codec handles.
  int get version;

  static final v1 = KeepCodecV1._();

  /// Flag bitmask for **Removable** keys (Bit 0).
  @internal
  @protected
  static const int flagRemovable = 1;

  /// Indicates that the payload is encrypted.
  @internal
  @protected
  static const int flagSecure = 2;

  Uint8List encodeAll(Map<String, KeepMemoryValue> entries);
  Map<String, KeepMemoryValue> decodeAll(Uint8List bytes);

  /// Encodes [data] to this codec's version format.
  Uint8List? encode({
    required String storeName,
    required String keyName,
    required Object value,
    required int flags,
  });

  /// Decodes [data] from this codec's version format.
  KeepMemoryValue? decode(Uint8List bytes);

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
}
