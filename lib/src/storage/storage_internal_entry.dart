part of 'storage.dart';

/// Represents a value stored in the keep along with its associated metadata flags.
///
/// This class serves as the fundamental data container for storing and retrieving
/// information within the Keep system. It encapsulates both the raw data payload
/// and bitwise flags that define the data's behavior (e.g., persistence strategies).
///
/// Instances of [KeepMemoryValue] are immutable and are used during:
/// - In-memory storage (Internal Keep)
/// - Binary serialization (External Keep)
@immutable
class KeepMemoryValue {
  /// Creates a new keep entry with the given [value], [flags], and optional [version].
  const KeepMemoryValue(this.value, this.flags, {this.version = Keep.version});

  /// The stored value payload.
  ///
  /// This can be any JSON-serializable type, such as:
  /// - `String`, `int`, `double`, `bool`
  /// - `List<dynamic>`, `Map<String, dynamic>`
  /// - `null`
  final dynamic value;

  /// Bitwise metadata flags determining the entry's properties.
  ///
  /// Common flags include:
  /// - **Removable (Bit 0):** Indicates that the entry should be cleared when `clearRemovable()` is called.
  /// - *(Future Flags):* Compression, Expiry, etc.
  final int flags;

  /// The version of the data package format.
  final int version;

  /// Checks if the entry is marked as **Removable**.
  ///
  /// Returns `true` if the first bit (Bit 0) of [flags] is set.
  bool get isRemovable => (flags & KeepCodec.flagRemovable) != 0;

  /// Checks if the entry is marked as **Secure**.
  ///
  /// Returns `true` if the second bit (Bit 1) of [flags] is set.
  bool get isSecure => (flags & KeepCodec.flagSecure) != 0;

  @override
  String toString() =>
      'KeepMemoryValue(value: $value, flags: $flags, isRemovable: $isRemovable, isSecure: $isSecure)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is KeepMemoryValue &&
        other.value == value &&
        other.flags == flags &&
        other.version == version;
  }

  @override
  int get hashCode => Object.hash(value, flags, version);
}
