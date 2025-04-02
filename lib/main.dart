import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:coffee_mapper/providers/admin_provider.dart';
import 'package:coffee_mapper/screens/home_screen.dart';
import 'package:coffee_mapper/screens/login_screen.dart';
import 'package:coffee_mapper/screens/splash_screen.dart';
import 'package:coffee_mapper/utils/logger.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';

// Singleton class for Firebase initialization
class FirebaseInitializer {
  static final FirebaseInitializer _instance = FirebaseInitializer._internal();
  static final _logger = AppLogger.getLogger('FirebaseInitializer');
  static bool _isInitialized = false;

  factory FirebaseInitializer() {
    return _instance;
  }

  FirebaseInitializer._internal();

  static Future<void> ensureInitialized() async {
    if (_isInitialized) {
      _logger.info('Firebase already initialized, skipping...');
      return;
    }

    try {
      // Initialize Firebase with the correct options
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      // Initialize Crashlytics
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);
      FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterError;

      // Get environment configuration
      const environment = String.fromEnvironment('ENVIRONMENT', defaultValue: 'development');
      final isProduction = environment == 'production';

      try {
        // Initialize App Check
        if (!isProduction) {
          _logger.info('Initializing App Check in debug mode');
          await FirebaseAppCheck.instance.activate(
            androidProvider: AndroidProvider.debug,
          );
        } else {
          _logger.info('Initializing App Check in release mode');
          await FirebaseAppCheck.instance.activate(
            androidProvider: AndroidProvider.playIntegrity,
          );
        }
        
        // Set App Check token auto-refresh
        await FirebaseAppCheck.instance.setTokenAutoRefreshEnabled(true);
        
        // Add listener for App Check token changes
        FirebaseAppCheck.instance.onTokenChange.listen(
          (token) {
            if (!isProduction) {
              _logger.info('App Check debug token refreshed');
            } else {
              _logger.info('App Check token refreshed');
            }
          },
          onError: (error) => _logger.severe('Error refreshing App Check token: $error'),
        );

        _logger.info('App Check initialized successfully');

      } catch (appCheckError) {
        _logger.severe('Failed to initialize App Check: $appCheckError');
        // Continue even if App Check fails - other Firebase services might still work
      }

      // Enable offline persistence for Firestore
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );

      _isInitialized = true;
      _logger.info('Firebase initialization completed successfully');
    } catch (e, stack) {
      _logger.severe('Failed to initialize Firebase services: $e\n$stack');
      // Continue with the app even if Firebase fails, to allow debugging
    }
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Logger first
  AppLogger.init();

  // Initialize Firebase services
  await FirebaseInitializer.ensureInitialized();

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AdminProvider()),
      ],
      child: const CoffeeMapperApp(),
    ),
  );
}

class CoffeeMapperApp extends StatelessWidget {
  const CoffeeMapperApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        primaryColor: const Color(0xFFc09366),
        scaffoldBackgroundColor: const Color(0xFFD5B799),
        cardColor: const Color(0xFFEADCC8),
        dialogTheme: const DialogTheme(
          backgroundColor: Color(0xFFFAEEE6),
        ),
        unselectedWidgetColor: const Color(0xff402200),
        highlightColor: const Color(0xFF632D00),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFc09366),
          primary: const Color(0xFFc09366),
          secondary: const Color(0xFF964600),
          error: const Color(0xFF1e0f00),
          surface: const Color(0xFFEDE2D6),
        ),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(fontFamily: 'Gilroy-Medium'),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFc09366),
            textStyle: const TextStyle(
              fontFamily: 'Gilroy-SemiBold',
            ),
          ),
        ),
      ),
      routes: {
        '/main_menu': (context) => const HomeScreen(),
        '/login_screen': (context) => const LoginScreen(),
      },
      home: const SplashScreen(),
    );
  }
}
