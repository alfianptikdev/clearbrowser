import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kDebugMode) {
    // Aktifkan chrome://inspect hanya di debug.
    await InAppWebViewController.setWebContentsDebuggingEnabled(true);
  }

  runApp(const ClearBrowserApp());
}
