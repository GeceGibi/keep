import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:keep/keep.dart';

class TestKeep extends Keep {
  TestKeep()
    : super(
        encrypter: SimpleKeepEncrypter(
          secureKey: 'secure_test_key_32_chars_long!!',
        ),
      );

  final KeepKey<String> username = Keep.string('username');
  final KeepKey<String> secureToken = Keep.stringSecure('token');
  final KeepKey<String> extData = Keep.string(
    'ext_data',
    useExternal: true,
  );

  final KeepKey<String> extSecure = Keep.stringSecure(
    'ext_secure',
    useExternal: true,
  );

  final KeepKey<String> users = Keep.string('users');
}

void main() {
  test('Generate Data for Inspection', () async {
    final dir = Directory('${Directory.current.path}/test/keep_data_inspect');

    // Clean start
    if (dir.existsSync()) {
      await dir.delete(recursive: true);
    }
    await dir.create(recursive: true);

    print('Storage Path: ${dir.path}');

    final storage = TestKeep();
    await storage.init(path: dir.path);

    print(storage.keys);

    // 1. Internal Plain
    print('Internal Plain: ${await storage.username.read()}');
    await storage.username.write('john_doe_plain');

    // 2. Internal Secure
    print('Internal Secure: ${await storage.secureToken.read()}');
    await storage.secureToken.write('secret_token_123');

    // 3. External Plain
    print('External Plain: ${await storage.extData.read()}');
    await storage.extData.write('external_file_content_plain');

    // 4. External Secure
    print('External Secure: ${await storage.extSecure.read()}');
    await storage.extSecure.write('external_secret_content');

    // 5. Sub-keys
    print('Creating simple sub-keys...');

    final u1 = storage.users('u1');
    final u2 = storage.users('u2');
    final u3 = storage.users('u3');

    // Test: Sub-keys should be discoverable even before write()
    print('\nBefore write() - toList():');
    final keysBeforeWrite = await storage.users.keys.toList();
    print(
      'Found ${keysBeforeWrite.length} sub-keys: ${keysBeforeWrite.map((k) => k.name).toList()}',
    );

    u1.stream.listen((_) => print('u1: changed'));

    await u1.write('u1-val');
    await u2.write('u2-val');
    await u3.write('u3-val');

    print('Sub-keys created.');

    // Test SubKeyManager.toList()
    print('\nTesting SubKeyManager.toList()...');
    final subKeys = await storage.users.keys.toList();
    print(
      'Found ${subKeys.length} sub-keys: ${subKeys.map((k) => k.name).toList()}',
    );

    // Verify we can read from discovered keys
    for (final key in subKeys) {
      final value = await key.read();
      print('  ${key.name} = $value');
    }

    print('\nChecking values:');
    print('u1: ${await u1.read()}');
    print('u2: ${await u2.read()}');
    print('u3: ${await u3.read()}');

    print('Sub-keys: ${storage.users}');

    // Test dynamic keys
    print('\n--- Testing Dynamic Keys ---');
    final cities = storage.users; // Reusing for test

    for (var cityId in [1, 2, 3]) {
      final counties = cities(cityId.toString());
      await counties.write('City $cityId data');
    }

    print('Dynamic keys created (1, 2, 3)');

    // Now instantiate only key "2" without writing
    final key2Again = cities('2');
    print('Instantiated key "2" again (no write)');

    // toList should find: u1, u2, u3, 1, 2, 3 (from storage + registry)
    final allKeys = await cities.keys.toList();
    print('All keys found: ${allKeys.map((k) => k.name).toList()}');

    await Future<void>.delayed(const Duration(seconds: 1));
    print('\nData generated successfully! Check ${dir.path}');
  });
}
