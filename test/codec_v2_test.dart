import 'package:flutter_test/flutter_test.dart';
import 'package:keep/src/codec/codec.dart';

void main() {
  group('Codec V1 vs V2', () {
    test('V1 JSON encoding works', () {
      final encoded = KeepCodec.forVersion(1).encode(
        storeName: 'test_key',
        keyName: 'testKey',
        value: {'name': 'ali', 'age': 25},
        flags: 0,
      );

      expect(encoded, isNotNull);

      final decoded = KeepCodec.forVersion(1).decode(
        KeepCodec.current.unShiftBytes(encoded!),
      );

      expect(decoded, isNotNull);
      expect(decoded!.value, {'name': 'ali', 'age': 25});
      expect(decoded.version, 1);
    });

    test('V2 StandardMessageCodec encoding works', () {
      final encoded = KeepCodec.forVersion(2).encode(
        storeName: 'test_key',
        keyName: 'testKey',
        value: {'name': 'ali', 'age': 25},
        flags: 0,
      );

      expect(encoded, isNotNull);

      final decoded = KeepCodec.forVersion(2).decode(
        KeepCodec.current.unShiftBytes(encoded!),
      );

      expect(decoded, isNotNull);
      expect(decoded!.value, {'name': 'ali', 'age': 25});
      expect(decoded.version, 2);
    });

    test('V2 is more compact than V1', () {
      final testData = {
        'name': 'test',
        'age': 25,
        'active': true,
        'scores': [100, 200, 300],
      };

      final v1Encoded = KeepCodec.forVersion(1).encode(
        storeName: 'test_key',
        keyName: 'testKey',
        value: testData,
        flags: 0,
      );

      final v2Encoded = KeepCodec.forVersion(2).encode(
        storeName: 'test_key',
        keyName: 'testKey',
        value: testData,
        flags: 0,
      );

      print('V1 size: ${v1Encoded!.length} bytes');
      print('V2 size: ${v2Encoded!.length} bytes');
      print(
        'Savings: ${((v1Encoded.length - v2Encoded.length) / v1Encoded.length * 100).toStringAsFixed(1)}%',
      );

      expect(v2Encoded.length, lessThan(v1Encoded.length));
    });

    test('Migration: V1 data can be decoded and re-encoded as V2', () {
      // 1. Encode with V1
      final v1Encoded = KeepCodec.forVersion(1).encode(
        storeName: 'test_key',
        keyName: 'testKey',
        value: {'name': 'ali', 'age': 25},
        flags: 1,
      );

      // 2. Decode with KeepCodec.of (auto-detects version from shifted bytes)
      final decoded = KeepCodec.of(v1Encoded!).decode();

      expect(decoded, isNotNull);
      expect(decoded!.version, 1); // Original was V1
      expect(decoded.value, {'name': 'ali', 'age': 25});

      // 3. Re-encode with V2 (current)
      final v2Encoded = KeepCodec.current.encode(
        storeName: decoded.storeName,
        keyName: decoded.name,
        value: decoded.value,
        flags: decoded.flags,
      );

      // 4. Verify V2 decoding
      final v2Decoded = KeepCodec.forVersion(2).decode(
        KeepCodec.current.unShiftBytes(v2Encoded!),
      );

      expect(v2Decoded, isNotNull);
      expect(v2Decoded!.version, 2); // Now V2
      expect(v2Decoded.value, decoded.value);
      expect(v2Decoded.flags, decoded.flags);
    });

    test('V2 handles various types correctly', () {
      final testCases = [
        {'name': 'int', 'value': 42},
        {'name': 'double', 'value': 3.14},
        {'name': 'string', 'value': 'hello'},
        {'name': 'bool', 'value': true},
        {
          'name': 'list',
          'value': [1, 2, 3],
        },
        {
          'name': 'map',
          'value': {'a': 1, 'b': 2},
        },
        {
          'name': 'nested',
          'value': {
            'user': {
              'name': 'ali',
              'tags': ['a', 'b'],
            },
          },
        },
      ];

      for (final test in testCases) {
        final encoded = KeepCodec.current.encode(
          storeName: 'test',
          keyName: test['name']! as String,
          value: test['value'],
          flags: 0,
        );

        final decoded = KeepCodec.current.decode(
          KeepCodec.current.unShiftBytes(encoded!),
        );

        expect(
          decoded?.value,
          test['value'],
          reason: 'Failed for ${test['name']}',
        );
      }
    });
  });
}
