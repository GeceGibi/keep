import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('StandardMessageCodec examples', () {
    print('=== STANDARD MESSAGE CODEC TEST ===\n');
    testStandardMessageCodec();
  });

  test('Analyze main.keep file', () async {
    print('\n=== MAIN.KEEP ANALYSIS ===\n');

    final file = File('test/storage/main.keep');

    if (!file.existsSync()) {
      print('File not found: ${file.path}');
      return;
    }

    final bytes = await file.readAsBytes();
    print('Total size: ${bytes.length} bytes\n');

    print('=== HEX DUMP ===');
    hexDump(bytes);

    print('\n=== STRUCTURE ===');
    analyzeStructure(bytes);
  });
}

void testStandardMessageCodec() {
  const codec = StandardMessageCodec();

  // Test 1: Simple map
  print('Test 1: Simple Map');
  final data1 = {
    'name': 'ali',
    'age': 25,
    'active': true,
  };

  final encoded1 = codec.encodeMessage(data1)!;
  final bytes1 = Uint8List.view(encoded1.buffer);
  print('Original: $data1');
  print('Encoded size: ${bytes1.length} bytes');
  print(
    'Hex: ${bytes1.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}',
  );

  final decoded1 = codec.decodeMessage(encoded1);
  print('Decoded: $decoded1');
  print('Match: ${data1.toString() == decoded1.toString()}\n');

  // Test 2: Nested structure
  print('Test 2: Nested Map');
  final data2 = {
    'user': {
      'name': 'veli',
      'tags': ['a', 'b', 'c'],
      'meta': {
        'score': 100,
      },
    },
  };

  final encoded2 = codec.encodeMessage(data2)!;
  final bytes2 = Uint8List.view(encoded2.buffer);
  print('Original: $data2');
  print('Encoded size: ${bytes2.length} bytes');
  print(
    'First 32 bytes: ${bytes2.take(32).map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}',
  );

  final decoded2 = codec.decodeMessage(encoded2);
  print('Decoded: $decoded2');
  print('Match: ${data2.toString() == decoded2.toString()}\n');

  // Test 3: Map of entries (KeepStorage case)
  print('Test 3: Storage-like Map');
  final data3 = {
    'key1': ['name1', 0, 'value1', 1, 'string'],
    'key2': ['name2', 1, 42, 1, 'int'],
    'key3': ['name3', 0, true, 1, 'bool'],
  };

  final encoded3 = codec.encodeMessage(data3)!;
  final bytes3 = Uint8List.view(encoded3.buffer);
  print('Original: $data3');
  print('Encoded size: ${bytes3.length} bytes');
  hexDump(bytes3);

  final decoded3 = codec.decodeMessage(encoded3);
  print('\nDecoded: $decoded3');
  print('Match: ${data3.toString() == decoded3.toString()}');
}

void hexDump(Uint8List bytes, {int bytesPerLine = 16}) {
  for (var i = 0; i < bytes.length; i += bytesPerLine) {
    final line = bytes.sublist(
      i,
      i + bytesPerLine > bytes.length ? bytes.length : i + bytesPerLine,
    );

    // Offset
    final offset = i.toRadixString(16).padLeft(8, '0');

    // Hex
    final hex = line.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');

    // ASCII
    final ascii = line
        .map((b) => b >= 32 && b <= 126 ? String.fromCharCode(b) : '.')
        .join();

    print('$offset  ${hex.padRight(bytesPerLine * 3)}  $ascii');
  }
}

void analyzeStructure(Uint8List bytes) {
  if (bytes.isEmpty) {
    print('Empty file');
    return;
  }

  print('First byte (version?): ${bytes[0]}');

  // Length-prefix parsing gibi dene
  var offset = 0;
  var entryCount = 0;

  while (offset + 4 <= bytes.length) {
    final len =
        (bytes[offset] << 24 |
                bytes[offset + 1] << 16 |
                bytes[offset + 2] << 8 |
                bytes[offset + 3])
            .toUnsigned(32);

    print('\nEntry ${++entryCount} at offset $offset:');
    print('  Length: $len bytes');

    offset += 4;

    if (offset + len > bytes.length) {
      print('  ERROR: Length exceeds file size');
      break;
    }

    final payload = bytes.sublist(offset, offset + len);
    print(
      '  First 32 bytes: ${payload.take(32).map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}',
    );

    offset += len;
  }

  print('\nTotal entries: $entryCount');
  print('Bytes parsed: $offset / ${bytes.length}');
}
