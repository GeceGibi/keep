part of 'codec.dart';

class KeepHeader {
  KeepHeader({
    required this.storeName,
    required this.name,
    required this.flags,
    required this.version,
    required this.type,
  });

  final String storeName;
  final String name;
  final int flags;
  final int version;
  final KeepType type;
}
