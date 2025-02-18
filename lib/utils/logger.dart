import 'package:logging/logging.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

class AppLogger {
  static void init() {
    // Set up logging
    Logger.root.level = Level.ALL;
    Logger.root.onRecord.listen((record) {
      if (kDebugMode) {
        // In debug mode, print to console
        print('${record.level.name}: ${record.time}: ${record.message}');
      }
      
      // Log to Firebase Crashlytics
      final crashlytics = FirebaseCrashlytics.instance;
      
      switch (record.level.name) {
        case 'SEVERE':
          crashlytics.recordError(
            record.error ?? record.message,
            record.stackTrace,
            reason: record.message,
            fatal: true,
          );
          break;
        case 'WARNING':
          crashlytics.recordError(
            record.error ?? record.message,
            record.stackTrace,
            reason: record.message,
            fatal: false,
          );
          break;
        case 'INFO':
          crashlytics.log(record.message);
          break;
        case 'FINE':
        case 'FINER':
        case 'FINEST':
          if (!kReleaseMode) {
            crashlytics.log(record.message);
          }
          break;
      }
    });
  }

  static Logger getLogger(String name) => Logger(name);
} 