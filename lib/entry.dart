part of 'keep.dart';

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
  /// Creates a new keep entry with the given [value] and [flags].
  const KeepMemoryValue(this.value, this.flags);

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

  /// Checks if the entry is marked as **Removable**.
  ///
  /// Returns `true` if the first bit (Bit 0) of [flags] is set.
  bool get isRemovable => (flags & KeepCodec._flagRemovable) != 0;

  @override
  String toString() => 'KeepEntry(value: $value, flags: $flags)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is KeepMemoryValue &&
        other.value == value &&
        other.flags == flags;
  }

  @override
  int get hashCode => Object.hash(value, flags);
}
