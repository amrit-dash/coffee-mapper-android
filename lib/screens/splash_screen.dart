import 'package:coffee_mapper/main.dart' show FirebaseInitializer;
import 'package:coffee_mapper/screens/auth_wrapper.dart';
//import 'package:coffee_mapper/widgets/svg_animator.dart';

import 'package:flutter/material.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/logo/appLogo.png',
                width: MediaQuery.of(context).size.width * 0.85), // Replace with your logo image path
            // LoaderBean Animation
            /*

            const SizedBox(height: 130),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                LoaderBeanWidget(
                  color1: Theme.of(context).colorScheme.error,
                  color2: Theme.of(context).colorScheme.error.withOpacity(0.5),
                  size: 20.0,
                ),
                LoaderBeanWidget(
                  color1: Theme.of(context).colorScheme.error.withOpacity(0.5),
                  color2: Theme.of(context).colorScheme.error.withOpacity(0.75),
                  size: 30.0,
                ),
                LoaderBeanWidget(
                  color1: Theme.of(context).colorScheme.error,
                  color2: Theme.of(context).colorScheme.error.withOpacity(0.5),
                  size: 20.0,
                ),
              ],
            ),

             */
          ],
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    // Run Firebase init in parallel with a minimum splash display window
    // so the splash never flashes by, but we also never block past init.
    await Future.wait([
      FirebaseInitializer.ensureInitialized(),
      Future.delayed(const Duration(seconds: 2)),
    ]);
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const AuthWrapper()),
    );
  }
}