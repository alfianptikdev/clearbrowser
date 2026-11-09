import 'package:flutter/foundation.dart';

/// Logger tipis: tidak mencetak apa pun di release build.
class Log {
  Log._();

  static void d(String tag, Object? message) {
    if (kDebugMode) {
      debugPrint('[CB/$tag] $message');
    }
  }

  static void e(String tag, Object? message, [Object? error]) {
    if (kDebugMode) {
      debugPrint('[CB/$tag] ERROR $message${error == null ? '' : ' | $error'}');
    }
  }
}
