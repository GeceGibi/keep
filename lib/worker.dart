part of 'vault.dart';

// --- Payloads for Isolate Operations ---

class _IsolateSavePayload {
  final String path;
  final Map<String, dynamic> data;
  _IsolateSavePayload({required this.path, required this.data});
}

class _IsolateFileOpPayload {
  final String rootPath;
  final String keyName;
  final dynamic valuePayload; // String (encrypted or not) or Raw DTO

  _IsolateFileOpPayload({
    required this.rootPath,
    required this.keyName,
    this.valuePayload,
  });
}

// --- Isolate Static Handlers ---

Future<void> _isolateSaveVault(_IsolateSavePayload payload) async {
  // Atomic Save: Write to .tmp then rename
  final tempFile = File('${payload.path}.tmp');
  final json = jsonEncode(payload.data);

  await tempFile.writeAsString(json, flush: true);

  // Cross-platform safe rename
  final targetFile = File(payload.path);
  if (Platform.isWindows && await targetFile.exists()) {
    try {
      await targetFile.delete();
    } catch (_) {}
  }

  await tempFile.rename(payload.path);
}

Future<void> _isolateWriteFileSystem(_IsolateFileOpPayload payload) async {
  final vault = DefaultFileVault(root: Directory(payload.rootPath));
  final file = vault.getFile(payload.keyName);

  // Encode content
  final content = payload.valuePayload is String
      ? payload.valuePayload as String
      : jsonEncode(payload.valuePayload);

  final bytes = utf8.encode(content);

  // Atomic Write Strategy
  final tempFile = File('${file.path}.tmp');

  // Write to temporary file with flush
  await tempFile.writeAsBytes(bytes, flush: true);

  // Cross-platform safe rename
  if (Platform.isWindows && await file.exists()) {
    try {
      await file.delete();
    } catch (_) {}
  }

  await tempFile.rename(file.path);
}
