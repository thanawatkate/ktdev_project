class LocalFileWriteResult {
  const LocalFileWriteResult({required this.path});

  final String path;
}

bool get supportsDesktopFileExport => false;

Future<LocalFileWriteResult?> writeTextFileToDocuments({
  required String filename,
  required String content,
}) async {
  return null;
}

Future<LocalFileWriteResult?> writeBytesFileToDocuments({
  required String filename,
  required List<int> bytes,
}) async {
  return null;
}

Future<void> openFileLocation(String path) async {}

Future<String> buildBackupExportPath(String filename) async {
  throw UnsupportedError('ยังไม่รองรับการสำรองบนเว็บ');
}

Future<String> stageLocalFileForRestore({
  required String sourcePath,
  required String stagedFilename,
}) async {
  throw UnsupportedError('ยังไม่รองรับการกู้คืนบนเว็บ');
}
