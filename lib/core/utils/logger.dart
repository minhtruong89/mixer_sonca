import 'package:flutter/foundation.dart';

class Logger {
  const Logger._();

  static void info(String message) {
    if (kDebugMode) {
      print('[INFO] $message');
    }
  }

  static void error(String message, [Object? error, StackTrace? stackTrace]) {
    if (kDebugMode) {
      print('[ERROR] $message');
      if (error != null) print(error);
      if (stackTrace != null) print(stackTrace);
    }
  }
}
