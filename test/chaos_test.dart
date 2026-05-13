import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:keep/keep.dart';

/// Concrete Keep implementation for chaos testing
class ChaosKeep extends Keep {
  ChaosKeep(super.id);

  /// Fast internal key for counter operations
  final KeepKeyPlain<int> counter = Keep.kInt('counter');

  /// Heavy external key for large data
  final KeepKeyPlain<String> bigData = Keep.kString('big_data', useExternal: true);

  /// Secure key for sensitive data
  final KeepKeySecure<String> secret = Keep.kStringSecure('secret');

  /// Removable key for cache operations
  final KeepKeyPlain<Map<String, dynamic>> cache = Keep.kMap('cache', removable: true);
}

void main() {
  late Directory tempDir;
  late ChaosKeep keep;

  setUp(() async {
    // Create a unique temp directory for each test run
    final projectDir = Directory.current;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    tempDir = Directory('${projectDir.path}/test/chaos_temp_$timestamp');

    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }

    await tempDir.create(recursive: true);

    keep = ChaosKeep('chaos_v1');
    await keep.init(path: tempDir.path);
  });

  tearDown(() async {
    await keep.dispose();

    // Grace period for pending IO operations
    await Future<void>.delayed(const Duration(milliseconds: 100));

    if (await tempDir.exists()) {
      try {
        await tempDir.delete(recursive: true);
      } catch (e) {
        print('Warning: Failed to cleanup temp dir: $e');
      }
    }
  });

  group('Chaos Tests', () {
    test(
      'High concurrency read/write/delete/clear operations',
      () async {
        final rng = Random();
        final operations = <Future<void>>[];
        const iterationCount = 100;

        print('Starting chaos with $iterationCount operations...');

        for (var i = 0; i < iterationCount; i++) {
          final opType = rng.nextInt(7); // 0..6 (added one more type)

          switch (opType) {
            case 0: // Write Internal
              operations.add(
                keep.counter.write(i).catchError((e) {
                  print('Write counter error: $e');
                }),
              );

            case 1: // Write External (Heavy)
              operations.add(
                keep.bigData.write('Chunk of data #$i ' * 50).catchError((e) {
                  print('Write bigData error: $e');
                }),
              );

            case 2: // Write Secure
              operations.add(
                keep.secret.write('s3cr3t_$i').catchError((e) {
                  print('Write secret error: $e');
                }),
              );

            case 3: // Write Removable
              operations.add(
                keep.cache
                    .write({
                      'step': i,
                      'ts': DateTime.now().toIso8601String(),
                      'random': rng.nextInt(1000),
                    })
                    .catchError((e) {
                      print('Write cache error: $e');
                    }),
              );

            case 4: // Random Removal
              if (rng.nextBool()) {
                operations.add(
                  keep.counter.remove().catchError((e) {
                    print('Remove counter error: $e');
                  }),
                );
              } else {
                operations.add(
                  keep.bigData.remove().catchError((e) {
                    print('Remove bigData error: $e');
                  }),
                );
              }

            case 5: // Clear Removable (occasional)
              if (i % 50 == 0) {
                operations.add(
                  keep.clearRemovable().catchError((e) {
                    print('Clear removable error: $e');
                  }),
                );
              }

            case 6: // Random Read operations
              final readType = rng.nextInt(4);
              switch (readType) {
                case 0:
                  operations.add(
                    keep.counter
                        .read()
                        .then((val) {
                          // Silently consume
                        })
                        .catchError((e) {
                          print('Read counter error: $e');
                        }),
                  );
                case 1:
                  operations.add(
                    keep.bigData
                        .read()
                        .then((val) {
                          // Silently consume
                        })
                        .catchError((e) {
                          print('Read bigData error: $e');
                        }),
                  );
                case 2:
                  operations.add(
                    keep.secret
                        .read()
                        .then((val) {
                          // Silently consume
                        })
                        .catchError((e) {
                          print('Read secret error: $e');
                        }),
                  );
                case 3:
                  operations.add(
                    keep.cache
                        .read()
                        .then((val) {
                          // Silently consume
                        })
                        .catchError((e) {
                          print('Read cache error: $e');
                        }),
                  );
              }
          }
        }

        // Execute all chaotic operations concurrently
        print('Waiting for ${operations.length} concurrent operations...');
        await Future.wait(operations);

        print('Chaos operations finished. Verifying stability...');

        // Verification Phase: Ensure system is still responsive
        await _verifySystemStability(keep);

        print('✓ Chaos test passed successfully.');
      },
      timeout: const Timeout(Duration(minutes: 5)),
    );

    test(
      'Extreme debounce stress test',
      () async {
        print('Starting extreme debounce test...');
        final operations = <Future<void>>[];

        // Rapidly write same key 1000 times with debounce
        for (var i = 0; i < 1000; i++) {
          operations.add(keep.counter.write(i));
          // Tiny delay to stress debounce mechanism
          if (i % 100 == 0) {
            await Future<void>.delayed(const Duration(microseconds: 1));
          }
        }

        await Future.wait(operations);

        // Final value should be written successfully
        final finalValue = await keep.counter.read();
        expect(finalValue, isNotNull, reason: 'Counter should have a value');

        print('✓ Debounce stress test passed. Final value: $finalValue');
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );

    test(
      'Concurrent write-read race conditions',
      () async {
        print('Starting concurrent write-read race test...');
        final operations = <Future<void>>[];

        // Simulate 50 concurrent writers and readers on same key
        for (var i = 0; i < 50; i++) {
          // Writer
          operations
            ..add(
              keep.counter.write(i).catchError((e) {
                print('Write error in race test: $e');
              }),
            )
            // Reader (immediate after write)
            ..add(
              keep.counter
                  .read()
                  .then((val) {
                    // Value could be anything due to race, just verify no crash
                  })
                  .catchError((e) {
                    print('Read error in race test: $e');
                  }),
            );
        }

        await Future.wait(operations);

        // Verify system is still functional
        await keep.counter.write(12345);
        final result = await keep.counter.read();
        expect(result, equals(12345));

        print('✓ Race condition test passed.');
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );
  });
}

/// Verifies that the Keep system is still stable and responsive after chaos
Future<void> _verifySystemStability(ChaosKeep keep) async {
  // Test internal storage
  const finalCounterVal = 999999;
  await keep.counter.write(finalCounterVal);
  final readCounter = await keep.counter.read();
  expect(
    readCounter,
    equals(finalCounterVal),
    reason: 'Internal storage should remain consistent after chaos',
  );

  // Test external storage
  const finalBigData = 'ValidData_End';
  await keep.bigData.write(finalBigData);
  final readBigData = await keep.bigData.read();
  expect(
    readBigData,
    equals(finalBigData),
    reason: 'External storage should remain consistent after chaos',
  );

  // Test secure storage
  const secretVal = 'FinalSecret';
  await keep.secret.write(secretVal);
  final readSecret = await keep.secret.read();
  expect(
    readSecret,
    equals(secretVal),
    reason: 'Secure storage should remain consistent after chaos',
  );

  // Test removable storage
  const cacheVal = {'verified': true, 'timestamp': 'end'};
  await keep.cache.write(cacheVal);
  final readCache = await keep.cache.read();
  expect(
    readCache,
    equals(cacheVal),
    reason: 'Removable storage should remain consistent after chaos',
  );
}
