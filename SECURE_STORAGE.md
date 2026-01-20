# 🔐 Flutter Secure Storage Adapter Example

This example demonstrates how to implement a custom `KeepStorage` adapter using the `flutter_secure_storage` package. This allows you to store sensitive data (like tokens or API keys) in the OS-level secure storage (Keychain for iOS/macOS, Keystore for Android).

## Implementation

```dart
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:keep/keep.dart';

class SecureKeepStorage extends KeepStorage {
  final _storage = const FlutterSecureStorage();
  late Keep _keep;

  @override
  Future<void> init(Keep keep) async => _keep = keep;

  @override
  Future<void> write(KeepKey key, Object? value) async {
    if (value == null) return remove(key);

    // Wrap the value into Keep's binary format
    final bytes = KeepCodec.current.encode(
      storeName: key.storeName,
      keyName: key.name,
      value: value,
      flags: (key.removable ? KeepCodec.flagRemovable : 0) | KeepCodec.flagSecure,
    );

    if (bytes != null) {
      // Secure storage only supports strings, so we use base64
      await _storage.write(key: key.storeName, value: base64Encode(bytes));
    }
  }

  @override
  Future<V?> read<V>(KeepKey key) async {
    final raw = await _storage.read(key: key.storeName);
    if (raw == null) return null;
    
    final entry = KeepCodec.of(base64Decode(raw)).decode();
    return entry?.value as V?;
  }

  @override
  Future<void> remove(KeepKey key) async => _storage.delete(key: key.storeName);

  @override
  Future<bool> exists(KeepKey key) async => _storage.containsKey(key: key.storeName);

  @override
  Future<List<String>> getKeys() async => (await _storage.readAll()).keys.toList();

  @override
  Future<void> clear() async => _storage.deleteAll();

  @override
  Future<void> removeKey(String storeName) async => _storage.delete(key: storeName);

  @override
  Future<void> clearRemovable() async {
    final keys = await getKeys();
    for (final k in keys) {
      final h = await header(k);
      if (h != null && (h.flags & KeepCodec.flagRemovable) != 0) {
        await _storage.delete(key: k);
      }
    }
  }

  @override
  Future<KeepHeader?> header(String storeName) async {
    final raw = await _storage.read(key: storeName);
    if (raw == null) return null;
    return KeepCodec.of(base64Decode(raw)).header();
  }

  // Secure Storage is async only
  @override
  V? readSync<V>(KeepKey key) => null;
  @override
  bool existsSync(KeepKey key) => false;
}
```

## Usage

Define your `Keep` instance with the secure storage adapter:

```dart
final secureKeep = Keep(
  'secure_vault',
  externalStorage: SecureKeepStorage(),
);

// Define a key that uses the external (secure) storage
final apiKey = Keep.kString('api_token', useExternal: true);

void main() async {
  await secureKeep.init();
  
  // Write to Keychain/Keystore
  await apiKey.write('sk-1234567890');
  
  // Read from Keychain/Keystore
  print(apiKey.cachedValue);
}
```
