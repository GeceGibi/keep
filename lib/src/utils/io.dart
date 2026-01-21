part of 'utils.dart';

/// Performs an atomic write by writing to a temporary file and then renaming it.
/// This helps prevent data corruption during power failures or crashes.
@internal
Future<void> atomicWrite(File file, Uint8List bytes) async {
  final targetPath = file.path;
  final tmpFile = File('$targetPath.tmp');

  try {
    if (!file.parent.existsSync()) {
      await file.parent.create(recursive: true);
    }

    await tmpFile.writeAsBytes(bytes, flush: true);

    if (tmpFile.existsSync()) {
      await tmpFile.rename(targetPath);
    } else {
      throw PathNotFoundException(
        tmpFile.path,
        const OSError('Temporary file vanished before rename', 2),
      );
    }
  } catch (e) {
    if (tmpFile.existsSync()) {
      try {
        await tmpFile.delete();
      } catch (_) {}
    }
    rethrow;
  }
}
