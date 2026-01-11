//
// ignore_for_file: specify_nonobvious_property_types

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as encrypt_lib;
import 'package:path_provider/path_provider.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

part 'storage.dart';
part 'security.dart';
part 'builders.dart';
part 'keys.dart';
part 'errors.dart';
part 'worker.dart';
part 'widgets.dart';

/// Local data storage service
class Vault {
  Vault({
    required this.fileVault,
    required this.secureKey,
    this.storageName = 'main',
    this.onError,
  });

  final FileVaultBase fileVault;
  final String secureKey;
  final String storageName;
  final void Function(Object error)? onError;

  late final key = KeyCreator(this);
  late final secure = SecureKeyCreator(this);

  final _keys = <VaultKey<dynamic>>[];
  List<VaultKey<dynamic>> get keys => List.unmodifiable(_keys);

  Map<String, dynamic> _memCache = {};
  File? _mainStorageFile;
  final _controller = StreamController<MapEntry<VaultKey, dynamic>>.broadcast();
  Timer? _saveDebounce;

  void dispose() {
    _saveDebounce?.cancel();
    _controller.close();
  }

  Future<void> init() async {
    // Forward FileVault errors to main error handler
    fileVault.onError = (e, s) {
      onError?.call(VaultException('FileVault error', error: e, stackTrace: s));
    };

    try {
      await fileVault.init();
      _mainStorageFile = File('${fileVault.root.path}/$storageName.vault');

      if (!_mainStorageFile!.existsSync()) {
        await _mainStorageFile!.create(recursive: true);
        await _mainStorageFile!.writeAsString('{}');
        _memCache = {};
      } else {
        final content = await _mainStorageFile!.readAsString();
        if (content.isNotEmpty) {
          try {
            _memCache = jsonDecode(content) as Map<String, dynamic>;
          } catch (error, stackTrace) {
            _memCache = {};
            onError?.call(
              VaultException(
                'Corrupted, resetting.',
                error: error,
                stackTrace: stackTrace,
              ),
            );
          }
        }
      }
    } catch (e, s) {
      onError?.call(VaultException('Init failed', error: e, stackTrace: s));
      rethrow;
    }
  }

  void _register(VaultKey key) => _keys.add(key);

  Future<T?> readKey<T>(VaultKey<T> key) async {
    try {
      String? payload;

      if (key.useFileSystem) {
        // Direct async read (Performance is fine for typical use cases)
        payload = await fileVault.read(key.name);
      } else {
        payload = _memCache[key.name] as String?;
      }

      if (payload == null) return null;
      final decodable = await key.decrypt(payload);
      if (decodable.isEmpty) return null;

      final decodedJson = jsonDecode(decodable);
      return key.fromStorage(decodedJson);
    } catch (e, s) {
      onError?.call(key.toException('Read failed', error: e, stackTrace: s));
      return null;
    }
  }

  Future<void> writeKey<T>(VaultKey<T> key, T value) async {
    if (value == null) {
      await removeKey(key);
      return;
    }

    try {
      final jsonDto = key.toStorage(value);
      final rawString = jsonEncode(jsonDto);
      final payload = await key.encrypt(rawString);

      if (key.useFileSystem) {
        final ioPayload = _IsolateFileOpPayload(
          rootPath: fileVault.root.path,
          keyName: key.name,
          valuePayload: payload,
        );
        // Using compute
        await compute(_isolateWriteFileSystem, ioPayload);
      } else {
        _memCache[key.name] = payload;
        await _saveMemCache();
      }
      _controller.add(MapEntry(key, value));
    } catch (e, s) {
      onError?.call(key.toException('Write failed', error: e, stackTrace: s));
    }
  }

  Future<void> _saveMemCache() async {
    if (_mainStorageFile == null) return;
    _saveDebounce?.cancel();

    _saveDebounce = Timer(const Duration(milliseconds: 50), () async {
      try {
        final payload = _IsolateSavePayload(
          path: _mainStorageFile!.path,
          data: _memCache,
        );
        await compute(_isolateSaveVault, payload);
      } catch (e, s) {
        onError?.call(
          VaultException('Persistence failed', error: e, stackTrace: s),
        );
      }
    });
  }

  Future<void> removeKey(VaultKey key) async {
    try {
      if (key.useFileSystem) {
        await fileVault.remove(key.name);
      } else {
        _memCache.remove(key.name);
        await _saveMemCache();
      }
      _controller.add(MapEntry(key, null));
    } catch (e, s) {
      onError?.call(key.toException('Remove failed', error: e, stackTrace: s));
    }
  }

  Future<bool> keyExists(VaultKey key) async {
    try {
      if (key.useFileSystem) return fileVault.exists(key.name);
      return _memCache.containsKey(key.name);
    } catch (e, s) {
      onError?.call(key.toException('Exists failed', error: e, stackTrace: s));
      return false;
    }
  }

  Future<void> clear({bool force = false}) async {
    try {
      await fileVault.clear();
      if (force) {
        _memCache.clear();
        await _saveMemCache();
        return;
      }
      for (final key in _keys) {
        if (key.removable) await removeKey(key);
      }
    } catch (e, s) {
      onError?.call(VaultException('Clear failed', error: e, stackTrace: s));
    }
  }

  Stream<T?> listen<T>(VaultKey<T> key) {
    return _controller.stream
        .where((event) => event.key.name == key.name)
        .map((event) => event.value as T?);
  }

  /// Global stream of all changes
  Stream<MapEntry<VaultKey, dynamic>> get events => _controller.stream;
}
