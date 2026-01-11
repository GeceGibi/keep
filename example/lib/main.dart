import 'dart:convert';
import 'package:flutter/material.dart';
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
  AppStorage()
      : super(
          // Automatic root resolution (getApplicationSupportDirectory/vault)
          fileVault: DefaultFileVault(),
          secureKey: 'my-super-secret-app-key-12345678',
          onError: (e) {
            print('🔴 Vault Error: $e');
          },
          storageName: 'app_data',
        );

  late final themeMode = key.boolean('is_dark');
  late final counter = key.integer('counter');
  late final secretToken = secure.string('token', removable: true);
  late final tags = key.list<String>('tags');

  late final profile = key.custom<UserProfile>(
    'profile',
    fromStorage: (v) => UserProfile.fromJson(v as Map<String, dynamic>),
    toStorage: (v) => v.toJson(),
    removable: true,
  );
}

final storage = AppStorage();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await storage.init();
  runApp(const MyApp());
}

// --- 3. UI Application ---
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return VaultBuilder<bool>(
      vaultKey: storage.themeMode,
      builder: (context, isDark) {
        return MaterialApp(
          title: 'Vault Demo',
          theme: (isDark ?? false)
              ? ThemeData.dark(useMaterial3: true)
              : ThemeData.light(useMaterial3: true),
          home: const DashboardPage(),
        );
      },
    );
  }
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  @override
  void initState() {
    super.initState();

    // Listen to ALL events and print to console
    storage.events.listen((event) {
      print('📝 LOG: ${event.key.name} -> ${event.value}');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vault Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_forever),
            onPressed: () async {
              await storage.clear(force: true);
              print('⚠️ STORAGE CLEARED ⚠️');
            },
          )
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // --- Counter ---
          _buildCard(
              'Counter (Int)',
              VaultBuilder<int>(
                vaultKey: storage.counter,
                builder: (context, value) {
                  final count = value ?? 0;
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('$count',
                          style: const TextStyle(
                              fontSize: 24, fontWeight: FontWeight.bold)),
                      Row(
                        children: [
                          IconButton.filledTonal(
                            icon: const Icon(Icons.remove),
                            onPressed: () => storage.counter.write(count - 1),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filledTonal(
                            icon: const Icon(Icons.add),
                            onPressed: () => storage.counter.write(count + 1),
                          ),
                        ],
                      )
                    ],
                  );
                },
              )),

          // --- Toggle ---
          _buildCard(
              'Theme (Bool)',
              VaultBuilder<bool>(
                vaultKey: storage.themeMode,
                builder: (context, isDark) => SwitchListTile(
                  title: const Text('Dark Mode'),
                  value: isDark ?? false,
                  onChanged: (v) => storage.themeMode.write(v),
                ),
              )),

          // --- Encrypted Input ---
          _buildCard(
              'Secret Token (Encrypted)',
              VaultBuilder<String>(
                  vaultKey: storage.secretToken,
                  builder: (context, token) {
                    return TextField(
                      controller: TextEditingController(text: token),
                      decoration:
                          const InputDecoration(hintText: 'Type secret...'),
                      onSubmitted: (v) => storage.secretToken.write(v),
                    );
                  })),

          // --- List ---
          _buildCard(
              'Tags (List<String>)',
              VaultBuilder<List<String>>(
                  vaultKey: storage.tags,
                  builder: (context, tags) {
                    final list = tags ?? [];
                    return Wrap(
                      spacing: 8,
                      children: [
                        ...list.map((tag) => Chip(
                              label: Text(tag),
                              onDeleted: () {
                                final newList = List<String>.from(list)
                                  ..remove(tag);
                                storage.tags.write(newList);
                              },
                            )),
                        ActionChip(
                          label: const Icon(Icons.add, size: 16),
                          onPressed: () {
                            final newList = List<String>.from(list)
                              ..add('Tag ${list.length + 1}');
                            storage.tags.write(newList);
                          },
                        )
                      ],
                    );
                  })),

          // --- Custom Object ---
          _buildCard(
              'Profile (Custom Object)',
              VaultBuilder<UserProfile>(
                  vaultKey: storage.profile,
                  builder: (context, p) {
                    if (p == null) {
                      return ElevatedButton(
                          onPressed: () => storage.profile.write(UserProfile(
                              id: 'u1', bio: 'Hello Vault!', level: 1)),
                          child: const Text('Create Profile'));
                    }
                    return ListTile(
                      leading: CircleAvatar(child: Text('${p.level}')),
                      title: Text('User: ${p.id}'),
                      subtitle: Text(p.bio),
                      trailing: IconButton(
                        icon: const Icon(Icons.upgrade),
                        onPressed: () => storage.profile.write(UserProfile(
                            id: p.id, bio: p.bio, level: p.level + 1)),
                      ),
                    );
                  })),
        ],
      ),
    );
  }

  Widget _buildCard(String title, Widget content) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 8),
            content,
          ],
        ),
      ),
    );
  }
}
