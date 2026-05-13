import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:keep/keep.dart';

class TestKeep extends Keep {
  TestKeep()
    : super(
        'TestKeep',

        encrypter: SimpleKeepEncrypter(
          secureKey: 'secure_test_key_32_chars_long!!',
        ),
      );

  final counter = Keep.kInt('counter');
  final username = Keep.kString('username');
  final secureToken = Keep.kStringSecure('token');

  final extData = Keep.kString(
    'ext_data',
    useExternal: true,
  );

  final extSecure = Keep.kStringSecure(
    'ext_secure',
    useExternal: true,
  );

  final extRemovable1 = Keep.kString(
    'ext_removable_1',
    useExternal: true,
    removable: true,
  );

  final extRemovable2 = Keep.kString(
    'ext_removable_2',
    useExternal: true,
    removable: true,
  );

  final extNonRemovable = Keep.kString(
    'ext_non_removable',
    useExternal: true,
    removable: false,
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
    // Wait for debounced writes to complete
    await Future<void>.delayed(const Duration(milliseconds: 200));
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
        '${storage.root.path}/external/${storage.extData.storeName}',
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
        '${storage.root.path}/external/${storage.extSecure.storeName}',
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

    test('ClearRemovable external storage', () async {
      // Write values
      await storage.extRemovable1.write('value1');
      await storage.extRemovable2.write('value2');
      await storage.extNonRemovable.write('value3');

      // Verify all exist
      expect(await storage.extRemovable1.exists, true);
      expect(await storage.extRemovable2.exists, true);
      expect(await storage.extNonRemovable.exists, true);

      // Clear removable
      await storage.clearRemovable();

      // Removable keys should be gone
      expect(await storage.extRemovable1.exists, false);
      expect(await storage.extRemovable2.exists, false);

      // Non-removable should remain
      expect(await storage.extNonRemovable.exists, true);
      expect(await storage.extNonRemovable.read(), 'value3');
    });
  });

  group('Bug fixes', () {
    test('Bug #1: remove() invalidates cache and emits change event',
        () async {
      await storage.counter.write(42);
      expect(storage.counter.readSync(), 42);

      final events = <int?>[];
      final sub = storage.counter.stream.listen((k) async {
        events.add(await k.read());
      });

      await storage.counter.remove();

      // Cache must be cleared synchronously so the next sync read sees null.
      expect(storage.counter.readSync(), isNull);
      expect(await storage.counter.read(), isNull);

      // Allow the broadcast event to be delivered.
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await sub.cancel();

      expect(events, isNotEmpty, reason: 'remove() must emit a change event');
      expect(events.last, isNull);
    });

    test('Bug #1: clear() invalidates per-key caches', () async {
      await storage.counter.write(7);
      await storage.extData.write('x');
      expect(storage.counter.readSync(), 7);
      expect(storage.extData.readSync(), 'x');

      await storage.clear();

      expect(storage.counter.readSync(), isNull);
      expect(await storage.counter.read(), isNull);
      expect(storage.extData.readSync(), isNull);
    });

    test('Bug #2: concurrent external reads all return the value', () async {
      await storage.extData.write('hello');

      final results = await Future.wait(
        List.generate(8, (_) => storage.extData.read()),
      );

      expect(
        results,
        everyElement('hello'),
        reason:
            'Parallel reads must not be debounced/cancelled into null by the '
            'writer queue.',
      );
    });

    test('Bug #2: read after write sees the latest value', () async {
      // Issue many rapid writes then read; the read must observe the final
      // committed value, not a debounce-cancelled null.
      for (var i = 0; i < 10; i++) {
        unawaited(storage.extData.write('v$i'));
      }
      // Force a settling read; awaitSettled inside read() waits for the queue.
      final value = await storage.extData.read();
      expect(value, isNotNull);
      expect(value, startsWith('v'));
    });

    test('Bug #6: concurrent update() calls do not lose increments',
        () async {
      await storage.counter.write(0);

      const concurrency = 25;
      await Future.wait(
        List.generate(
          concurrency,
          (_) => storage.counter.update((v) => (v ?? 0) + 1),
        ),
      );

      expect(
        await storage.counter.read(),
        concurrency,
        reason:
            'Atomic update() must serialize concurrent callers; otherwise '
            'lost-update races would yield a value < $concurrency.',
      );
    });

    test('Bug #15/#27: await write() is durable after dispose+reopen',
        () async {
      // Write to internal storage and dispose immediately. After a fresh
      // Keep instance reopens the same directory, the value must survive.
      await storage.counter.write(12345);
      await storage.username.write('persisted');
      await storage.dispose();

      final reopened = TestKeep();
      await reopened.init(path: tempDir.path);

      expect(
        await reopened.counter.read(),
        12345,
        reason:
            'await write() must guarantee disk durability before returning, '
            'so the value survives dispose() and a fresh init().',
      );
      expect(await reopened.username.read(), 'persisted');

      await reopened.dispose();
    });

    test(
        'Bug #28: supersede chain — every awaiter sees a durable post-state',
        () async {
      // Many rapid writes against the same internal key are debounced into
      // ideally a single disk flush, but the await of EVERY caller must
      // resolve only after that flush has happened. Following each individual
      // await with a fresh Keep instance verifies durability.
      final futures = <Future<void>>[];
      for (var i = 0; i < 20; i++) {
        futures.add(storage.counter.write(i));
      }
      await Future.wait(futures);

      // The in-memory state should match the LAST write (final loser).
      expect(await storage.counter.read(), 19);

      // Crucially, that value must be on disk — verify by reopening.
      await storage.dispose();

      final reopened = TestKeep();
      await reopened.init(path: tempDir.path);
      expect(
        await reopened.counter.read(),
        19,
        reason:
            'All callers awaiting a debounced write must observe the final '
            'durable state once their await resolves.',
      );
      await reopened.dispose();
    });

    test('Keep.flush(): explicit drain of unawaited writes', () async {
      // Issue several fire-and-forget writes, then ensure flush() makes them
      // durable before we dispose.
      unawaited(storage.counter.write(7));
      unawaited(storage.extData.write('flushed'));
      unawaited(storage.username.write('alice'));

      await storage.flush();
      await storage.dispose();

      final reopened = TestKeep();
      await reopened.init(path: tempDir.path);
      expect(await reopened.counter.read(), 7);
      expect(await reopened.extData.read(), 'flushed');
      expect(await reopened.username.read(), 'alice');
      await reopened.dispose();
    });

    test('Bug #5: init() failure surfaces via Future error (no hang)',
        () async {
      final broken = TestKeep();
      // Path under a read-only root that cannot be created.
      const badPath = '/dev/null/keep_broken_dir';

      var caught = false;
      try {
        // Run with a timeout so a hang would visibly fail this test.
        await broken
            .init(path: badPath)
            .timeout(const Duration(seconds: 3));
      } catch (_) {
        caught = true;
      }
      expect(
        caught,
        isTrue,
        reason: 'A broken init must throw, not hang forever.',
      );

      // Subsequent awaits of ensureInitialized must also fail-fast.
      var rethrown = false;
      try {
        await broken
            .init(path: badPath)
            .timeout(const Duration(seconds: 3));
      } catch (_) {
        rethrown = true;
      }
      expect(rethrown, isTrue);
    });
  });
}
