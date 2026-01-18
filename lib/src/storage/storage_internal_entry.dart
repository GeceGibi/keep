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
  /// Creates a new keep entry with the given [value], [flags], optional [version] and [type].
  KeepMemoryValue({
    required this.value,
    required this.flags,
    required this.name,
    required this.storeName,
    this.version = Keep.version,
    KeepType? type,
  }) : type = type ?? KeepCodec.inferType(value);

  /// The original key name.
  final String name;

  /// The hashed key name (StoreName) used for file system and map keys.
  final String storeName;

  /// The stored value payload.
  final dynamic value;

  /// Bitwise metadata flags.
  final int flags;

  /// The version of the data package format.
  final int version;

  /// The type of the stored value.
  final KeepType type;

  /// Checks if the entry is marked as **Removable**.
  bool get isRemovable => (flags & KeepCodec.flagRemovable) != 0;

  /// Checks if the entry is marked as **Secure**.
  bool get isSecure => (flags & KeepCodec.flagSecure) != 0;

  @override
  String toString() =>
      'KeepMemoryValue(name: $name, value: $value, flags: $flags, type: $type, isRemovable: $isRemovable, isSecure: $isSecure)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is KeepMemoryValue &&
        other.name == name &&
        other.value == value &&
        other.flags == flags &&
        other.version == version &&
        other.type == type;
  }

  @override
  int get hashCode => Object.hash(name, value, flags, version, type);
}
