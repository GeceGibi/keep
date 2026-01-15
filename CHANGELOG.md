## [0.0.2]

### Added
- **Static Key Factories:** Added `Keep.integer`, `Keep.stringSecure`, etc., enabling cleaner field declarations without `late`.
- **Decimal Support:** Added `decimal` and `decimalSecure` factories for typed-safe double storage.
- **Inline Documentation:** Added comprehensive DartDocs for all public members and constructors.

### Changed
- **API Refactor:** Removed `KeepKeyManager` in favor of static methods in `Keep` class.
- **Metadata Optimization:** Eliminated `meta.keep` file; external storage indices are now code-driven via the internal registry.
- **Documentation:** Modernized example code in README.md.

### Fixed
- **Type Safety:** Improved `num` to `double` conversion in decimal factories.
- **Duplicate Part Directives:** Cleaned up project file organization.

## [0.0.1+1]
- Internal build stabilization and testing.

## [0.0.1]
- Initial release