import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:coffee_mapper/utils/logger.dart';
import 'dart:async';

class AdminProvider with ChangeNotifier {
  bool _isAdmin = false;
  bool _isSuperAdmin = false;
  final _logger = AppLogger.getLogger('AdminProvider');
  static const int _maxRetries = 2;
  static const Duration _initialDelay = Duration(milliseconds: 500);

  bool get isAdmin => _isAdmin;

  bool get isSuperAdmin => _isSuperAdmin;

  Future<void> checkAdminStatus(String email) async {
    int retryCount = 0;
    Duration delay = _initialDelay;

    while (retryCount < _maxRetries) {
      try {
        final docRef = FirebaseFirestore.instance.collection('admins').doc(email);
        final doc = await docRef.get();
        _isAdmin = doc.exists;

        if (doc.exists) {
          // Document exists, retrieve the data
          final data = doc.data();

          if (data != null) {
            final role = data['role'];

            if (role == "superAdmin") {
              _isSuperAdmin = true;
            } else {
              _isSuperAdmin = false;
            }
          }
        }
        // If we get here, the operation was successful
        break;
      } catch (e) {
        retryCount++;
        if (retryCount == _maxRetries) {
          // Last retry failed, log error and set default values
          _logger.warning('Error checking admin status after $retryCount retries: $e');
          _isAdmin = false;
          _isSuperAdmin = false;
        } else {
          // Log retry attempt and wait before next try
          _logger.info('Retry $retryCount of $_maxRetries for admin status check. Waiting ${delay.inSeconds} seconds...');
          await Future.delayed(delay);
          // Exponential backoff
          delay *= 2;
        }
      }
    }
    notifyListeners();
  }

  void reset() {
    _isAdmin = false;
    _isSuperAdmin = false;
    notifyListeners();
  }
}
