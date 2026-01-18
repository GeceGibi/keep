## [0.2.14]
### Changed
- `SubKeyManager.exists` is now async and ensures initialization before checking.

## [0.2.13]
### Added
- Added `SubKeyEvent` enum (`added`, `removed`, `cleared`) for tracking sub-key changes.
- Added `stream` getter to `SubKeyManager` for reactive sub-key monitoring.
- `SubKeyManager` now extends `ChangeNotifier` for Flutter widget integration.
- Added `dispose()` method to `SubKeyManager` for proper resource cleanup.

## [0.2.12]
### Changed
- Renamed `SubKeyManager.keys` getter to `toList()` method for better API clarity.

## [0.2.11]
### Changed
- Added documentation to `SubKeyManager.keys` getter.

## [0.2.10]
### Fixed
- Fixed race condition in `SubKeyManager._ensureInitialized()` that could cause concurrent calls to run multiple `_performLoad()` operations.
- Added `_ensureInitialized()` call to `SubKeyManager.remove()` to prevent data loss.
- Errors in `_performLoad()` now properly complete the completer with error, preventing infinite waits.

## [0.2.9]
### Fixed
- `KeepType.fromByte` now returns `tNull` instead of `null` for unknown bytes, preventing encoding crashes.

### Changed
- `KeepKey` no longer extends `Stream`. Use `stream` getter instead.
- Added `exists` getter to `SubKeyManager`.

## [0.2.8]
### Fixed
- Added try-catch blocks to `KeepCodec.encodeAll`, `decodeAll`, and `encodePayload` methods.

## [0.2.7]
### Fixed
- Internal storage now deletes corrupted files on decode failure instead of deadlocking.

## [0.2.6]
### Fixed
- Added missing try-catch blocks to `SubKeyManager` I/O operations.
- Disabled `avoid_catches_without_on_clauses` lint rule for broader exception handling.

## [0.2.5]
### Added
- Added memory cache for `KeepKeyPlain` and `KeepKeySecure` read operations.
- Added `clear()` and `remove()` methods to `SubKeyManager`.

### Changed
- Renamed `KeepValueType` to `KeepType`.
- Replaced `tUnknown` with `tNull` and added `tBytes` for `Uint8List` support.

### Performance
- Read operations now return cached values, significantly improving throughput.
- See `test/stress_test.dart` for benchmarks.

## [0.2.4]
### Changed
- Added `@mustCallSuper` annotation to `Keep.init()` method.

## [0.2.3]
### Added
- Added `KeepValueType` enum for type-safe binary encoding.
- Type byte now stored in binary format header.
- Added `KeepValueType.parse<T>()` for default type conversions.

## [0.2.2]
### Changed
- Optimized sub-key registration and disk synchronization (synchronous registration, smart background sync).

### Fixed
- Resolved issues with sub-key hierarchy and traversal logic.

## [0.2.1]
### Changed
- Improved global exception handling and error propagation stability.
- `read` methods now return `null` instead of throwing on corruption, ensuring graceful degradation.
- `write` methods now consistently fail-fast on errors.

### Fixed
- Fixed duplicate `onError` callbacks.

## [0.2.0]
### Added
- Introduced binary format versioning and migration infrastructure (V1).
- Improved storage key hashing and internal data obfuscation.

### Changed
- **Breaking:** `KeepKeySecure` now stores raw encrypted values directly for better efficiency.
- Standardized code structure and return patterns.

### Fixed
- Fixed crash when handling empty external storage files.
- Added legacy format support during migration.

## [0.1.2]
### Added
- Added `Keep.custom` for plain custom storage keys.

### Changed
- Renamed `custom` to `customSecure` for consistency.

## [0.1.1]
### Added
- Exported `KeepBuilder` and `KeepException`.

### Changed
- Renamed `useExternalStorage` to `useExternal`.

## [0.1.0]
### Added
- Added `fromStorage`/`toStorage` converters to `KeepKeyPlain`.
- Enhanced type safety for `Keep.list` and `Keep.map` factories.

## [0.0.4]
### Added
- Providing a custom `storage` adapter now automatically enables `useExternal`.

## [0.0.3]
### Added
- Support for per-key custom `KeepStorage` adapters.

## [0.0.2]
### Added
- Added static key factories (`Keep.integer`, `Keep.stringSecure`, etc.).
- Added `decimal` and `decimalSecure` factories.

### Changed
- `Keep.keys` now uses internal registry for faster access.
- `clearRemovable()` automatically notifies listeners.

### Fixed
- Improved `num` to `double` conversion.
- Fixed boolean parsing support.

## [0.0.1+1]
- Internal build stabilization.

## [0.0.1]
- Initial release