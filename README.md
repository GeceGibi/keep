# Vault

**Vault** is a modern, type-safe, and reactive local storage solution for Flutter apps. It is designed to replace `SharedPreferences` with a more robust architecture that supports encryption, custom data models, and isolated file storage for large datasets.

## Features

- 🔒 **Secure by Default:** Built-in encryption support for sensitive data.
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

### 1. Define your Storage

Extend the `Vault` class to define your storage schema. This creates a central place for all your app's persistent state.

```dart
import 'package:vault/vault.dart';

class AppStorage extends Vault {
  AppStorage() : super(
    fileVault: DefaultFileVault(),
    secureKey: 'your-32-char-secure-key-here-for-encryption',
    storageName: 'app_settings',
  );

  // Standard persistent keys
  late final themeMode = key.boolean('is_dark');
  late final counter = key.integer('launch_count');
  
  // Encrypted key (auto-encrypted on write, decrypted on read)
  late final authToken = secure.string('auth_token');

  // Complex object key
  late final userProfile = key.custom<UserProfile>(
    'profile',
    fromStorage: UserProfile.fromJson,
    toStorage: (user) => user.toJson(),
  );
}

// Create a global instance
final storage = AppStorage();
```

### 2. Initialize

Initialize the storage before running your app, usually in `main()`.

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await storage.init();
  runApp(const MyApp());
}
```

### 3. Read & Write

Access your data using the typed keys.

```dart
// Write
await storage.themeMode.write(true);
await storage.counter.write(42);

// Read
final isDark = await storage.themeMode.read(); // returns bool?
final count = await storage.counter.readSafe(0); // returns int (0 if null)

// Remove
await storage.authToken.remove();
```

### 4. Reactive UI

Vault provides a simple way to rebuild your UI when data changes.

```dart
VaultBuilder<bool>(
  vaultKey: storage.themeMode,
  builder: (context, isDark) {
    return MaterialApp(
      theme: (isDark ?? false) ? ThemeData.dark() : ThemeData.light(),
      home: HomePage(),
    );
  },
);
```

Or listen to the stream directly:

```dart
storage.counter.stream.listen((value) {
  print('Counter changed to: $value');
});
```

## Advanced Usage

### File System Isolation for Large Data

By default, Vault stores keys in a single JSON file for fast startup. For large data (like long lists or cached API responses), use `useFileSystem: true`. This stores the data in a separate distinct file, keeping the main index light.

```dart
// Stored in specific file on disk, not loaded into memory until requested
late final largeData = key.list<String>(
  'api_cache', 
  useFileSystem: true, 
);
```

### Secured Keys

Use the `secure` creator instead of `key` to automatically encrypt data before writing to disk.

```dart
// The content of this file is AES encrypted on disk
late final apiKey = secure.string('api_key');
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

// In AppStorage
late final profile = key.custom<UserProfile>(
  'user_profile',
  fromStorage: UserProfile.fromJson,
  toStorage: (u) => u.toJson(),
);
```
