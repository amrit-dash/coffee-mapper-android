import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:coffee_mapper/utils/logger.dart';
import 'dart:async';
import 'dart:math';

class AdminProvider with ChangeNotifier {
  bool _isAdmin = false;
  bool _isSuperAdmin = false;
  String? _lastCheckedEmail;
  final _logger = AppLogger.getLogger('AdminProvider');
  static const int _maxRetries = 5;
  static const Duration _initialDelay = Duration(milliseconds: 500);
  static const Duration _maxDelay = Duration(seconds: 5);

  bool get isAdmin => _isAdmin;

  bool get isSuperAdmin => _isSuperAdmin;

  Future<void> checkAdminStatus(String email) async {
    // If we've already checked this email and have the status, no need to check again
    if (_lastCheckedEmail == email) {
      _logger.info('Using cached admin status for $email');
      return;
    }

    int retryCount = 0;
    Duration delay = _initialDelay;

    while (retryCount < _maxRetries) {
      try {
        _logger.info('Checking admin status for $email (attempt ${retryCount + 1}/$_maxRetries)');
        
        final docRef = FirebaseFirestore.instance.collection('admins').doc(email);
        final doc = await docRef.get();
        _isAdmin = doc.exists;

        if (doc.exists) {
          final data = doc.data();
          if (data != null) {
            final role = data['role'];
            _isSuperAdmin = role == "superAdmin";
          }
        }

        _lastCheckedEmail = email; // Cache the email we just checked
        _logger.info('Admin status check successful: isAdmin=$_isAdmin, isSuperAdmin=$_isSuperAdmin');
        notifyListeners();
        return; // Success, exit the retry loop
      } catch (e) {
        retryCount++;
        _logger.warning('Admin status check attempt $retryCount failed: $e');
        
        if (retryCount == _maxRetries) {
          // Last retry failed, log error and set default values
          _logger.severe('Failed to check admin status after $retryCount attempts. Defaulting to non-admin access.');
          _isAdmin = false;
          _isSuperAdmin = false;
          notifyListeners();
          return;
        }

        // Calculate next delay with exponential backoff and jitter
        delay = Duration(milliseconds: min(
          _maxDelay.inMilliseconds,
          (_initialDelay.inMilliseconds * pow(2, retryCount - 1)).round() +
              (Random().nextInt(1000)), // Add jitter
        ));

        _logger.info('Retrying admin status check in ${delay.inSeconds} seconds...');
        await Future.delayed(delay);
      }
    }
  }

  void reset() {
    _isAdmin = false;
    _isSuperAdmin = false;
    _lastCheckedEmail = null; // Clear the cache on reset
    notifyListeners();
  }
}
