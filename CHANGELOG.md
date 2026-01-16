## [0.2.0]
### Added
- **Unified Key Hashing:** All storage keys (Plain & Secure) now use DJB2 hashing for their physical storage names (`storeName`). This prevents issues with special characters in file names and adds a layer of obfuscation for all keys.
- **Payload Obfuscation for External Storage:** Byte shifting (ROL 1) is now consistently applied to both internal and external storage payloads.

### Changed
- **Breaking Change (Secure Storage Format):** `KeepKeySecure` no longer wraps encrypted data in a Map `{ 'k': name, 'v': value }`. It now stores the raw encrypted value directly for improved efficiency and simplicity.
- **Refactoring:** Extracted hashing and byte shifting logic into `KeepCodec` for better modularity and reuse.

### Fixed
- **Empty File Handling:** Added robust null checks for empty files in external storage to prevent potential crashes.

## [0.1.2]
### Added
- **`Keep.custom`:** Added a new method for plain (unencrypted) custom storage keys.

### Changed
- **`Keep.customSecure`:** Renamed the existing `custom` method for secure keys to `customSecure` to align with the naming convention.

## [0.1.1]
### Added
- **Exports:** Exposed `KeepBuilder` and `KeepException` to allow easier integration and error handling.

### Changed
- **API Refinement:** Renamed `useExternalStorage` to `useExternal` across all factories for a more concise and consistent API.
- **Maintenance:** Applied minor code formatting and internal optimizations to storage methods.

## [0.1.0]
### Added
- **`KeepKeyPlain` Converters:** Added `fromStorage` and `toStorage` support to `KeepKeyPlain`, enabling custom serialization and deserialization for non-encrypted keys.
- **Factory Type Safety:** Enhanced `Keep.list` and `Keep.map` factories with automatic `cast<T>()` and `cast<String, dynamic>()` support to prevent `List<dynamic>` to `List<String>` type cast errors from JSON.

## [0.0.4]
### Added
- **Implicit External Storage:** Providing a custom `storage` adapter now automatically enables `useExternalStorage`, simplifying key definitions.

## [0.0.3]
### Added
- **Per-Key Custom Storage:** Added support for specifying an optional `KeepStorage` for individual keys via factories, allowing multi-backend storage strategies.
- **Enhanced Documentation:** Added realistic AES-GCM and Custom Database Storage implementation examples.

## [0.0.2]
### Added
- **Static Key Factories:** Added `Keep.integer`, `Keep.stringSecure`, etc., enabling cleaner field declarations without `late`.
- **Decimal Support:** Added `decimal` and `decimalSecure` factories for typed-safe double storage.
- **Inline Documentation:** Added comprehensive DartDocs for all public members and constructors.

### Changed
- **API Simplification:** `Keep.keys` and `Keep.removableKeys` now return `List<KeepKey>` instead of `List<String>`, utilizing the internal registry for faster access.
- **Registry-Based Discovery:** Removed manual disk scanning for key discovery (`keysExternal` removed) in favor of the new automatic registration system.
- **Reactive Cleanup:** `clearRemovable()` now automatically notifies all listeners of the affected keys via `onChangeController`.
- **Metadata Optimization:** Eliminated `meta.keep` file; external storage is now purely code-driven.
- **Structure:** Removed `KeepKeyManager` and organized factories directly within the `Keep` class.

### Fixed
- **Type Safety:** Improved `num` to `double` conversion in decimal factories.
- **Boolean Parsing:** Added support for `1` as truthy in `booleanSecure`.
- **Duplicate Directives:** Cleaned up project file organization and part directives.

## [0.0.1+1]
- Internal build stabilization and testing.

## [0.0.1]
- Initial release