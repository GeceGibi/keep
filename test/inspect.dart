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

  final username = Keep.string('username');
  final secureToken = Keep.stringSecure('token');
  final extData = Keep.string('ext_data', useExternalStorage: true);
  final extSecure = Keep.stringSecure('ext_secure', useExternalStorage: true);
}

void main() {
  test('Generate Data for Inspection', () async {
    final dir = Directory('${Directory.current.path}/test/keep_data_inspect');

    // Clean start
    // if (dir.existsSync()) {
    //   await dir.delete(recursive: true);
    // }
    await dir.create(recursive: true);

    print('Storage Path: ${dir.path}');

    final storage = TestKeep();
    await storage.init(path: dir.path);

    print(storage.keys);
    print(await storage.keysExternal);

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

    // Wait for internal storage debounce timer (150ms) + IO
    await Future<void>.delayed(const Duration(seconds: 1));

    print('Data generated successfully! Check ${dir.path}');
  });
}
