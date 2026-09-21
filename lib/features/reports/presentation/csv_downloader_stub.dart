import 'package:flutter/services.dart';

/// Fallback saver for non-Web platforms that copies the CSV to the system clipboard.
Future<String> saveCsv(String filename, String content) async {
  await Clipboard.setData(ClipboardData(text: content));
  return 'CSV copied to the clipboard as $filename.';
}
