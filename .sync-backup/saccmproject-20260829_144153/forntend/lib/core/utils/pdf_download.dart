import 'dart:typed_data';

import 'pdf_download_stub.dart'
    if (dart.library.html) 'pdf_download_web.dart' as impl;

Future<void> downloadPdfBytes(String filename, Uint8List bytes) =>
    impl.downloadPdfBytes(filename, bytes);
