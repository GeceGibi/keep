part of 'codec.dart';

/// Represents a complete key-value entry with metadata and decoded value.
///
/// Extends [KeepKeyHeader] to include the actual deserialized value data.
/// Used internally for storing and transferring decoded entries.
class KeepKeyValue extends KeepKeyHeader {
  /// Creates a new keep entry with the given [value], [flags], [version] and
  /// [type].
  const KeepKeyValue({
    required this.value,
    required super.name,
    required super.flags,
    required super.version,
    required super.type,
    required super.storeName,
  });

  /// Parses a [KeepKeyValue] from raw bytes, automatically detecting codec
  /// version.
  static KeepKeyValue? fromBytes(Uint8List bytes) {
    return KeepCodec.of(bytes).decode();
  }

  /// The decoded value stored in this entry.
  final Object? value;
}
