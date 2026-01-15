# Keep

**Keep** is a modern, type-safe, and reactive local storage solution for Flutter apps. It is designed to replace `SharedPreferences` with a more robust architecture that supports encryption, custom data models, and isolated file storage for large datasets.

## Features

- **Secure by Default:** Built-in encryption support and **Byte Shifting** obfuscation for disk security.
- **Type-Safe:** Define keys with specific types (`int`, `bool`, `List<String>`, `CustomObject`).
- **Reactive:** Listen to changes on specific keys or the entire keep using Streams.
- **Performant & Isolated:** UI stays smooth with background I/O and isolate-based processing.
- **Hybrid Storage:** Fast load for small values, lazy load for large files.
- **Discovery:** Automatically discovers and maps encrypted keys even for uninitialized (`late`) fields.

## Installation

Add `keep` to your `pubspec.yaml`:

```yaml
dependencies:
  keep: ^0.0.1
```

## Usage

### 1. Define Your Storage
Extend `Keep` and define your keys as `final` fields using the static factories.

```dart
class AppStorage extends Keep {
  final counter = Keep.integer('counter');
  final username = Keep.string('username');
  final authToken = Keep.stringSecure('auth_token');
  final settings = Keep.map('settings', useExternalStorage: true);
}

final storage = AppStorage();
```

### 2. Initialize

Initialize the storage before running your app. Path defaults to `getApplicationSupportDirectory()`.

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await storage.init(); // Uses app support directory by default
  runApp(const MyApp());
}
```

Or specify a custom path:

```dart
await storage.init(path: '/custom/path', folderName: 'my_keep');
```

### 3. Read & Write

```dart
// Write
await counter.write(42);

// Read (Async)
final count = await counter.read(); // returns int?
final safeCount = await counter.readSafe(0); // returns int (0 if null)

// Read (Sync) - Great for non-async contexts
final syncCount = counter.readSync();

// Remove
await counter.remove();
```

### 4. Reactive UI

Keep provides a simple way to rebuild your UI when data changes.

```dart
KeepBuilder<int>(
  keepKey: storage.counter,
  builder: (context, value) {
    return Text('Count: ${value ?? 0}');
  },
);
```

Or listen to the stream directly:

```dart
storage.counter.stream.listen((key) async {
  final value = await key.read();
  print('Counter changed to: $value');
});
```

## Advanced Usage

### File System Isolation for Large Data

By default, Keep stores keys in a single JSON file for fast startup. For large data (like long lists or cached API responses), use `useExternalStorage: true`. This stores the data in a separate file, keeping the main index light.

```dart
final largeData = Keep.integer(
  'api_cache',
  useExternalStorage: true,
);
```

### Secured Keys

Use `Keep.integerSecure` (or custom secure keys) to automatically encrypt data before writing to disk.

```dart
final apiKey = Keep.integerSecure('api_key');
```

### Custom Objects

Store any class by providing a serializer and deserializer.

```dart
class UserProfile {
  final String name;
  UserProfile(this.name);
  
  Map<String, dynamic> toJson() => {'name': name};
  static UserProfile fromJson(dynamic json) => UserProfile(json['json_data']);
}

final profile = Keep.custom<UserProfile>(
  name: 'user_profile',
  fromStorage: UserProfile.fromJson,
  toStorage: (u) => u.toJson(),
);
```

### Sub-keys

You can create dynamic sub-keys by calling a key instance. This is useful for lists, category-based data, or dynamic paths.

```dart
final notes = Keep.string('notes');

// Creates keys named "notes.work", "notes.personal", etc.
await notes('work').write('Finish documentation');
await notes('personal').write('Buy milk');

final workNote = await notes('work').read();
```

## Documentation

All public APIs are documented with Dartdoc comments. Key classes:

- **`Keep`** – Main storage controller.
- **`KeepKey<T>`** – Typed key for read/write operations.
- **`KeepKeySecure<T>`** – Encrypted variant of `KeepKey`.
- **`KeepStorage`** – Abstract base for custom storage backends.
- **`KeepEncrypter`** – Interface for encryption implementations.
- **`KeepBuilder`** – Reactive widget for UI updates.

## Custom Encryption

You can implement `KeepEncrypter` to provide your own encryption logic (e.g., AES).
For heavy operations, use `Isolate.run` in async methods to keep the UI smooth.

```dart
class AesEncrypter extends KeepEncrypter {
  @override
  Future<void> init() async {
    // Initialize keys...
  }

  @override
  FutureOr<String> encrypt(String data) {
    // Offload heavy encryption to an isolate
    return Isolate.run(() => encryptSync(data));
  }

  @override
  String encryptSync(String data) {
    // Implement synchronous encryption logic
    return _aesEncrypt(data);
  }

  @override
  FutureOr<String> decrypt(String data) {
    return Isolate.run(() => decryptSync(data));
  }

  @override
  String decryptSync(String data) {
    return _aesDecrypt(data);
  }
}
```

## Roadmap & Planned Features

- [ ] **Data Integrity:** Add Checksum/CRC32 validation for binary files.
- [ ] **Atomicity:** Implement Shadow Backups (.bak) to recover from system crashes.
- [ ] **Migration:** Tools for schema versioning and data migrations.
- [ ] **Compression:** Optional GZip/Brotli support for large external files.
