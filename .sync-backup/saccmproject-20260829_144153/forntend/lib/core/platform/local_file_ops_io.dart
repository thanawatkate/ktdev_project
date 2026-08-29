import 'dart:io';

import 'package:path_provider/path_provider.dart';

class LocalFileWriteResult {
  const LocalFileWriteResult({required this.path});

  final String path;
}

bool get supportsDesktopFileExport =>
    Platform.isWindows || Platform.isLinux || Platform.isMacOS;

Future<LocalFileWriteResult?> writeTextFileToDocuments({
  required String filename,
  required String content,
}) async {
  final dir = await getApplicationDocumentsDirectory();
  final file = File('${dir.path}${Platform.pathSeparator}$filename');
  await file.writeAsString(content);
  return LocalFileWriteResult(path: file.path);
}

Future<LocalFileWriteResult?> writeBytesFileToDocuments({
  required String filename,
  required List<int> bytes,
}) async {
  final dir = await getApplicationDocumentsDirectory();
  final file = File('${dir.path}${Platform.pathSeparator}$filename');
  await file.writeAsBytes(bytes);
  return LocalFileWriteResult(path: file.path);
}

Future<void> openFileLocation(String path) async {
  final folder = File(path).parent.path;
  if (Platform.isWindows) {
    await Process.start('explorer', [folder]);
  } else if (Platform.isMacOS) {
    await Process.start('open', [folder]);
  } else if (Platform.isLinux) {
    await Process.start('xdg-open', [folder]);
  }
}

Future<String> buildBackupExportPath(String filename) async {
  final downloads = await getDownloadsDirectory();
  final dir = downloads ?? await getApplicationDocumentsDirectory();
  return '${dir.path}${Platform.pathSeparator}$filename';
}

Future<String> stageLocalFileForRestore({
  required String sourcePath,
  required String stagedFilename,
}) async {
  final src = File(sourcePath);
  if (!await src.exists()) {
    throw StateError('ไม่พบไฟล์');
  }
  final tempDir = await getTemporaryDirectory();
  final staged =
      File('${tempDir.path}${Platform.pathSeparator}$stagedFilename');
  await src.copy(staged.path);
  return staged.path;
}
