import 'dart:typed_data';

import 'file_download_stub.dart'
    if (dart.library.html) 'file_download_web.dart' as impl;

Future<void> downloadFileBytes({
  required String filename,
  required Uint8List bytes,
  required String mimeType,
}) =>
    impl.downloadFileBytes(filename: filename, bytes: bytes, mimeType: mimeType);
