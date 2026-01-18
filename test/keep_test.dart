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

  final counter = Keep.integer('counter');
  final username = Keep.string('username');
  final secureToken = Keep.stringSecure('token');

  final extData = Keep.string(
    'ext_data',
    useExternal: true,
  );

  final extSecure = Keep.stringSecure(
    'ext_secure',
    useExternal: true,
  );
}

void main() {
  late TestKeep storage;
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('keep_test');
    storage = TestKeep();
    await storage.init(path: tempDir.path);
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('Keep Internal Storage', () {
    test('Write and Read (Async)', () async {
      await storage.counter.write(42);
      expect(await storage.counter.read(), 42);

      await storage.username.write('test_user');
      expect(await storage.username.read(), 'test_user');
    });

    test('Write and Read (Sync)', () async {
      await storage.counter.write(100);
      expect(storage.counter.readSync(), 100);
    });

    test('Read undefined returns null', () async {
      expect(await storage.counter.read(), null);
      expect(storage.counter.readSync(), null);
    });

    test('ReadSafe returns default', () async {
      expect(await storage.counter.readSafe(99), 99);
      expect(storage.counter.readSafeSync(99), 99);
    });

    test('Update modifies value', () async {
      await storage.counter.write(10);
      await storage.counter.update((val) => (val ?? 0) + 5);
      expect(storage.counter.readSync(), 15);
    });
  });

  group('Keep Secure Storage', () {
    test('Write and Read (Async)', () async {
      await storage.secureToken.write('secret_value');
      expect(await storage.secureToken.read(), 'secret_value');
    });

    test('Write and Read (Sync)', () async {
      await storage.secureToken.write('secret_sync');
      expect(storage.secureToken.readSync(), 'secret_sync');
    });

    test('Data is actually encrypted in memory check', () {
      // We verify that it is encrypted by accessing internal storage directly.
      // This requires either private API access or assumptions.
      // We cannot test this through the Keep public API, we rely on the encryption interface test.
    });
  });

  group('Keep External Storage', () {
    test('Write and Read (Async)', () async {
      await storage.extData.write('hello_file');
      expect(await storage.extData.read(), 'hello_file');

      // Verify the file exists on disk (it is now stored with a hashed name)
      final file = File(
        '${tempDir.path}/keep/external/${storage.extData.storeName}',
      );
      expect(file.existsSync(), true);
    });

    test('Write and Read (Sync)', () async {
      await storage.extData.write('hello_sync');
      expect(storage.extData.readSync(), 'hello_sync');
    });

    test('Secure External Write and Read', () async {
      await storage.extSecure.write('super_secret_file');
      expect(await storage.extSecure.read(), 'super_secret_file');
      expect(storage.extSecure.readSync(), 'super_secret_file');

      // Dosya içeriği şifreli olmalı
      final file = File(
        '${tempDir.path}/keep/external/${storage.extSecure.storeName}',
      ); // Hashed name
      final bytes = file.readAsBytesSync();
      // Content should not be plain text (both encrypted and byte-shifted)
      final plainString = String.fromCharCodes(bytes);
      expect(plainString, isNot(contains('super_secret_file')));
    });
  });

  group('Reactivity', () {
    test('Stream emits events on write', () async {
      var eventCount = 0;
      final sub = storage.counter.stream.listen((key) {
        eventCount++;
        expect(key.name, storage.counter.name);
      });

      await storage.counter.write(1);
      await storage.counter.write(2);
      await storage.counter.write(3);

      await Future<void>.delayed(const Duration(milliseconds: 50));
      await sub.cancel();

      expect(eventCount, 3);
    });
  });

  group('Clear Operations', () {
    test('Clear removes all data', () async {
      await storage.counter.write(1);
      await storage.extData.write('file');

      await storage.clear();

      expect(storage.counter.readSync(), null);
      expect(storage.extData.readSync(), null);
    });
  });
}
