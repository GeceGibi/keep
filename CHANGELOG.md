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