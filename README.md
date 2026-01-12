# Vault

**Vault** is a modern, type-safe, and reactive local storage solution for Flutter apps. It is designed to replace `SharedPreferences` with a more robust architecture that supports encryption, custom data models, and isolated file storage for large datasets.

## Features

- 🔒 **Secure by Default:** Built-in encryption support for sensitive data via `VaultKeySecure`.
- 🧱 **Type-Safe:** Define keys with specific types (`int`, `bool`, `List<String>`, `CustomObject`) to prevent runtime errors.
- ⚡ **Reactive:** Listen to changes on specific keys or the entire vault using Streams.
- 🚀 **Performant:** Uses Isolates for heavy encryption and file I/O to keep the UI smooth.
- 💾 **Hybrid Storage:** Keep small settings in a consolidated file (fast load) and large data in separate files (lazy load).
- 🛠 **Custom Models:** Built-in support for storing custom Dart objects via `toJson`/`fromJson`.

## Installation

Add `vault` to your `pubspec.yaml`:

```yaml
dependencies:
  vault: ^0.0.1
```

## Usage

### 1. Extend Vault

Create a storage class by extending `Vault` and define your keys as fields.

```dart
import 'package:vault/vault.dart';

class AppStorage extends Vault {
  AppStorage() : super(
    encrypter: SimpleVaultEncrypter(secureKey: 'your-32-char-key!!'),
  );

  // Standard keys
  late final counter = key.integer('counter');
  late final username = key.string('username');
  
  // Encrypted keys
  late final authToken = key.stringSecure('auth_token');
  
  // External storage (separate files)
  late final largeData = key.map('data', useExternalStorage: true);
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
await storage.init(path: '/custom/path', folderName: 'my_vault');
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

Vault provides a simple way to rebuild your UI when data changes.

```dart
VaultBuilder<int>(
  vaultKey: storage.counter,
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

By default, Vault stores keys in a single JSON file for fast startup. For large data (like long lists or cached API responses), use `useExternalStorage: true`. This stores the data in a separate file, keeping the main index light.

```dart
final largeData = vault.key.integer(
  'api_cache',
  useExternalStorage: true,
);
```

### Secured Keys

Use `integerSecure` (or custom secure keys) to automatically encrypt data before writing to disk.

```dart
final apiKey = vault.key.integerSecure('api_key');
```

### Custom Objects

Store any class by providing a serializer and deserializer.

```dart
class UserProfile {
  final String name;
  UserProfile(this.name);
  
  Map<String, dynamic> toJson() => {'name': name};
  static UserProfile fromJson(dynamic json) => UserProfile(json['name']);
}

final profile = vault.key.custom<UserProfile>(
  name: 'user_profile',
  fromStorage: UserProfile.fromJson,
  toStorage: (u) => u.toJson(),
);
```

## Documentation

All public APIs are documented with Dartdoc comments. Key classes:

- **`Vault`** – Main storage controller.
- **`VaultKey<T>`** – Typed key for read/write operations.
- **`VaultKeySecure<T>`** – Encrypted variant of `VaultKey`.
- **`VaultKeyManager`** – Factory for creating keys.
- **`VaultStorage`** – Abstract base for custom storage backends.
- **`VaultEncrypter`** – Interface for encryption implementations.
- **`VaultBuilder`** – Reactive widget for UI updates.

## Custom Encryption

You can implement `VaultEncrypter` to provide your own encryption logic (e.g., AES).
For heavy operations, use `Isolate.run` in async methods to keep the UI smooth.

```dart
class AesEncrypter extends VaultEncrypter {
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

## Planned Features

- [ ] Custom serialization support for `VaultKey` (`fromStorage`/`toStorage`)
- [ ] AES-GCM encryption option
- [ ] Migration tools for version upgrades
- [ ] Batch operations
