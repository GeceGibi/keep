import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:vault/vault.dart';

// --- 1. Custom Data Model ---
class UserProfile {
  final String id;
  final String bio;
  final int level;

  UserProfile({required this.id, required this.bio, required this.level});

  Map<String, dynamic> toJson() => {'id': id, 'bio': bio, 'level': level};

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      bio: json['bio'] as String,
      level: json['level'] as int,
    );
  }

  @override
  String toString() => 'User(id: $id, level: $level)';
}

// --- 2. Define Vault ---
class AppStorage extends Vault {
  AppStorage();
  late final test = key.integer('test');
  late final testSecure = key.integerSecure('test');
}

final storage = AppStorage();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final appSupportDir = await getApplicationSupportDirectory();

  await storage.init(path: appSupportDir.path);

  runApp(const MyApp());
}

// --- 3. UI Application ---
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vault Demo',
      home: const DashboardPage(),
    );
  }
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int? value;
  String? file;
  String? memory;

  Future<void> readValue() async {
    file = storage.internal.rootFile.readAsStringSync();
    memory = storage.internal.memory.toString();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: storage.clear,
          ),
        ],
      ),
      body: ListView(
        children: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              await storage.test.update((s) => (s ?? 0) + 1);
              await storage.testSecure.update((s) => (s ?? 0) + 1);
              readValue();
            },
          ),
          VaultBuilder(
            vaultKey: storage.test,
            builder: (context, value) {
              return Text('test: $value');
            },
          ),
          VaultBuilder(
            vaultKey: storage.testSecure,
            builder: (context, value) {
              return Text('test-secure: $value');
            },
          ),
          Text(file ?? ''),
          Text(memory ?? ''),
        ],
      ),
    );
  }
}
