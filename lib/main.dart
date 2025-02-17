import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:coffee_mapper/providers/admin_provider.dart';
import 'package:coffee_mapper/screens/home_screen.dart';
import 'package:coffee_mapper/screens/login_screen.dart';
import 'package:coffee_mapper/screens/splash_screen.dart';
import 'package:coffee_mapper/utils/logger.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Logger first
  AppLogger.init();
  final logger = AppLogger.getLogger('main');

  try {
    // Initialize Firebase with the correct options
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    // If Firebase is already initialized, we can safely continue
    if (Firebase.apps.isNotEmpty) {
      logger.fine('Firebase already initialized');
    } else {
      logger.severe('Failed to initialize Firebase: $e');
      rethrow;
    }
  }

  // Initialize Crashlytics
  await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterError;

  // Enable App Check
  await FirebaseAppCheck.instance.activate(
    androidProvider: AndroidProvider.playIntegrity,
  );

  // Enable offline persistence for Firestore
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
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
        '/login_screen': (context) => const LoginScreen(), // Add this line
      },
      home: const SplashScreen(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.active) {
          if (snapshot.hasData && snapshot.data != null) {
            // Check admin status for persistent login
            context
                .read<AdminProvider>()
                .checkAdminStatus(snapshot.data!.email!);
            return const HomeScreen();
          } else {
            return const LoginScreen();
          }
        } else {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }
      },
    );
  }
}
