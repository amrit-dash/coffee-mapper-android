import 'package:coffee_mapper/providers/admin_provider.dart';
import 'package:coffee_mapper/screens/home_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;

  bool _invalidPassword = false;
  bool _invalidEmail = false;

  String? _loginErrorMessage;

  Future<void> _signInWithEmailAndPassword() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true; // Show loader
      _invalidEmail = false;
      _invalidPassword = false;
      _loginErrorMessage = null;
    });
    
    try {
      final providerContext = context;
      final navigatorContext = context;

      // Validate input before attempting login
      if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
        throw FirebaseAuthException(
          code: 'invalid-input',
          message: 'Email and password cannot be empty',
        );
      }
      
      final email = _emailController.text.trim();
      
      // Try to sign in with credentials, catch the specific PigeonUserDetails error
      User? user;
      try {
        // Normal sign-in attempt
        final userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: _passwordController.text,
        );
        user = userCredential.user;
      } catch (e) {
        // Check for the specific PigeonUserDetails error
        if (e.toString().contains("'List<Object?>") && 
            e.toString().contains("PigeonUserDetails")) {
          
          // If we get this error, the authentication might have actually succeeded
          // Try to get the current user
          user = FirebaseAuth.instance.currentUser;
          
          // If we still don't have a user, rethrow the original error
          if (user == null) {
            rethrow;
          }
        } else {
          // For any other error, rethrow it
          rethrow;
        }
      }
      
      // If we have a user at this point, we're authenticated
      if (user != null && user.email != null) {
        // Start admin status check in background
        if (providerContext.mounted) {
          // Don't await this call
          providerContext.read<AdminProvider>().checkAdminStatus(user.email!);
        }
  
        // Navigate to the main menu screen immediately
        if (navigatorContext.mounted) {
          Navigator.pushReplacement(navigatorContext,
              MaterialPageRoute(builder: (context) => const HomeScreen()));
        }
      } else {
        // This shouldn't happen, but handle it anyway
        throw Exception("Failed to authenticate. Please try again.");
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      // Display error message
      String errorMessage;
      switch (e.code) {
        case 'invalid-email':
          errorMessage = 'Invalid email format.';
          _invalidEmail = true;
          _loginErrorMessage = errorMessage;
          break;
        case 'user-disabled':
          errorMessage = 'User account disabled.';
          break;
        case 'user-not-found':
          errorMessage = 'No user found with this email address.';
          _invalidEmail = true;
          _loginErrorMessage = errorMessage;
          break;
        case 'wrong-password':
        case 'invalid-credential':
          errorMessage = 'Incorrect password.';
          _invalidPassword = true;
          _loginErrorMessage = errorMessage;
          break;
        case 'invalid-input':
          errorMessage = e.message ?? 'Please enter email and password.';
          break;
        default:
          // Check if the error could be a "user not found" error
          if (e.message?.toLowerCase().contains('user') == true && 
              e.message?.toLowerCase().contains('not found') == true) {
            errorMessage = 'No user found with this email address.';
            _invalidEmail = true;
            _loginErrorMessage = errorMessage;
          } else {
            errorMessage = 'Login failed: ${e.message}';
          }
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      
      // Handle generic errors, including the PigeonUserDetails error if not caught earlier
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().contains("PigeonUserDetails") 
            ? 'An authentication error occurred. Please try again.' 
            : 'Authentication error: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false; // Hide loader
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with logo and title
            _buildHeader(context),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Log in to continue',
                      style: TextStyle(
                        fontFamily: 'Gilroy-SemiBold',
                        fontSize: 20,
                      ),
                    ),
                    const SizedBox(height: 30),
                    _buildEmailTextField(context),
                    const SizedBox(height: 20),
                    _buildPasswordTextField(context),
                    const SizedBox(height: 20),
                    _buildForgotPasswordButton(context),
                  ],
                ),
              ),
            ),
            // Login button at the bottom
            _buildLoginButton(context),
          ],
        ),
      ),
    );
  }

  // Widget for the header section
  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(30),
      child: Row(
        children: [
          SvgPicture.asset(
            'assets/logo/logo.svg',
            height: 54,
            width: 56,
          ),
          const SizedBox(width: 20),
          Column(
            children: [
              const Text(
                'Coffee Mapper',
                style: TextStyle(
                  fontFamily: 'Gilroy-Medium',
                  fontSize: 26,
                  fontWeight: FontWeight.normal,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Widget for the email text field
  Widget _buildEmailTextField(BuildContext context) {
    return Stack(
      children: [
        TextFormField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            hintText: 'Enter Email',
            hintStyle: TextStyle(
              fontFamily: 'Gilroy-Medium',
              color: Theme.of(context).colorScheme.secondary,
            ),
            enabledBorder: UnderlineInputBorder(
              borderSide:
                  BorderSide(color: Theme.of(context).colorScheme.error),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide:
                  BorderSide(color: Theme.of(context).colorScheme.error),
            ),
            errorStyle: TextStyle(
              fontFamily: 'Gilroy-Medium',
              fontSize: 12,
              color: Theme.of(context).colorScheme.secondary,
            ),
          ),
          autovalidateMode: AutovalidateMode.onUserInteraction,
          validator: (value) {
            // Add validator for required field
            if (value == null || value.isEmpty) {
              _invalidEmail = false;
              return 'Please enter an email!';
            }

            if (_invalidEmail) {
              return _loginErrorMessage;
            }

            return null;
          },
        ),
        const Positioned(
          right: 13,
          top: 15,
          child: Icon(Icons.email_outlined, size: 20),
        ),
      ],
    );
  }

  // Widget for the password text field
  Widget _buildPasswordTextField(BuildContext context) {
    return Stack(
      children: [
        TextFormField(
          style: TextStyle(
            color: (_obscurePassword)
                ? Theme.of(context).colorScheme.error
                : Theme.of(context).colorScheme.secondary,
          ),
          autovalidateMode: AutovalidateMode.onUserInteraction,
          controller: _passwordController,
          obscureText: _obscurePassword,
          decoration: InputDecoration(
            hintText: 'Enter Password',
            hintStyle: TextStyle(
              fontFamily: 'Gilroy-Medium',
              color: Theme.of(context).colorScheme.secondary,
            ),
            enabledBorder: UnderlineInputBorder(
              borderSide:
                  BorderSide(color: Theme.of(context).colorScheme.error),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide:
                  BorderSide(color: Theme.of(context).colorScheme.error),
            ),
            errorStyle: TextStyle(
              fontFamily: 'Gilroy-Medium',
              fontSize: 12,
              color: Theme.of(context).colorScheme.secondary,
            ),
          ),
          validator: (value) {
            // Add validator for required field
            if (value == null || value.isEmpty) {
              _invalidPassword = false;
              return 'Please enter a password!';
            }

            if (_invalidPassword) {
              return _loginErrorMessage;
            }

            return null;
          },
        ),
        Positioned(
          right: 0,
          top: 0,
          child: IconButton(
            icon: SvgPicture.asset(
              'assets/icons/coffeeBeanOutline.svg',
              height: 25,
              width: 25,
              colorFilter: ColorFilter.mode(
                (_obscurePassword)
                    ? Theme.of(context).colorScheme.error
                    : Theme.of(context).colorScheme.secondary,
                BlendMode.srcIn,
              ),
            ),
            onPressed: () {
              setState(() {
                _obscurePassword =
                    !_obscurePassword; // Toggle the _obscurePassword variable
              });
            },
          ),
        ),
      ],
    );
  }

  // Widget for the forgot password button
  Widget _buildForgotPasswordButton(BuildContext context) {
    return TextButton(
      onPressed: () async {
        // 1. Check if email is provided in the input field
        final email = _emailController.text;
        final snackbarContext = context;

        if (email.isEmpty) {
          if (!mounted) return;
          ScaffoldMessenger.of(snackbarContext).showSnackBar(
            const SnackBar(content: Text('Please enter your email address')),
          );
          _emailController.selection = TextSelection.fromPosition(
            TextPosition(offset: _emailController.text.length),
          );
          return;
        }

        // 2. Send password reset email
        try {
          await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
          if (!mounted) return;
          if (snackbarContext.mounted) {
            ScaffoldMessenger.of(snackbarContext).showSnackBar(
              const SnackBar(content: Text('Password reset email sent!')),
            );
          }
        } on FirebaseAuthException catch (e) {
          if (!mounted) return;
          if (snackbarContext.mounted) {
            ScaffoldMessenger.of(snackbarContext).showSnackBar(
              SnackBar(
                  content: Text(e.message ?? 'Failed to send reset email')),
            );
          }
        }
      },
      child: Text(
        'Forgot Password?',
        style: TextStyle(
          fontFamily: 'Gilroy-Medium',
          color: Theme.of(context).colorScheme.error,
        ),
      ),
    );
  }

  // Widget for the login button
  Widget _buildLoginButton(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 150,
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 35),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.error,
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(10.0), // Reduce corner radius to 8 pixels
          ),
          elevation: 0,
          textStyle: const TextStyle(
            fontFamily: 'Gilroy-Medium',
            fontSize: 18,
          ),
        ),
        onPressed: _signInWithEmailAndPassword,
        child: _isLoading // Conditionally render the loader or text
            ? SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  strokeWidth: 2,
                ),
              )
            : Text(
                'Let\'s Begin!',
                style: TextStyle(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    fontSize: 19),
              ),
      ),
    );
  }
}
