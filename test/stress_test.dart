import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:keep/keep.dart';

class StressKeep extends Keep {
  StressKeep()
    : super(
        encrypter: SimpleKeepEncrypter(
          secureKey: 'stress_test_key_32_chars_long!!',
        ),
      );

  final KeepKey<String> stressKey = Keep.string('stress_key');
  final KeepKey<String> stressExt = Keep.string(
    'stress_ext',
    useExternal: true,
  );
  final KeepKey<String> stressSecure = Keep.stringSecure('stress_secure');
  final KeepKey<String> stressSecureExt = Keep.stringSecure(
    'stress_secure_ext',
    useExternal: true,
  );
}

void main() {
  test('Stress Test - ops/sec', () async {
    final dir = Directory('${Directory.current.path}/test/keep_stress');

    if (dir.existsSync()) {
      await dir.delete(recursive: true);
    }
    await dir.create(recursive: true);

    final keep = StressKeep();
    await keep.init(path: dir.path);

    const iterations = 1000;

    // Internal Write
    final writeStart = Stopwatch()..start();
    for (var i = 0; i < iterations; i++) {
      await keep.stressKey.write('value_$i');
    }
    writeStart.stop();

    final writeOps = (iterations / writeStart.elapsedMilliseconds * 1000)
        .round();
    print(
      'Internal Write: $writeOps ops/sec (${writeStart.elapsedMilliseconds}ms)',
    );

    // Internal Read (async)
    final readStart = Stopwatch()..start();
    for (var i = 0; i < iterations; i++) {
      await keep.stressKey.read();
    }
    readStart.stop();

    final readOps = (iterations / readStart.elapsedMilliseconds * 1000).round();
    print(
      'Internal Read: $readOps ops/sec (${readStart.elapsedMilliseconds}ms)',
    );

    // Internal ReadSync
    final syncStart = Stopwatch()..start();
    for (var i = 0; i < iterations; i++) {
      keep.stressKey.readSync();
    }
    syncStart.stop();

    final syncMs = syncStart.elapsedMilliseconds;
    final syncOps = syncMs > 0
        ? (iterations / syncMs * 1000).round()
        : iterations * 1000;

    print(
      'Internal ReadSync: $syncOps ops/sec (${syncStart.elapsedMilliseconds}ms)',
    );

    // External Write
    final extWriteStart = Stopwatch()..start();
    for (var i = 0; i < iterations; i++) {
      await keep.stressExt.write('ext_value_$i');
    }
    extWriteStart.stop();

    final extWriteOps = (iterations / extWriteStart.elapsedMilliseconds * 1000)
        .round();
    print(
      'External Write: $extWriteOps ops/sec (${extWriteStart.elapsedMilliseconds}ms)',
    );

    // External Read
    final extReadStart = Stopwatch()..start();
    for (var i = 0; i < iterations; i++) {
      await keep.stressExt.read();
    }
    extReadStart.stop();

    final extReadOps = (iterations / extReadStart.elapsedMilliseconds * 1000)
        .round();
    print(
      'External Read: $extReadOps ops/sec (${extReadStart.elapsedMilliseconds}ms)',
    );

    print('\n--- Secure (Encrypted) ---');

    // Internal Secure Write
    final secWriteStart = Stopwatch()..start();
    for (var i = 0; i < iterations; i++) {
      await keep.stressSecure.write('secure_value_$i');
    }
    secWriteStart.stop();

    final secWriteOps = (iterations / secWriteStart.elapsedMilliseconds * 1000)
        .round();
    print(
      'Internal Secure Write: $secWriteOps ops/sec (${secWriteStart.elapsedMilliseconds}ms)',
    );

    // Internal Secure Read
    final secReadStart = Stopwatch()..start();
    for (var i = 0; i < iterations; i++) {
      await keep.stressSecure.read();
    }
    secReadStart.stop();

    final secReadOps = (iterations / secReadStart.elapsedMilliseconds * 1000)
        .round();
    print(
      'Internal Secure Read: $secReadOps ops/sec (${secReadStart.elapsedMilliseconds}ms)',
    );

    // External Secure Write
    final secExtWriteStart = Stopwatch()..start();
    for (var i = 0; i < iterations; i++) {
      await keep.stressSecureExt.write('sec_ext_value_$i');
    }
    secExtWriteStart.stop();

    final secExtWriteOps =
        (iterations / secExtWriteStart.elapsedMilliseconds * 1000).round();
    print(
      'External Secure Write: $secExtWriteOps ops/sec (${secExtWriteStart.elapsedMilliseconds}ms)',
    );

    // External Secure Read
    final secExtReadStart = Stopwatch()..start();
    for (var i = 0; i < iterations; i++) {
      await keep.stressSecureExt.read();
    }
    secExtReadStart.stop();

    final secExtReadOps =
        (iterations / secExtReadStart.elapsedMilliseconds * 1000).round();
    print(
      'External Secure Read: $secExtReadOps ops/sec (${secExtReadStart.elapsedMilliseconds}ms)',
    );

    await Future<void>.delayed(const Duration(seconds: 1));
  });
}
