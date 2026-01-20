# Keep

A type-safe, reactive local storage solution for Flutter with field-level encryption and hybrid storage support.

---

## Features

- **Type-Safe Storage:** Built-in support for primitives, collections, and custom objects
- **Field-Level Encryption:** Encrypt individual keys while keeping others in plain text
- **Reactive:** Stream-based updates and reactive widgets
- **Hybrid Storage:** Small data in memory-cached binary file for speed, large data in separate files to avoid memory overhead
- **Dynamic Sub-Keys:** Create nested keys without predefined schema
- **Version-Based Migration:** Automatic codec selection for seamless data format upgrades
- **Extensible:** Custom encryption, serialization, and storage adapters

---

## Installation

```yaml
dependencies:
  keep: ^0.3.0
```

---

## Quick Start

### 1. Define Storage Schema

```dart
import 'package:keep/keep.dart';

class AppStorage extends Keep {
  AppStorage() : super('app_v1');

  final counter = Keep.kInt('counter');
  final username = Keep.kString('username');
  final settings = Keep.kMap('settings');
  
  // Encrypted storage
  final token = Keep.kStringSecure('auth_token');
}

final storage = AppStorage();
```

### Keep ID & Multi-Instance
Pass a unique `id` to the constructor. This ensures stable storage paths even after code obfuscation and allows running multiple isolated instances:

```dart
final user1 = AppStorage('user_1');
final user2 = AppStorage('user_2'); // Completely isolated
```
---

## Initialization

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await storage.init();
  runApp(const MyApp());
}
```

### 3. Read & Write

```dart
// Write
await storage.counter.write(42);

// Read
final value = await storage.counter.read();
final valueOrDefault = await storage.counter.readSafe(0);

// Update
await storage.counter.update((current) => (current ?? 0) + 1);

// Remove
await storage.counter.remove();
```

### 4. Reactive UI

Automatically rebuild widgets on value changes:

```dart
KeepBuilder<int>(
  keepKey: storage.counter,
  builder: (context, value) {
    return Text('Counter: ${value ?? 0}');
  },
)
```

### 5. Stream Listening

```dart
storage.counter.stream.listen((key) async {
  print('Counter changed: ${await key.read()}');
});
```

---

## API Overview

### Storage Types

```dart
// Primitives
Keep.kInt('key')
Keep.kString('key')
Keep.kBool('key')
Keep.kDouble('key')

// Collections
Keep.kList<T>('key')
Keep.kMap('key')

// Encrypted variants (add 'Secure' suffix)
Keep.kIntSecure('key')
Keep.kStringSecure('key')
// ... etc

// Custom types
Keep.custom<T>(
  name: 'key',
  fromStorage: (value) => /* deserialize */,
  toStorage: (value) => /* serialize */,
)
Keep.customSecure<T>(
  name: 'key',
  fromStorage: (value) => /* deserialize */,
  toStorage: (value) => /* serialize */,
)
```

### Key Parameters

| Parameter | Type | Description | Default |
|-----------|------|-------------|---------|
| `name` | `String` | Unique key identifier | Required |
| `removable` | `bool` | Can be cleared with `clearRemovable()` | `false` |
| `useExternal` | `bool` | Store in separate file | `false` |
| `storage` | `KeepStorage?` | Custom storage adapter | `null` |

### KeepKey Methods

```dart
// Reading
await key.read()              // Returns T?
await key.readSafe(default)   // Returns T with fallback
key.readSync()                // Sync read (avoid for external storage)

// Writing
await key.write(value)
await key.update((current) => newValue)

// Management
await key.remove()
await key.exists              // Future<bool>
key.existsSync                // bool

// Reactivity
key.stream                    // Stream<KeepKey<T>>
```

---

## Advanced Usage

### Sub-Keys

Create nested keys dynamically:

```dart
final users = Keep.kString('users');

// Create sub-keys using call operator
final alice = users('alice');
await alice.write('Alice Data');

// Nested sub-keys
final aliceSettings = alice('settings');
await aliceSettings.write('Dark Mode');

// Chaining
await users('bob')('preferences').write('Minimal');

// Reading
final data = await alice.read(); // 'Alice Data'
```

### Custom Encryption

Implement `KeepEncrypter` for custom encryption:

```dart
import 'package:keep/keep.dart';
import 'package:encrypt/encrypt.dart' as crypt;

class AesEncrypter extends KeepEncrypter {
  late crypt.Encrypter _encrypter;
  final _iv = crypt.IV.fromLength(16);

  @override
  Future<void> init() async {
    final key = crypt.Key.fromUtf8('my-32-char-key-here!!!!!!!!');
    _encrypter = crypt.Encrypter(crypt.AES(key, mode: crypt.AESMode.gcm));
  }

  @override
  String encryptSync(String data) => _encrypter.encrypt(data, iv: _iv).base64;

  @override
  String decryptSync(String data) => _encrypter.decrypt64(data, iv: _iv);

  @override
  Future<String> encrypt(String data) async => encryptSync(data);

  @override
  Future<String> decrypt(String data) async => decryptSync(data);
}

// Usage
class AppStorage extends Keep {
  AppStorage() : super('secure_vault', encrypter: AesEncrypter());
  
  final pin = Keep.kIntSecure('pin');
}
```

### Custom Storage Adapter

Implement `KeepStorage` to use custom backends:

```dart
class DatabaseStorage extends KeepStorage {
  @override
  Future<void> init(Keep keep) async {
    // Initialize database
  }

  @override
  Future<void> write(KeepKey key, Object? value) async {
    // Store in database
  }

  @override
  Future<V?> read<V>(KeepKey key) async {
    // Read from database
    return null;
  }

  @override
  Future<void> remove(KeepKey key) async {
    // Delete from database
  }

  @override
  Future<bool> exists(KeepKey key) async => false;

  @override
  Future<void> clear() async {
    // Clear all data
  }

  @override
  Future<List<String>> getKeys() async => [];

  @override
  Future<void> removeKey(String storeName) async {}

  @override
  Future<void> clearRemovable() async {}

  @override
  Future<({String name, int flags, int version, KeepType type})?> readHeader(
    String storeName,
  ) async => null;

  @override
  V? readSync<V>(KeepKey key) => null;

  @override
  bool existsSync(KeepKey key) => false;
}

// Usage
class AppStorage extends Keep {
  AppStorage() : super('db_vault', externalStorage: DatabaseStorage());
  
  final logs = Keep.kList('logs', useExternal: true);
}
```

### Custom Serialization

For complex objects:

```dart
class User {
  final String name;
  final int age;
  
  User(this.name, this.age);
  
  Map<String, dynamic> toJson() => {'name': name, 'age': age};
  factory User.fromJson(Map json) => User(json['name'], json['age']);
}

final currentUser = Keep.custom<User>(
  name: 'user',
  fromStorage: (value) => value != null ? User.fromJson(value) : null,
  toStorage: (user) => user.toJson(),
);

await currentUser.write(User('Alice', 30));
```

### Error Handling

```dart
class AppStorage extends Keep {
  AppStorage() : super(
    'error_logger',
    onError: (e) {
      print('Storage error: ${e.message}');
      print('Key: ${e.key?.name}');
    },
  );
}
```

### External Storage

Use for large data to avoid memory overhead:

```dart
// Store large data in separate files
final bigData = Keep.kMap('large_dataset', useExternal: true);
final logs = Keep.kList('app_logs', useExternal: true);
```

### Version-Based Migration

Keep uses a version-based codec system for seamless storage format upgrades:

- **Automatic Detection:** Reads version byte and selects correct codec
- **Backward Compatible:** Old data remains readable 
- **Zero Downtime:** Gradual migration as data is accessed
- **Extensible:** Add new codecs without breaking existing data

**Current Format (V1):** JSON-based with obfuscation  
**Future Formats:** Binary serialization, compression, etc.

```dart
// Automatic codec selection
final codec = KeepCodec.of(bytes);
final entry = codec.decode();
```

See source code for codec implementation details.

---

## Cleanup

### Clear All

```dart
await storage.clear();
```

### Clear Removable Only

```dart
final cache = Keep.kString('cache', removable: true);
final temp = Keep.kMap('temp', removable: true);

// Later
await storage.clearRemovable(); // Only clears keys marked removable
```

---

## Performance

Benchmark results (1000 iterations):

| Operation | ops/sec |
|-----------|---------|
| Internal Write | ~28K |
| Internal Read | ~110K |
| Internal ReadSync | ~1M |
| External Write | ~2.4K |
| External Read | ~125K |
| Secure Write | ~6K |
| Secure Read | ~150K |

---

## Best Practices

- Use `readSafe()` instead of `read()` when default values are acceptable
- Avoid `readSync()` for external storage (blocks UI thread)
- Mark temporary data as `removable: true`
- Use external storage for data larger than 10KB
- Store encryption keys securely (e.g., `flutter_secure_storage`)
- Always await `init()` before first use

---

## Example

See [`example/lib/main.dart`](example/lib/main.dart) for a complete example.

```bash
cd example
flutter run
```

---

## License

MIT License - See [LICENSE](LICENSE) for details.

Developed by [GeceGibi](https://github.com/GeceGibi).
