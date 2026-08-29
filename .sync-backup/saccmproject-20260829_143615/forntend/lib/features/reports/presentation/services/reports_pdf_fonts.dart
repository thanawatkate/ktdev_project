import 'package:flutter/services.dart';
import 'package:pdf/widgets.dart' as pw;

/// Shared Kanit font cache — load once, reuse for every PDF export.
class ReportsPdfFonts {
  ReportsPdfFonts._();

  static Uint8List? regularBytes;
  static Uint8List? boldBytes;
  static pw.Font? regular;
  static pw.Font? bold;

  static Future<void> preload() async {
    if (regular != null) return;
    final regularData =
        await rootBundle.load('assets/fonts/Kanit-Regular.ttf');
    final boldData = await rootBundle.load('assets/fonts/Kanit-Bold.ttf');
    regularBytes = regularData.buffer.asUint8List(
      regularData.offsetInBytes,
      regularData.lengthInBytes,
    );
    boldBytes = boldData.buffer.asUint8List(
      boldData.offsetInBytes,
      boldData.lengthInBytes,
    );
    regular = pw.Font.ttf(regularData);
    bold = pw.Font.ttf(boldData);
  }

  static pw.Font fontsFromBytes(Uint8List regular, Uint8List bold) {
    return pw.Font.ttf(ByteData.sublistView(regular));
  }

  static pw.Font boldFromBytes(Uint8List bold) {
    return pw.Font.ttf(ByteData.sublistView(bold));
  }
}
