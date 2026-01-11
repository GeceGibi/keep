part of 'vault.dart';

class _VaultInternalStorage extends VaultStorage {
  Map<String, dynamic> memory = {};

  late File rootFile;

  @override
  Future<void> init(Vault vault) async {
    rootFile = File('${vault.root.path}/main.vault');

    if (rootFile.existsSync()) {
      try {
        final content = await Isolate.run(() async {
          return jsonDecode(await rootFile.readAsString()) as Map;
        });

        memory = content.cast();
      } catch (e) {
        clear();
      }
    } else {
      await rootFile.writeAsString('{}');
    }
  }

  @override
  void clear() {
    memory.clear();
    saveMemory();
  }

  Timer? timer;
  Future<void> saveMemory() async {
    timer?.cancel();
    timer = Timer(const Duration(milliseconds: 150), () {
      rootFile.writeAsString(jsonEncode(memory));
    });
  }

  @override
  bool exists(VaultKey<dynamic> key) => memory.containsKey(key.name);

  @override
  FutureOr<List<E>> getEntries<E>() => memory.entries.toList().cast<E>();

  @override
  F getFile<F>(VaultKey<dynamic> key) {
    return {key.name: memory[key.name]} as F;
  }

  @override
  V? read<V>(VaultKey<dynamic> key) {
    return memory[key.name] as V?;
  }

  @override
  void write(VaultKey<dynamic> key, dynamic value) {
    memory[key.name] = value;
    unawaited(saveMemory());
  }

  @override
  void remove(VaultKey<dynamic> key) {
    memory.remove(key.name);
    unawaited(saveMemory());
  }
}
