# Storage Library Design Notes

## Core Features
- Type-safe `StorageKey<T>` with generic key system
- Automatic key registry (injected in constructor)
- `removable` flag for logout/cache management
- Cache versioning with automatic migration
- Isolate support (large data encode/decode)

## Changes Required for Library Extraction

### 1. Abstract Dependencies
- `logger` → callback or interface injection
- `globals.deviceInfo.uuid` → key derivation callback in config
- `fileStorage` → `PersistentStorageAdapter` interface
- `_k` (hardcoded key) → provided via config
- `compute` → `Isolate.run` (pure Dart) or optional

### 2. Encryption Override
```dart
StorageConfig(
  encrypt: (value) => customEncrypt(value),
  decrypt: (value) => customDecrypt(value),
  // or for default AES, just provide key
  encryptionKey: 'my-secret-key',
)
```

### 3. PersistentStorage Adapter
```dart
abstract class PersistentStorageAdapter {
  Future<void> init();
  bool exists(String key);
  String? read(String key);
  Future<void> write(String key, String value);
  Future<void> remove(String key);
  Future<void> clear();
}
```
Users can implement SQLite, Hive, cloud storage, etc.

### 4. Zero Config Init
```dart
await Storage.init(); // all defaults
await Storage.init(config: StorageConfig(...)); // custom
```

### 5. Extendable Storage (Multiple Instances)
```dart
class UserStorage extends Storage {
  UserStorage() : super(
    defaultEncrypted: true,
    defaultRemovable: true,
    prefix: 'user_',
  );
  
  final token = key.string('token');
  final profile = key.map('profile');
}

class CacheStorage extends Storage {
  CacheStorage() : super(
    defaultEncrypted: false,
    defaultRemovable: true,
    prefix: 'cache_',
  );
  
  final feedData = key.list<Map>('feedData');
}

// Each instance is isolated
final userStorage = UserStorage();
final cacheStorage = CacheStorage();

await userStorage.init();
await cacheStorage.init();

// Different clear behaviors
await cacheStorage.clear(); // only cache
await userStorage.clear();  // only user data
```

### 6. Parent Defaults + Child Override
```dart
// Defaults from parent
final token = key.string('token'); // encrypted: true, removable: true

// Override
final apiKey = key.string('apiKey', 
  encrypted: true,
  removable: false, // override
);
```

## Package Name Ideas
- `fortress`, `citadel`, `haven` (may be taken)
- `ironbox`, `keystash`, `datafort`, `enclave`
- `persistx`, `safekey`, `storix`

## Competitive Advantages
| Feature | This Package | flutter_secure_storage | Hive |
|---------|--------------|------------------------|------|
| Type-safe keys | ✅ | ❌ | ✅ |
| Key registry | ✅ | ❌ | ❌ |
| Removable flag | ✅ | ❌ | ❌ |
| Cache versioning | ✅ | ❌ | ❌ |
| Encryption + large data | ✅ | ❌ | ❌ |
| Multi-instance | ✅ | ❌ | ✅ |
