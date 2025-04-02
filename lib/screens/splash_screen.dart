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
    // Navigate to the main screen after a delay
    Future.delayed(const Duration(seconds: 4), () {
      final navigatorContext = context;
      if (!mounted) return;
      if (navigatorContext.mounted) {
        Navigator.pushReplacement(
          navigatorContext,
          MaterialPageRoute(builder: (context) => const AuthWrapper()),
        );
      }
    });
  }
}