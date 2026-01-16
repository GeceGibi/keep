part of 'utils.dart';

/// Handles data migrations between different storage versions.
class KeepMigration {
  /// Processes a decoded entry and applies migrations if its version is older than [Keep.version].
  static KeepMemoryValue migrate(KeepMemoryValue entry) {
    // For now, we only support Version 1. Future migrations will be added here.
    return entry;
  }
}
