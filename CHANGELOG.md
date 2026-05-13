## 1.0.0

This is a major release focused on **data durability**, **reactivity correctness**,
and **concurrency safety**. Several long-standing bugs that could cause silent
data loss or stale UI have been fixed. Most changes are transparent to existing
code, but a few have behavioral implications — see _Migration Notes_ at the end.

### Durability (BREAKING)

- **Bug Fix:** `await keepKey.write(value)` for internal storage now blocks until
  the value is durably persisted to disk. Previously `saveMemory()` was
  fire-and-forget (`unawaited`), so a process crash immediately after
  `await write()` could lose the written value despite the apparent success.
- **Bug Fix:** `Keep.dispose()` now flushes all pending writes to disk before
  tearing down the writer queues. Previously pending debounced writes were
  cancelled and their data lost forever.
- **Bug Fix:** When a debounced pending operation is superseded by a newer one
  (`KeepWriteQueue.run`), the original caller's future is now resolved with the
  **successor's** outcome instead of being silently completed with `null`. This
  guarantees that `await write(...)` returning means data is persistent for
  every caller in a debounce chain, not just the most recent one.
- **New API:** `Keep.flush()` drains all pending writes to disk across both
  internal and external storage. Useful after fire-and-forget
  `unawaited(write(...))` patterns or before snapshotting the storage directory.
- **New API:** `KeepStorage.flush()` interface method (default no-op) lets
  storage adapters expose their flush semantics.
- **New API:** `KeepWriteQueue.flush()` waits for all in-flight and pending
  operations to settle without cancelling them; `awaitSettled(id)` waits for a
  specific id.

### Reactivity (BREAKING)

- **Bug Fix:** `KeepKey.remove()` now invalidates the in-memory value cache and
  emits a change event on `onChangeController`. Previously a removed key kept
  returning its stale cached value from `readSync()`/`read()`, and listeners
  (`KeepBuilder`, `key.stream`) never observed the removal.
- **Bug Fix:** `Keep.clear()` and `Keep.clearRemovable()` now invalidate the
  per-key caches of all (or removable) registered keys before notifying
  listeners.
- **Bug Fix:** `KeepBuilder` is now a `StatefulWidget` that holds the latest
  value in widget state. Previously the `StreamBuilder` + `FutureBuilder`
  combination issued a fresh `read()` future on every parent rebuild, causing
  flicker and transient `null` frames.

### Storage Engine

- **Bug Fix:** Concurrent external reads on the same key no longer return
  phantom `null` due to the writer queue's debounce. Reads now bypass the queue
  and use `awaitSettled` to observe in-flight writes without participating in
  cancellation.
- **Bug Fix:** External storage `read()` / `readSync()` no longer delete the
  underlying file when decoding returns `null`, completing the 0.7.0 fix that
  already removed this automatic deletion in error paths.
- **Bug Fix:** `KeepInternalStorage.read()` now awaits `Keep.ensureInitialized`
  so callers that bypass the `KeepKey` wrapper still observe a fully loaded
  memory map.

### Robustness

- **Bug Fix:** `Keep.init()` now wraps initialization in a `try/catch` and
  completes its internal completer with an error on failure. Previously a
  failed init left the completer permanently pending, causing every subsequent
  `ensureInitialized` await to hang forever.
- **Bug Fix:** `KeepKey.update()` now serializes concurrent atomic updates
  targeting the same key via a per-key mutex (`Keep.runSerialized`), preventing
  classic lost-update races where two callers read the same value and
  overwrite each other.
- **Bug Fix:** `SubKeyManager.toList()` no longer silently swallows header read
  errors; failures are now surfaced via `Keep.onError`.
- **Bug Fix:** All `onChangeController.add(...)` call sites guard against a
  closed controller, preventing crashes when a fire-and-forget write resolves
  after `Keep.dispose()`.

### Security

- **Improvement:** `SimpleKeepEncrypter` now asserts that `secureKey` is at
  least 8 characters long.
- **Improvement:** `Keep.init()` emits a debug-mode warning when the default
  fallback `SimpleKeepEncrypter` is used together with any `KeepKeySecure`,
  since the default key is a public constant that offers only basic
  obfuscation.

### Codec

- **Bug Fix:** `shiftBytes` and `unShiftBytes` no longer mutate their input
  buffer; they return a freshly allocated `Uint8List`. The defensive
  `Uint8List.fromList` copy inside `KeepCodecOf` has been removed since the
  mixin is now safe.

### Migration Notes

- `await keepKey.write(value)` for internal storage is now stricter about
  durability and therefore slower for sequential awaited writes (roughly
  matching external storage throughput). For high-frequency writes that
  previously relied on fire-and-forget semantics, switch to
  `unawaited(write(...))` followed by a single `await keep.flush()` at the
  appropriate flush point — supersede chaining still coalesces these into a
  single disk write while preserving durability for every awaiter.
- Custom `KeepStorage` implementations may override `flush()` to expose their
  own queue draining; the default implementation is a no-op.
- Code that depended on `shiftBytes` / `unShiftBytes` mutating in place must
  now use the returned `Uint8List`.

## 0.7.0
- **Performance:** Implemented `null` value caching in `KeepKeyPlain` and `KeepKeySecure` to prevent unnecessary repeated disk I/O when reading non-existent keys.
- **Performance:** Updated `write` methods to immediately cache the newly written value, avoiding an extra disk read on the subsequent `read` call.
- **Bug Fix:** Removed `unawaited(remove())` from the catch blocks in `read` and `readSync` methods for both `KeepKeyPlain` and `KeepKeySecure`. This prevents disastrous automatic deletion of user data when a simple parsing or schema error occurs.

## 0.6.0
- **Binary Codec (V2):** Switched from JSON-based encoding to `StandardMessageCodec` for significant performance gains and smaller storage footprint.
- **Improved Performance:** Optimized binary serialization for complex and nested data structures.
- **Auto-Migration:** Automatic seamless migration from V1 (JSON) to V2 (Binary) format on first write.
- **Better Field Support:** Updated codec interface to use `Object?` for improved type precision.
- **Stability:** Enhanced internal batch encoding logic for better memory efficiency.

## 0.5.3
- Fixed race condition in atomic writes.
- Fixed race condition in initialization.

## 0.5.2
- Refactored file write operations with a robust `atomicWrite` utility.
- Added explicit directory checks and temporary file validation to prevent `PathNotFoundException` during atomic swaps.
- Improved error handling by ensuring temporary files are cleaned up on failure.
- Specialized for better stability on emulators and slow file systems.

## [0.5.1]
### Added
- **Uint8List Support:** New `kBytes` and `kBytesSecure` factories for efficient byte array storage.
- **Custom Serialization for Secure Keys:** Secure factories now support optional `fromStorage` and `toStorage` mappers.

### Changed
- **Performance:** General optimizations for better memory efficiency and speed.
- **Code Clarity:** Improved internal factory logic for better readability.

## [0.5.0]
### Added
- **Multi-Instance Support:** Multiple `Keep` instances can now run concurrently with independent registries and storage locations.
  - `Keep` constructor now requires a unique `id` for stable identity and folder naming.
  - Automatic folder hashing ensures storage isolation based on instance ID.
- **Refined Static Key Factories:** Renamed factories for brevity and consistency:
  - `Keep.kInt`, `Keep.kIntSecure`
  - `Keep.kString`, `Keep.kStringSecure`
  - `Keep.kBool`, `Keep.kBoolSecure`
  - `Keep.kDouble`, `Keep.kDoubleSecure`
  - `Keep.kList`, `Keep.kListSecure`
  - `Keep.kMap`, `Keep.kMapSecure`
  - `Keep.custom`, `Keep.customSecure`

### Changed
- **Breaking:** `Keep` constructor requires positional `id: String`.
- **Breaking:** `Keep.init()` no longer accepts `folderName` as it is now derived from `id`.
- `Keep` instances now perform automatic key binding during construction for multi-instance support.

## [0.4.0]
### Added
- **Version-Based Migration System:** Introduced `KeepCodec` architecture for seamless storage format upgrades
  - `KeepCodec.of(bytes)` automatically selects correct codec based on version byte
  - `KeepCodecV1` implements current JSON-based format with optimized header structure
  - Future-proof: Add new codecs without breaking existing data
- New binary format with version-first layout: `[Version][Flags][Type][Lengths...][Data]`
- `KeepCodecOf` wrapper for automatic codec selection and decoding
- `KeepHeader` class for metadata extraction without full payload parsing

### Changed
- **Breaking:** Binary format updated - version byte moved to first position for instant detection
- Batch encoding/decoding moved from codec interface to internal storage implementation
- Simplified codec interface to single-entry operations only

### Performance
- Header parsing now O(1) instead of O(n) due to fixed-position metadata
- Codec selection happens once at read time, not per-operation

## [0.3.0+1]
### Added
- Added `KeepStorage.readHeader()` to allow reading metadata without loading full content.
- `KeepCodec.parseHeader()` now returns `version` and `KeepType` enum.

### Changed
- Refactored `SubKeyManager` to be storage-agnostic by using `readHeader()` instead of direct file system access.

## [0.3.0]
### Changed
- **Breaking:** `SubKeyManager.toList()` now works without requiring a meta-file.
- **Breaking:** Storage format updated. Old data will be treated as non-existent and ignored.

### Added
- `SubKeyManager.toList()` now finds sub-keys even if they haven't been written yet in the current session.
- `clearRemovable()` can now remove all removable sub-keys, even those not accessed in the current session.

### Fixed
- Improved reliability of sub-key discovery across app restarts.

## [0.2.16]
### Fixed
- Fixed a deadlock in `KeepKey.remove` when notifying the parent `SubKeyManager`.
- Fixed potential race condition in `SubKeyManager.clear()` by canceling active debounce timers.

### Changed
- Internalized sub-key registration methods (`_register`, `_unregister`) to simplify the public API.

## [0.2.15]
### Fixed
- `SubKeyManager.clear()` now properly removes sub-key contents before clearing the registry.

### Changed
- Renamed internal debounce timer variables for consistency (`_debounceTimer`).

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