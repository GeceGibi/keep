import 'package:flutter/material.dart';
import 'package:keep/keep.dart';

/// Extend Keep to define your storage schema.
/// Keys are defined as class fields - autocomplete friendly!
class AppStorage extends Keep {
  AppStorage()
      : super(
          'app_v1',
          encrypter: SimpleKeepEncrypter(secureKey: 'my-32-char-key-here!!!!'),
          onError: (e) => print('❌ Error: $e'),
        );

  // Standard keys
  final counter = Keep.kInt('counter');
  final username = Keep.kString('username');
  final isDarkMode = Keep.kBool('is_dark_mode');
  final rating = Keep.kDouble('rating');
  final tags = Keep.kList<String>('tags');
  final settings = Keep.kMap('settings');

  // Secure keys (encrypted)
  final authToken = Keep.kStringSecure('auth_token');
  final pinCode = Keep.kIntSecure('pin_code');

  // External storage (separate files)
  final largeData = Keep.kMap('large_data', useExternal: true);
  final secretFile = Keep.kStringSecure('secret_file', useExternal: true);
}

// Global instance
final storage = AppStorage();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await storage.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Keep Test',
      theme: ThemeData.dark(),
      home: const TestScreen(),
    );
  }
}

class TestScreen extends StatelessWidget {
  const TestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Keep Test')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          _TestButton('Run All Tests', _runAllTests),
          Divider(),
          _TestButton('Test Standard Keys', _testStandardKeys),
          _TestButton('Test Secure Keys', _testSecureKeys),
          _TestButton('Test External Storage', _testExternalStorage),
          _TestButton('Test Reactivity', _testReactivity),
          Divider(),
          _TestButton('Clear All', _clearAll, color: Colors.red),
        ],
      ),
    );
  }
}

class _TestButton extends StatelessWidget {
  const _TestButton(this.label, this.onPressed, {this.color});
  final String label;
  final VoidCallback onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: ElevatedButton(
        style: color != null
            ? ElevatedButton.styleFrom(backgroundColor: color)
            : null,
        onPressed: onPressed,
        child: Text(label),
      ),
    );
  }
}

void _runAllTests() async {
  print('\n=== KEEP TEST START ===\n');
  await _testStandardKeys();
  await _testSecureKeys();
  await _testExternalStorage();
  await _testReactivity();
  print('\n=== KEEP TEST COMPLETE ===\n');
}

Future<void> _testStandardKeys() async {
  print('--- Standard Keys ---');

  // Integer
  await storage.counter.write(42);

  print('counter: ${await storage.counter.read()}');

  // String
  await storage.username.write('JohnDoe');
  print('username: ${await storage.username.read()}');

  // Boolean
  await storage.isDarkMode.write(true);
  print('isDarkMode: ${await storage.isDarkMode.read()}');

  // Double
  await storage.rating.write(4.5);
  print('rating: ${await storage.rating.read()}');

  // List
  await storage.tags.write(['flutter', 'dart', 'keep']);
  print('tags: ${await storage.tags.read()}');

  // Map
  await storage.settings.write({'volume': 80, 'notifications': true});
  print('settings: ${await storage.settings.read()}');

  // Update
  await storage.counter.update((v) => (v ?? 0) + 1);
  print('counter after update: ${await storage.counter.read()}');
}

Future<void> _testSecureKeys() async {
  print('--- Secure Keys (Encrypted) ---');

  await storage.authToken.write('eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...');
  print('authToken (Async): ${await storage.authToken.read()}');
  print('authToken (Sync) : ${storage.authToken.readSync()}');

  await storage.pinCode.write(1234);
  print('pinCode (Async): ${await storage.pinCode.read()}');
  print('pinCode (Sync) : ${storage.pinCode.readSync()}');
}

Future<void> _testExternalStorage() async {
  print('--- External Storage (Separate Files) ---');

  await storage.largeData.write({
    'users': ['user1', 'user2', 'user3'],
    'metadata': {'count': 100},
  });
  print('largeData (Async): ${await storage.largeData.read()}');
  print('largeData (Sync) : ${storage.largeData.readSync()}');

  await storage.secretFile.write('Super secret content');
  print('secretFile (Async): ${await storage.secretFile.read()}');
  print('secretFile (Sync) : ${storage.secretFile.readSync()}');
}

Future<void> _testReactivity() async {
  print('--- Reactivity ---');

  final subscription = storage.counter.stream.listen((k) async {
    print('Stream: counter changed to ${await k.read()}');
  });

  await storage.counter.write(100);
  await storage.counter.write(200);
  await storage.counter.write(300);

  await Future.delayed(const Duration(milliseconds: 100));
  await subscription.cancel();
  print('Stream test complete');
}

Future<void> _clearAll() async {
  print('--- Clear All ---');
  await storage.clear();
  print('All data cleared');
}
