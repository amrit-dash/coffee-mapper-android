import 'package:coffee_mapper/providers/admin_provider.dart';
import 'package:coffee_mapper/screens/home_screen.dart';
import 'package:coffee_mapper/screens/login_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.active) {
          if (snapshot.hasData && snapshot.data != null) {
            // Start admin status check in background
            final currentUser = snapshot.data!;
            if (currentUser.email != null) {
              // Don't wait for the admin check, just trigger it
              context.read<AdminProvider>().checkAdminStatus(currentUser.email!);
            }
            // Show HomeScreen immediately
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