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

    u1.stream.listen((_) => print('u1: changed'));

    await u1.write('u1-val');
    await u2.write('u2-val');
    await u3.write('u3-val');

    print('Sub-keys created.');

    // Listing logic (once implemented in SubKeyManager)
    // final keys = await storage.users.subKeys.keys;
    // print('Keys: $keys');

    print('\nChecking values:');
    print('u1: ${await u1.read()}');
    print('u2: ${await u2.read()}');
    print('u3: ${await u3.read()}');

    print('Sub-keys: ${storage.users}');

    await Future<void>.delayed(const Duration(seconds: 1));
    print('\nData generated successfully! Check ${dir.path}');
  });
}
