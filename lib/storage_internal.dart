part of 'vault.dart';

/// Default in-memory storage implementation used internally by [Vault].
///
/// This class is private by design. For custom storage implementations,
/// extend [VaultStorage] and pass it via the `externalStorage` parameter.
class _VaultInternalStorage extends VaultStorage {
  Map<String, dynamic> memory = {};
  late File _rootFile;
  late Vault _vault;

  @override
  Future<void> init(Vault vault) async {
    _rootFile = File('${vault.root.path}/main.vault');
    _vault = vault;

    if (_rootFile.existsSync()) {
      try {
        final content = await Isolate.run(() async {
          return jsonDecode(await _rootFile.readAsString()) as Map;
        });

        memory = content.cast();
      } catch (error, stackTrace) {
        final exception = VaultException<dynamic>(
          'Failed to load memory',
          error: error,
          stackTrace: stackTrace,
        );

        _vault.onError?.call(exception);
        clear();
      }
    } else {
      await _rootFile.writeAsString('{}');
    }
  }

  @override
  void clear() {
    memory.clear();
    unawaited(saveMemory());
  }

  Timer? _timer;
  Future<void> saveMemory() async {
    try {
      _timer?.cancel();
      _timer = Timer(const Duration(milliseconds: 150), () async {
        final tmp = File('${_rootFile.path}.tmp');

        // Capture memory state to avoid concurrent modification issues
        // during async isolate execution.
        final currentMemory = Map<String, dynamic>.from(memory);

        final data = await compute(jsonEncode, currentMemory);

        await tmp.writeAsString(data, flush: true);
        await tmp.rename(_rootFile.path);
      });
    } catch (error, stackTrace) {
      final exception = VaultException<dynamic>(
        'Failed to save memory',
        error: error,
        stackTrace: stackTrace,
      );

      _vault.onError?.call(exception);
      throw exception;
    }
  }

  @override
  bool exists(VaultKey<dynamic> key) => memory.containsKey(key.name);

  @override
  FutureOr<List<E>> getEntries<E>() => memory.entries.toList().cast<E>();

  @override
  F getEntry<F>(VaultKey<dynamic> key) {
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
