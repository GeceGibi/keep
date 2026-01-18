part of 'utils.dart';

/// Represents the type of a stored value in binary format.
enum KeepType {
  /// Null type.
  tNull(0),

  /// Integer type.
  tInt(1),

  /// Double type.
  tDouble(2),

  /// Boolean type.
  tBool(3),

  /// String type.
  tString(4),

  /// List type.
  tList(5),

  /// Map type.
  tMap(6),

  /// Bytes type.
  tBytes(7)
  ;

  const KeepType(this.byte);

  /// The byte value used in binary encoding.
  final int byte;

  /// Returns the [KeepType] for the given [byte], or [tNull] if not found.
  static KeepType fromByte(int byte) {
    for (final type in values) {
      if (type.byte == byte) return type;
    }

    return tNull;
  }

  /// Parses the raw [value] to the expected type.
  T? parse<T>(Object? value) {
    if (value == null) {
      return null;
    }

    switch (this) {
      case .tNull:
        return null;

      case .tInt:
        final parsed = value is int ? value : int.tryParse(value.toString());
        return parsed as T?;

      case .tDouble:
        final parsed = value is double
            ? value
            : (value is num
                  ? value.toDouble()
                  : double.tryParse(value.toString()));
        return parsed as T?;

      case .tBool:
        final parsed = value is bool ? value : (value == 'true' || value == 1);
        return parsed as T?;

      case .tString:
        return value.toString() as T?;

      case .tList:
        return (value is List ? value : null) as T?;

      case .tMap:
        return (value is Map ? value : null) as T?;

      case .tBytes:
        return (value is Uint8List ? value : null) as T?;
    }
  }
}
