import 'package:coffee_mapper/providers/user_provider.dart';
import 'package:coffee_mapper/providers/attendance_provider.dart';
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
            // Don't wait for the admin check, just trigger it
            context.read<UserProvider>().checkUserStatus(currentUser.uid);
            context.read<AttendanceProvider>().initialize(currentUser.uid);
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