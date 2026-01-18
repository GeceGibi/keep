# Keep

**Keep** is a modern, type-safe, and highly reactive local storage engine for Flutter. Built for developers who need more than just key-value pairs, Keep offers **Field-Level Encryption**, **Hybrid Storage** (Memory + Disk), and a **"No-Late" Static API** that makes state management a breeze.

---

## Key Features

- **Field-Level Encryption:** Encrypt sensitive fields individually while keeping the rest plain.
- **"No-Late" Architecture:** Define keys as final class members. No late, no complicated initialization.
- **Fully Reactive:** Bind your UI directly to storage keys with KeepBuilder or Streams.
- **Hybrid Storage:** Small data lives in a fast binary index; large data is offloaded to independent files.
- **Obfuscated Disk Footprint:** File names and internal keys are hashed (DJB2) and payloads are byte-shifted.
- **Type-Safe:** Built-in support for int, String, bool, double, Map, List, and Custom Objects.

---

## Installation

Add keep to your pubspec.yaml:

```yaml
dependencies:
  keep: ^0.2.5
```

---

## Usage

### 1. Define Your Schema
Extend Keep and declare your keys. You can configure global error handling, encryption, and storage through the constructor.

```dart
class AppStorage extends Keep {
  AppStorage() : super(
    // Global error listener
    onError: (exception) => print('Keep Error: ${exception.message}'),

    // Custom encryption strategy (defaults to XOR obfuscation)
    encrypter: MyAesEncrypter(),

    // Custom storage adapter (defaults to File-based storage)
    externalStorage: DefaultKeepExternalStorage(),
  );

  // Define keys as final fields
  final counter = Keep.integer('counter');
  final username = Keep.string('username');
  final authToken = Keep.stringSecure('auth_token');
  final settings = Keep.map('settings', useExternal: true);
}

final storage = AppStorage();
```

### 2. Constructor Configuration

| Parameter | Type | Description | Default |
|-----------|------|-------------|---------|
| `onError` | `Function(KeepException)` | Global callback for all storage and encryption errors. | `null` |
| `encrypter` | `KeepEncrypter` | The implementation used for secure keys. | `SimpleKeepEncrypter` |
| `externalStorage` | `KeepStorage` | The adapter used for external (file-based) keys. | `DefaultKeepExternalStorage` |

### 3. Initialize
Call init() before using the storage (usually in your main function).

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Default path: getApplicationSupportDirectory()
  await storage.init(); 
  
  runApp(const MyApp());
}
```

### 4. Read & Write
Keep supports both async and sync reads for maximum flexibility.

```dart
// Simple writes
await storage.counter.write(42);

// Async reads (Safest)
final value = await storage.counter.read();
final safeValue = await storage.counter.readSafe(0);

// Sync reads (Fast, for UI building)
final syncValue = storage.counter.readSync();
```

### 5. Reactive UI Binding
Rebuild widgets automatically when a specific key changes.

```dart
KeepBuilder<int>(
  keepKey: storage.counter,
  builder: (context, value) {
    return Text('Value: $value');
  },
);
```

---

## Advanced Usage

### Custom Encryption (AES Example)

For production apps, implement `KeepEncrypter` with a robust algorithm like **AES-GCM**. Use `Isolate.run` to offload heavy cryptographic operations from the UI thread.

```dart
import 'dart:async';
import 'dart:isolate';
import 'package:keep/keep.dart';
import 'package:encrypt/encrypt.dart' as crypt;

class MyAesEncrypter extends KeepEncrypter {
  late crypt.Encrypter _encrypter;
  final _iv = crypt.IV.fromLength(16);

  @override
  Future<void> init() async {
    // In a real app, retrieve this from a secure vault like flutter_secure_storage
    final key = crypt.Key.fromUtf8('my-32-character-ultra-secure-key');
    _encrypter = crypt.Encrypter(crypt.AES(key, mode: crypt.AESMode.gcm));
  }

  @override
  String encryptSync(String data) {
    return _encrypter.encrypt(data, iv: _iv).base64;
  }

  @override
  String decryptSync(String data) {
    return _encrypter.decrypt64(data, iv: _iv);
  }

  @override
  Future<String> encrypt(String data) => Isolate.run(() => encryptSync(data));

  @override
  Future<String> decrypt(String data) => Isolate.run(() => decryptSync(data));
}

// Injection into your Keep subclass
class SecureAppStorage extends Keep {
  SecureAppStorage() : super(
    encrypter: MyAesEncrypter(),
  );

  final pin = Keep.integerSecure('user_pin');
}
```

### Custom Storage Adapter

Implement `KeepStorage` to change how external keys (those with `useExternal: true`) are persisted. This is useful for storing large blobs in a local database like SQLite or a NoSQL solution.

```dart
class MyDatabaseStorage extends KeepStorage {
  @override
  Future<void> init(Keep keep) async {
    // Open your database connection here
    print('Initializing Database Storage for ${keep.root.path}');
  }

  @override
  FutureOr<void> write(KeepKey<dynamic> key, Object? value) async {
    // key.storeName contains the hashed/obfuscated name
    // Save 'value' to your DB table where id = key.storeName
  }

  @override
  FutureOr<V?> read<V>(KeepKey<dynamic> key) async {
    // Retrieve value from DB and cast to V
    return null; 
  }

  @override
  FutureOr<void> remove(KeepKey<dynamic> key) async {
    // Delete row from DB
  }

  @override
  FutureOr<bool> exists(KeepKey<dynamic> key) async {
    // Check if row exists in DB
    return false;
  }

  @override
  FutureOr<void> clear() async {
    // Truncate storage table
  }

  // Mandatory overrides for sync and internal discovery
  @override
  V? readSync<V>(KeepKey<dynamic> key) => null;
  
  @override
  bool existsSync(KeepKey<dynamic> key) => false;

  @override
  F getEntry<F>(KeepKey<dynamic> key) => throw UnimplementedError('DB does not use Files');

  @override
  FutureOr<List<E>> getEntries<E>() => [];

  @override
  Future<void> clearRemovable() async {
    // Query DB for entries with removable flag and delete them
  }
}

// Injection into your Storage class
class AppStorage extends Keep {
  AppStorage() : super(
    externalStorage: MyDatabaseStorage(),
  );

  // This key will now use MyDatabaseStorage instead of the file system
  final largeLogs = Keep.list('logs', useExternal: true);
}
```

### Per-Key Custom Storage

You can specify a custom storage adapter for individual keys. This overrides the global `externalStorage` for that specific key. **Note:** Providing a custom adapter automatically enables external storage for that key and routes all operations directly to your adapter.

```dart
final specialData = Keep.string(
  'special_key',
  storage: MyCloudStorage(), // Uses this storage directly and enables external storage implicitly
);
```

---

### 6. Sub-Keys (Nested Storage)
Create nested keys dynamically using the call operator. This allows for hierarchical data organization without defining explicit fields for every possible key.

```dart
// Define a root key
final users = Keep.string('users');

// Recommended: Assign sub-keys to variables for better readability and safety
final alice = users('alice');
await alice.write('Alice Data');

final aliceSettings = alice('settings');
await aliceSettings.write('Dark Mode');
```

---

## Documentation

- **Keep**: The orchestrator. Handles lifecycle and registry.
- **KeepKey<T>**: Handle for data access. Supports `read()`, `write()`, and `Stream` listening. Use `key('subKey')` to create nested keys.
- **KeepKeySecure<T>**: Automatically handles encryption cycles.
- **KeepBuilder**: Reactive widget for automatic UI updates.

## Performance

Benchmarked with 1000 iterations per operation. See [`test/stress_test.dart`](test/stress_test.dart) for details.

| Operation | ops/sec |
|-----------|---------|
| Internal Write | ~28K |
| Internal Read | ~110K |
| Internal ReadSync | ~1M |
| External Write | ~2.4K |
| External Read | ~125K |
| Internal Secure Write | ~6K |
| Internal Secure Read | ~150K |

> Read operations benefit from in-memory caching. Write operations include disk I/O.

---

## Roadmap

- [x] **Migration:** Tools for schema versioning and data migrations.

---

## License

MIT License - Check [LICENSE](LICENSE) for details. Developed by **GeceGibi**.
