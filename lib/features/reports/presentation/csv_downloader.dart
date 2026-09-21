// Conditional export routing CSV saving to browser downloads on Web and clipboard on mobile/desktop.
export 'csv_downloader_stub.dart'
    if (dart.library.html) 'csv_downloader_web.dart';
